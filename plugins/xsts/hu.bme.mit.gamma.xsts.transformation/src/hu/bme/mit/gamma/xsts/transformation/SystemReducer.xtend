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
package hu.bme.mit.gamma.xsts.transformation

import hu.bme.mit.gamma.expression.model.DirectReferenceExpression
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.statechart.composite.CompositeComponent
import hu.bme.mit.gamma.util.GammaEcoreUtil
import hu.bme.mit.gamma.xsts.model.AssignmentAction
import hu.bme.mit.gamma.xsts.model.XSTS
import hu.bme.mit.gamma.xsts.util.XstsActionUtil

import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*
import static extension hu.bme.mit.gamma.xsts.transformation.util.Namings.*

class SystemReducer {
	// Singleton
	public static final SystemReducer INSTANCE =  new SystemReducer
	protected new() {}
	// Auxiliary objects
	protected final extension GammaEcoreUtil expressionUtil = GammaEcoreUtil.INSTANCE
	protected final extension XstsActionUtil xStsActionUtil = XstsActionUtil.INSTANCE
	protected final extension ExpressionModelFactory factory = ExpressionModelFactory.eINSTANCE
	
	def void deleteUnusedPorts(XSTS xSts, CompositeComponent component) {
		val xStsAssignmentActions = xSts.getAllContentsOfType(AssignmentAction) // Caching
		val xStsFalseVariables = newHashSet
		val xStsDeletableVariables = newHashSet
		val xStsDeletableAssignmentActions = newHashSet
		for (instance : component.derivedComponents) {
			for (instancePort : instance.unusedPorts) {
				// In events on required port
				for (inputEvent : instancePort.inputEvents) {
					val inEventName = inputEvent.customizeInputName(instancePort, instance)
					val xStsInEventVariable = xSts.getVariable(inEventName)
					if (xStsInEventVariable !== null) {
						xStsFalseVariables += xStsInEventVariable
						xStsDeletableVariables += xStsInEventVariable
						xStsDeletableAssignmentActions += xStsInEventVariable.getAssignments(xStsAssignmentActions)
						// In-parameters - they can be placed on transitions without trigger, so we do not delete them
//						for (parameter : inputEvent.parameterDeclarations) {
//							val inParamaterName = parameter.customizeInName(instancePort, instance)
//							val xStsInParameterVariable = xSts.getVariable(inParamaterName)
//							if (xStsInParameterVariable !== null) {
//								xStsDeletableVariables += xStsInParameterVariable
//								xStsDeletableAssignmentActions += xStsInParameterVariable.getAssignments(xStsAssignmentActions)
//							}
//						}
					}
				}
				for (outputEvent : instancePort.outputEvents) {
					val outEventName = outputEvent.customizeOutputName(instancePort, instance)
					val xStsOutEventVariable = xSts.getVariable(outEventName)
					if (xStsOutEventVariable !== null) {
						xStsDeletableVariables += xStsOutEventVariable
						xStsDeletableAssignmentActions += xStsOutEventVariable.getAssignments(xStsAssignmentActions)
						// Out-parameters
						for (parameter : outputEvent.parameterDeclarations) {
							val inParamaterName = parameter.customizeOutName(instancePort, instance)
							val xStsOutParameterVariable = xSts.getVariable(inParamaterName)
							if (xStsOutParameterVariable !== null) {
								xStsDeletableVariables += xStsOutParameterVariable
								xStsDeletableAssignmentActions += xStsOutParameterVariable.getAssignments(xStsAssignmentActions)
							}
						}
					}
				}
			}
		}
		// Assignment removal is before falsification, as ReferenceExpressions
		// can be placed inside assignment actions, and the other way around,
		// cast exceptions are thrown!
		for (xStsDeletableAssignmentAction : xStsDeletableAssignmentActions) {
			xStsDeletableAssignmentAction.remove // To speed up the process
		}
		// Deleting references to the input event variables in guards
		// before variable removal as references must be present here
		for (xStsFalseVariable : xStsFalseVariables) {
			val references = xSts.getAllContentsOfType(DirectReferenceExpression)
				.filter[it.declaration === xStsFalseVariable]
			for (reference : references) {
				val falseExpression = createFalseExpression
				falseExpression.replace(reference)
			}
		}
		for (xStsDeletableVariable : xStsDeletableVariables) {
			xStsDeletableVariable.delete // Delete needed due to e.g., transientVariables list
		}
	}
	
}