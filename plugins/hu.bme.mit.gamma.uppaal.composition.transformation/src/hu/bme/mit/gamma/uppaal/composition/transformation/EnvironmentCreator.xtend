/********************************************************************************
 * Copyright (c) 2018-2020 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.uppaal.composition.transformation

import hu.bme.mit.gamma.expression.model.EnumerationLiteralExpression
import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.expression.model.IntegerLiteralExpression
import hu.bme.mit.gamma.statechart.model.Port
import hu.bme.mit.gamma.statechart.model.composite.AsynchronousAdapter
import hu.bme.mit.gamma.statechart.model.composite.ComponentInstance
import hu.bme.mit.gamma.statechart.model.composite.SynchronousComponentInstance
import hu.bme.mit.gamma.statechart.model.interface_.Event
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.DistinctWrapperInEvents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.TopAsyncCompositeComponents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.TopAsyncSystemInEvents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.TopSyncSystemInEvents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.TopUnwrappedSyncComponents
import hu.bme.mit.gamma.uppaal.composition.transformation.queries.TopWrapperComponents
import hu.bme.mit.gamma.uppaal.transformation.queries.ValuesOfEventParameters
import hu.bme.mit.gamma.uppaal.transformation.traceability.MessageQueueTrace
import java.math.BigInteger
import java.util.Collection
import java.util.HashSet
import java.util.Set
import java.util.logging.Level
import java.util.logging.Logger
import org.eclipse.viatra.query.runtime.api.ViatraQueryEngine
import org.eclipse.viatra.transformation.runtime.emf.modelmanipulation.IModelManipulations
import org.eclipse.viatra.transformation.runtime.emf.rules.batch.BatchTransformationRule
import org.eclipse.viatra.transformation.runtime.emf.rules.batch.BatchTransformationRuleFactory
import uppaal.declarations.DataVariableDeclaration
import uppaal.expressions.ExpressionsFactory
import uppaal.expressions.ExpressionsPackage
import uppaal.expressions.LogicalOperator
import uppaal.templates.Edge
import uppaal.templates.Location
import uppaal.templates.TemplatesPackage

import static extension hu.bme.mit.gamma.statechart.model.derivedfeatures.StatechartModelDerivedFeatures.*
import hu.bme.mit.gamma.expression.util.ExpressionUtil

class EnvironmentCreator {
	// Logger
	protected extension Logger logger = Logger.getLogger("GammaLogger")
	// Transformation rule-related extensions
	protected extension BatchTransformationRuleFactory = new BatchTransformationRuleFactory
	protected final extension IModelManipulations manipulation
	// Trace
	protected final extension Trace modelTrace
	// Engine
	protected final extension ViatraQueryEngine engine
	// UPPAAL packages
	protected final extension TemplatesPackage temPackage = TemplatesPackage.eINSTANCE
	protected final extension ExpressionsPackage expPackage = ExpressionsPackage.eINSTANCE
	// UPPAAL factories
	protected final extension ExpressionsFactory expFact = ExpressionsFactory.eINSTANCE
	// Gamma factories
	protected final extension ExpressionModelFactory emFact = ExpressionModelFactory.eINSTANCE
	// Id
	var id = 0
	protected final DataVariableDeclaration isStableVar
	// Auxiliary objects
	protected final extension ExpressionUtil expressionUtil = new ExpressionUtil
	protected final extension AsynchronousComponentHelper asynchronousComponentHelper
	protected final extension NtaBuilder ntaBuilder
	protected final extension AssignmentExpressionCreator assignmentExpressionCreator
	protected final extension ExpressionEvaluator expressionEvaluator
	// Rules
	protected BatchTransformationRule<TopUnwrappedSyncComponents.Match, TopUnwrappedSyncComponents.Matcher> topSyncEnvironmentRule
	protected BatchTransformationRule<TopWrapperComponents.Match, TopWrapperComponents.Matcher> topWrapperEnvironmentRule
	protected BatchTransformationRule<TopAsyncCompositeComponents.Match, TopAsyncCompositeComponents.Matcher> instanceWrapperEnvironmentRule
	
	new(NtaBuilder ntaBuilder, ViatraQueryEngine engine, IModelManipulations manipulation,
			AssignmentExpressionCreator assignmentExpressionCreator, AsynchronousComponentHelper asynchronousComponentHelper,
			Trace modelTrace, DataVariableDeclaration isStableVar) {
		this.ntaBuilder = ntaBuilder
		this.engine = engine
		this.manipulation = manipulation
		this.assignmentExpressionCreator = assignmentExpressionCreator
		this.asynchronousComponentHelper = asynchronousComponentHelper
		this.expressionEvaluator = new ExpressionEvaluator(this.engine)
		this.modelTrace = modelTrace
		this.isStableVar = isStableVar
	}
	
	/**
	 * Responsible for creating the control template that enables the user to fire events.
	 */
	def getTopSyncEnvironmentRule() {
		if (topSyncEnvironmentRule === null) {
			topSyncEnvironmentRule = createRule(TopUnwrappedSyncComponents.instance).action [
				val initLoc = createTemplateWithInitLoc("Environment", "InitLoc")
				val template = initLoc.parentTemplate
				val loopEdges = newHashMap
				// Simple event raisings
				for (systemPort : it.syncComposite.ports) {
					for (inEvent : systemPort.inputEvents) {
						var Edge loopEdge = null // Needed as now a port with only in events can be bound to multiple instance ports
						for (match : TopSyncSystemInEvents.Matcher.on(engine).getAllMatches(it.syncComposite, systemPort, null, null, inEvent)) {
							val toRaiseVar = match.event.getToRaiseVariable(match.port, match.instance)
							log(Level.INFO, "Information: System in event: " + match.instance.name + "." + match.port.name + "_" + match.event.name)
							if (loopEdge === null) {
								loopEdge = initLoc.createLoopEdgeWithGuardedBoolAssignment(toRaiseVar)
								loopEdge.addGuard(isStableVar, LogicalOperator.AND)
								loopEdges.put(new Pair(systemPort, inEvent), loopEdge)
							}
							else {
								loopEdge.extendLoopEdgeWithGuardedBoolAssignment(toRaiseVar)
							}
						}
					}
				}
				// Parameter adding if necessary
				for (systemPort : it.syncComposite.ports) {
					for (inEvent : systemPort.inputEvents) {
						var Edge loopEdge = loopEdges.get(new Pair(systemPort, inEvent))
						var Collection<Expression> expressionSet = new HashSet
						for (match : TopSyncSystemInEvents.Matcher.on(engine).getAllMatches(it.syncComposite, systemPort, null, null, inEvent)) {
							// Collecting parameter values for each instant event
							expressionSet += ValuesOfEventParameters.Matcher.on(engine).getAllValuesOfexpression(match.port, match.event)
						}
						// Removing the expression duplications (that are evaluated to the same expression)
						val expressions = expressionSet.removeDuplicatedExpressions
						if (!expressions.empty) {
							// Removing original edge from the model - only if there is a valid expression
							template.edge -= loopEdge
							for (expression : expressions) {
								// Putting variables raising for ALL instance parameters
		   						val clonedLoopEdge = loopEdge.clone(true, true)
		   						for (innerMatch : TopSyncSystemInEvents.Matcher.on(engine).getAllMatches(it.syncComposite, systemPort, null, null, inEvent)) {
									clonedLoopEdge.extendValueOfLoopEdge(innerMatch.port, innerMatch.event, innerMatch.instance, expression)
								}
								template.edge += clonedLoopEdge
								expression.removeGammaElementFromTrace
							}
							// Adding a different value if the type is an integer
							if (expressionSet.filter(EnumerationLiteralExpression).empty &&
									!expressions.empty) {
			   					val clonedLoopEdge = loopEdge.clone(true, true)
								val maxValue = expressions.filter(IntegerLiteralExpression).map[it.value].max
								val biggerThanMax = constrFactory.createIntegerLiteralExpression => [it.value = maxValue.add(BigInteger.ONE)]
								for (innerMatch : TopSyncSystemInEvents.Matcher.on(engine).getAllMatches(it.syncComposite, systemPort, null, null, inEvent)) {
									clonedLoopEdge.extendValueOfLoopEdge(innerMatch.port, innerMatch.event, innerMatch.instance, biggerThanMax)
								}
								template.edge += clonedLoopEdge
								biggerThanMax.removeGammaElementFromTrace
							}
						}
					}
				}
			].build
		}
	}
	
	private def void extendValueOfLoopEdge(Edge loopEdge, Port port, Event event, ComponentInstance owner, Expression expression) {
		val valueOfVars = event.parameterDeclarations.head.allValuesOfTo.filter(DataVariableDeclaration)
							.filter[it.owner == owner && it.port == port]
		if (valueOfVars.size != 1) {
			throw new IllegalArgumentException("Not one valueOfVar: " + valueOfVars)
		}
		val valueOfVar = valueOfVars.head
		loopEdge.createAssignmentExpression(edge_Update, valueOfVar, expression, owner)
	}
	
	def getTopWrapperEnvironmentRule() {
		if (topWrapperEnvironmentRule === null) {
			topWrapperEnvironmentRule = createRule(TopWrapperComponents.instance).action [
				// Creating the template
				val initLoc = createTemplateWithInitLoc(it.wrapper.name + "Environment" + id++, "InitLoc")
				val component = wrapper.wrappedComponent.type
				for (match : TopSyncSystemInEvents.Matcher.on(engine).getAllMatches(component, null, null, null, null)) {
					val queue = wrapper.getContainerMessageQueue(match.systemPort /*Wrapper port*/, match.event) // In what message queue this event is stored
					val messageQueueTrace = queue.getTrace(null) // Getting the owner
					// Creating the loop edge (or edges in case of parameterized events)
					initLoc.createEnvironmentLoopEdges(messageQueueTrace, match.systemPort, match.event, match.instance /*Sync owner*/)		
				}
				for (match : DistinctWrapperInEvents.Matcher.on(engine).getAllMatches(wrapper, null, null)) {
					val queue = wrapper.getContainerMessageQueue(match.port, match.event) // In what message queue this event is stored
					val messageQueueTrace = queue.getTrace(null) // Getting the owner
					// Creating the loop edge (or edges in case of parameterized events)
					initLoc.createEnvironmentLoopEdges(messageQueueTrace, match.port, match.event, null)		
				}
			].build
		}
	}
	
	private def void createEnvironmentLoopEdges(Location initLoc, MessageQueueTrace messageQueueTrace,
			Port port, Event event, SynchronousComponentInstance owner) {
		// Checking the parameters
		val expressions = ValuesOfEventParameters.Matcher.on(engine).getAllValuesOfexpression(port, event)
		for (expression : expressions) {
			// New edge is needed in every iteration!
			val loopEdge = initLoc.createEdge(initLoc)
			loopEdge.extendEnvironmentEdge(messageQueueTrace, event.getConstRepresentation(port), expression, owner)
			loopEdge.addGuard(isStableVar, LogicalOperator.AND) // For the cutting of the state space
			loopEdge.addInitializedGuards
		}
		if (expressions.empty) {
			val loopEdge = initLoc.createEdge(initLoc)
			loopEdge.extendEnvironmentEdge(messageQueueTrace, event.getConstRepresentation(port), createLiteralExpression => [it.text = "0"])
			loopEdge.addGuard(isStableVar, LogicalOperator.AND) // For the cutting of the state space
			loopEdge.addInitializedGuards
		}
	}
	
	def getInstanceWrapperEnvironmentRule() {
		if (instanceWrapperEnvironmentRule === null) {
			instanceWrapperEnvironmentRule = createRule(TopAsyncCompositeComponents.instance).action [
				// Creating the template
				val initLoc = createTemplateWithInitLoc(it.asyncComposite.name + "Environment" + id++, "InitLoc")
				// Collecting in event parameters
				val parameterMap = newHashMap
				for (systemPort : it.asyncComposite.ports) {
					for (inEvent : systemPort.inputEvents) {
						for (match : TopAsyncSystemInEvents.Matcher.on(engine).getAllMatches(it.asyncComposite, systemPort, null, null, inEvent)) {
							val expressions = ValuesOfEventParameters.Matcher.on(engine).getAllValuesOfexpression(match.port, match.event)
							var Set<Expression> expressionList
							if (!parameterMap.containsKey(new Pair(systemPort, inEvent))) {
								expressionList = newHashSet
								parameterMap.put(new Pair(systemPort, inEvent), expressionList)
							}
							else {
								expressionList = parameterMap.get(new Pair(systemPort, inEvent))
							}
							expressionList += expressions
						}
					}
				}
				// Setting updates, one update may affect multiple queues (full in port events can be connected to multiple instance ports)
				for (systemPort : it.asyncComposite.ports) {
					for (inEvent : systemPort.inputEvents) {
						val expressionList = parameterMap.get(new Pair(systemPort, inEvent))
						if (expressionList.empty) {
								val loopEdge = initLoc.createEdge(initLoc)
								loopEdge.addGuard(isStableVar, LogicalOperator.AND) // For the cutting of the state space
								loopEdge.addInitializedGuards
								for (match : TopAsyncSystemInEvents.Matcher.on(engine).getAllMatches(it.asyncComposite, systemPort, null, null, inEvent)) {
									val wrapper = match.instance.type as AsynchronousAdapter
									val queue = wrapper.getContainerMessageQueue(match.port /*Wrapper port, this is the instance port*/, match.event) // In what message queue this event is stored
									val messageQueueTrace = queue.getTrace(match.instance) // Getting the owner
									loopEdge.extendEnvironmentEdge(messageQueueTrace, match.event.getConstRepresentation(match.port), createLiteralExpression => [it.text = "0"])
								}
						}
						else {
							val expressionSet = expressionList.removeDuplicatedExpressions
							for (expression : expressionSet) {
								// New edge is needed in every iteration!
								val loopEdge = initLoc.createEdge(initLoc)
								loopEdge.addGuard(isStableVar, LogicalOperator.AND) // For the cutting of the state space
								loopEdge.addInitializedGuards
								for (match : TopAsyncSystemInEvents.Matcher.on(engine).getAllMatches(it.asyncComposite, systemPort, null, null, inEvent)) {
									val wrapper = match.instance.type as AsynchronousAdapter
									val queue = wrapper.getContainerMessageQueue(match.port /*Wrapper port, this is the instance port*/, match.event) // In what message queue this event is stored
									val messageQueueTrace = queue.getTrace(match.instance) // Getting the owner
									loopEdge.extendEnvironmentEdge(messageQueueTrace, match.event.getConstRepresentation(match.port), expression, null)
								}
							}
						}
					}
				}
			].build
		}
	}
	
	private def void extendEnvironmentEdge(Edge edge, MessageQueueTrace messageQueueTrace,
			DataVariableDeclaration representation, Expression expression, SynchronousComponentInstance instance) {
		// !isFull...
		val isNotFull = createNegationExpression => [
			it.addFunctionCall(negationExpression_NegatedExpression, messageQueueTrace.isFullFunction.function)
		 ]
		edge.addGuard(isNotFull, LogicalOperator.AND)
		// push....
		edge.addPushFunctionUpdate(messageQueueTrace, representation, expression, instance)
	}
	
	private def void extendEnvironmentEdge(Edge edge, MessageQueueTrace messageQueueTrace,
			DataVariableDeclaration representation, uppaal.expressions.Expression expression) {
		// !isFull...
		val isNotFull = createNegationExpression => [
			it.addFunctionCall(negationExpression_NegatedExpression, messageQueueTrace.isFullFunction.function)
		 ]
		edge.addGuard(isNotFull, LogicalOperator.AND)
		// push....
		edge.addPushFunctionUpdate(messageQueueTrace, representation, expression)
	}
	
}