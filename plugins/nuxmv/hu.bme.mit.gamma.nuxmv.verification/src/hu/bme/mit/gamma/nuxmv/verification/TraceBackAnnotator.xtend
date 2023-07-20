/********************************************************************************
 * Copyright (c) 2023 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.nuxmv.verification

import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.querygenerator.NuxmvQueryGenerator
import hu.bme.mit.gamma.querygenerator.ThetaQueryGenerator
import hu.bme.mit.gamma.statechart.interface_.Component
import hu.bme.mit.gamma.statechart.interface_.Package
import hu.bme.mit.gamma.statechart.interface_.SchedulingConstraintAnnotation
import hu.bme.mit.gamma.theta.verification.XstsBackAnnotator
import hu.bme.mit.gamma.trace.model.Cycle
import hu.bme.mit.gamma.trace.model.ExecutionTrace
import hu.bme.mit.gamma.trace.model.Reset
import hu.bme.mit.gamma.trace.model.TraceModelFactory
import hu.bme.mit.gamma.trace.util.TraceUtil
import hu.bme.mit.gamma.util.GammaEcoreUtil
import hu.bme.mit.gamma.verification.util.TraceBuilder
import java.util.NoSuchElementException
import java.util.Scanner
import java.util.logging.Level
import java.util.logging.Logger
import org.eclipse.emf.ecore.EObject

import static com.google.common.base.Preconditions.checkState

import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*

class TraceBackAnnotator {
	
	protected final String STATE = "-> State:"
	protected final String INPUT = "-> Input:"
	protected final String LOOP = "-- Loop starts here"
	
	protected final Scanner traceScanner
	protected final ThetaQueryGenerator nuxmvQueryGenerator
	protected final extension XstsBackAnnotator xStsBackAnnotator
	
	protected final Package gammaPackage
	protected final Component component
	protected final Expression schedulingConstraint
	
	protected final boolean sortTrace
	// Auxiliary objects
	protected final extension TraceModelFactory trFact = TraceModelFactory.eINSTANCE
	protected final extension TraceUtil traceUtil = TraceUtil.INSTANCE
	protected final extension TraceBuilder traceBuilder = TraceBuilder.INSTANCE
	protected final extension GammaEcoreUtil gammaEcoreUtil = GammaEcoreUtil.INSTANCE
	
	protected final Logger logger = Logger.getLogger("GammaLogger")
	
	new(Package gammaPackage, Scanner traceScanner) {
		this(gammaPackage, traceScanner, true)
	}
	
	new(Package gammaPackage, Scanner traceScanner, boolean sortTrace) {
		this.gammaPackage = gammaPackage
		this.traceScanner = traceScanner
		this.sortTrace = sortTrace
		this.component = gammaPackage.firstComponent
		this.nuxmvQueryGenerator = new NuxmvQueryGenerator(component)
		this.xStsBackAnnotator = new XstsBackAnnotator(nuxmvQueryGenerator, NuxmvArrayParser.INSTANCE)
		val schedulingConstraintAnnotation = gammaPackage.annotations
				.filter(SchedulingConstraintAnnotation).head
		if (schedulingConstraintAnnotation !== null) {
			this.schedulingConstraint = schedulingConstraintAnnotation.schedulingConstraint
		}
		else {
			this.schedulingConstraint = null
		}
	}
	
	def ExecutionTrace execute() {
		// Creating the trace component
		val trace = createExecutionTrace => [
			it.component = this.component
			it.import = this.gammaPackage
			it.name = this.component.name + "Trace"
		]
		val topComponentArguments = gammaPackage.topComponentArguments
		// Note that the top component does not contain parameter declarations anymore due to the preprocessing
		checkState(topComponentArguments.size == component.parameterDeclarations.size, 
			"The number of top component arguments and top component parameters are not equal: " +
				topComponentArguments.size + " - " + component.parameterDeclarations.size)
		logger.log(Level.INFO, "The number of top component arguments is " + topComponentArguments.size)
		trace.arguments += topComponentArguments.map[it.clone]
		
		var EObject stepContainer = trace
		var step = stepContainer.addStep
		
		// Parsing
		var state = BackAnnotatorState.INIT
		try {
			while (traceScanner.hasNext) {
				val isFirstState = (state == BackAnnotatorState.INIT)
				var line = traceScanner.nextLine.trim // Trimming leading white spaces
				switch (line) {
					case line.startsWith(INPUT): {
						/// New step to be parsed: checking the previous step
						step.checkInEvents
						// Add schedule
						if (!step.containsType(Reset)) {
							step.addSchedulingIfNeeded
						}
						step.checkStates
						///
						
						// Creating a new step
						step = stepContainer.addStep
						
						/// Add static delay every turn (apart from first state)
						if (schedulingConstraint !== null) {
							step.addTimeElapse(schedulingConstraint)
						}
						///
						// Setting the state
						state = BackAnnotatorState.ENVIRONMENT_CHECK
					}
					case line.startsWith(STATE): {
						if (isFirstState) {
							step.actions += createReset
						}
						// Setting the state
						state = BackAnnotatorState.STATE_CHECK
					}
					case line.startsWith(LOOP): {
						val cycle = createCycle
						trace.cycle = cycle
						stepContainer = cycle
					}
					default: {
						if (!isFirstState) {
							// We parse in every turn except the init
							val split = line.split(" = ", 2) // Only the first " = " is checked
							val id = split.get(0)
							val value = split.get(1)
							try {
								switch (state) {
									case STATE_CHECK: {
										val potentialStateString = '''«id» == «value»'''
										if (nuxmvQueryGenerator.isSourceState(potentialStateString)) {
											potentialStateString.parseState(step)
										}
										else if (nuxmvQueryGenerator.isDelay(id)) {
											step.addTimeElapse(Integer.valueOf(value))
										}
										else if (nuxmvQueryGenerator.isSourceVariable(id)) {
											id.parseVariable(value, step)
										}
										else if (id.isSchedulingVariable) {
											id.addScheduling(value, step)
										}
										else if (nuxmvQueryGenerator.isSourceOutEvent(id)) {
											id.parseOutEvent(value, step)
										}
										else if (nuxmvQueryGenerator.isSourceOutEventParameter(id)) {
											id.parseOutEventParameter(value, step)
										}
										// Checking if an asynchronous in-event is already stored in the queue
										else if (nuxmvQueryGenerator.isAsynchronousSourceMessageQueue(id)) {
											id.handleStoredAsynchronousInEvents(value)
										}
									}
									case ENVIRONMENT_CHECK: {
										// Synchronous in-event
										if (nuxmvQueryGenerator.isSynchronousSourceInEvent(id)) {
											id.parseSynchronousInEvent(value, step)
										}
										// Synchronous in-event parameter
										else if (nuxmvQueryGenerator.isSynchronousSourceInEventParameter(id)) {
											id.parseSynchronousInEventParameter(value, step)
										}
										// Asynchronous in-event
										else if (nuxmvQueryGenerator.isAsynchronousSourceMessageQueue(id)) {
											id.parseAsynchronousInEvent(value, step)
										}
										// Asynchronous in-event parameter
										else if (nuxmvQueryGenerator.isAsynchronousSourceInEventParameter(id)) {
											id.parseAsynchronousInEventParameter(value, step)
										}
									}
									default:
										throw new IllegalArgumentException("Not known state: " + state)
								}
							}
							catch (IndexOutOfBoundsException e) {
								// In the SMV mapping, the arrays are set to have a larger capacity by one
								// So out of indexing will result in the default value
								checkState(id.isArray(value))
							}
						}
					}
				}
			}
			// Checking the last state
			step.checkInEvents // In events can be deleted here?
			if (!step.containsType(Reset)) {
				step.addSchedulingIfNeeded
			}
			step.checkStates
			// Sorting if needed
			if (sortTrace) {
				trace.sortInstanceStates
			}
		} catch (NoSuchElementException e) {
			// If there are not enough lines, that means there are no environment actions
			step.actions += createReset
		}
		
		trace.removeInternalEventRaiseActs
		trace.removeTransientVariableReferences // They always have default values
		
		return trace
	}
	
	//
	
	protected def addStep(EObject container) {
		val step = createStep
		switch (container) {
			ExecutionTrace: {
				container.steps += step
				return step
			}
			Cycle: {
				container.steps += step
				return step
			}
			default:
				throw new IllegalArgumentException("Not known object: " + container)
		}
	}
	
	//
	
	enum BackAnnotatorState {INIT, STATE_CHECK, ENVIRONMENT_CHECK}
	
}