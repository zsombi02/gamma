/********************************************************************************
 * Copyright (c) 2024 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.xsts.iml.transformation.serialization

import hu.bme.mit.gamma.expression.model.ArrayAccessExpression
import hu.bme.mit.gamma.expression.model.ArrayLiteralExpression
import hu.bme.mit.gamma.expression.model.ArrayTypeDefinition
import hu.bme.mit.gamma.expression.model.Declaration
import hu.bme.mit.gamma.expression.model.DirectReferenceExpression
import hu.bme.mit.gamma.expression.model.EnumerationLiteralDefinition
import hu.bme.mit.gamma.expression.model.EnumerationLiteralExpression
import hu.bme.mit.gamma.expression.model.EqualityExpression
import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.expression.model.FalseExpression
import hu.bme.mit.gamma.expression.model.IfThenElseExpression
import hu.bme.mit.gamma.expression.model.ImplyExpression
import hu.bme.mit.gamma.expression.model.InequalityExpression
import hu.bme.mit.gamma.expression.model.NotExpression
import hu.bme.mit.gamma.expression.model.TrueExpression
import hu.bme.mit.gamma.expression.util.ExpressionEvaluator
import hu.bme.mit.gamma.expression.util.ExpressionTypeDeterminator2
import hu.bme.mit.gamma.util.GammaEcoreUtil
import hu.bme.mit.gamma.xsts.iml.transformation.util.MessageQueueHandler
import hu.bme.mit.gamma.xsts.iml.transformation.util.Namings
import hu.bme.mit.gamma.xsts.model.HavocAction
import hu.bme.mit.gamma.xsts.transformation.util.MessageQueueUtil
import hu.bme.mit.gamma.xsts.util.XstsActionUtil

import static extension hu.bme.mit.gamma.expression.derivedfeatures.ExpressionModelDerivedFeatures.*
import static extension hu.bme.mit.gamma.xsts.derivedfeatures.XstsDerivedFeatures.*
import static extension hu.bme.mit.gamma.xsts.iml.transformation.util.Namings.*

class ExpressionSerializer extends hu.bme.mit.gamma.expression.util.ExpressionSerializer {
	// Singleton
	public static final ExpressionSerializer INSTANCE = new ExpressionSerializer
	protected new() {}
	//
	protected final extension MessageQueueUtil messageQueueUtil = MessageQueueUtil.INSTANCE
	protected final extension MessageQueueHandler messageQueueHandler = MessageQueueHandler.INSTANCE
	protected final extension XstsActionUtil xStsActionUtil = XstsActionUtil.INSTANCE
	protected final extension ExpressionTypeDeterminator2 typeDeterminator = ExpressionTypeDeterminator2.INSTANCE
	protected final extension ExpressionEvaluator expressionEvaluator = ExpressionEvaluator.INSTANCE
	protected final extension GammaEcoreUtil ecoreUtil = GammaEcoreUtil.INSTANCE
	//
	
	override String serialize(Expression expression) {
		if (expression.queueExpression) {
			return expression.serializeQueueExpression
		}
		return super.serialize(expression)
	}
	
	//
	
	def String superSerialize(Expression expression) {
		return super.serialize(expression)
	}
	
	//
	
	override String _serialize(TrueExpression expression) '''true'''

	override String _serialize(FalseExpression expression) '''false'''
	
	override String _serialize(NotExpression expression) '''(not («expression.operand.serialize»))'''
	
	override String _serialize(ImplyExpression expression) '''(«expression.leftOperand.serialize» ==> «expression.rightOperand.serialize»)'''
	
	override String _serialize(EqualityExpression expression) '''(«expression.leftOperand.serialize» = «expression.rightOperand.serialize»)'''
	
	override String _serialize(InequalityExpression expression) '''(«expression.leftOperand.serialize» <> «expression.rightOperand.serialize»)'''
	
	override String _serialize(IfThenElseExpression expression) '''(if «expression.condition.serialize» then «expression.then.serialize» else «expression.^else.serialize»)'''

	override String _serialize(EnumerationLiteralExpression expression) '''«expression.serializeName»'''
	
	override String _serialize(DirectReferenceExpression expression) {
		val declaration = expression.declaration
		return '''«declaration.id».«declaration.serializeName»'''
	}
	
	override String _serialize(ArrayAccessExpression arrayAccessExpression) '''(Map.get «arrayAccessExpression.index.serialize» «arrayAccessExpression.operand.serialize»)'''
	
	override String _serialize(ArrayLiteralExpression expression) {
		val operands = expression.operands
		val typeDefinition = expression.typeDefinition as ArrayTypeDefinition
		
		val defaultExpression = typeDefinition.elementType.defaultExpression
		val imlDefaultValue = defaultExpression.serialize
		
		var imlArrayLiteral = '''(Map.const «imlDefaultValue»)'''
		
		if (!defaultExpression.typeDefinition.array) {
			val evaluatedDefaultExpression = defaultExpression.evaluate
			if (operands.forall[it.helperEquals(defaultExpression) || it.evaluable && it.evaluate == evaluatedDefaultExpression]) {
				return imlArrayLiteral.toString // No need for Map.add commands
			}
		}
		
		for (var i = 0; i < operands.size; i++) {
			val operand = operands.get(i)
			imlArrayLiteral = '''(Map.add «i» «operand.serialize» «imlArrayLiteral»)'''
		} 
		
		return imlArrayLiteral
	}
	
	//

	def String serializeAsLhs(Declaration declaration) {
		return declaration.serializeName
	}
	
	def String serializeAsRhs(Declaration declaration) {
		return declaration.createReferenceExpression.serialize
	}

	/**
	 * See https://dev.realworldocaml.org/guided-tour.html#ocaml-as-a-calculator.
	 * Note that there are some constraints on what identifiers can be used for variable names.
	 * Punctuation is excluded, except for _ and ', and variables must start with a lowercase letter or an underscore.
	 */
	def String serializeName(Declaration declaration) {
		val customizedName = declaration.customizeName
		return customizedName
	}
	
	def String serializeName(EnumerationLiteralExpression literal) {
		val customizedName = literal.customizeName
		return customizedName
	}
	
	def String serializeName(EnumerationLiteralDefinition literal) {
		val customizedName = literal.customizeName
		return customizedName
	}
	
	def serializeFieldName(HavocAction havoc) {
		val customizedName = havoc.customizeHavocField
		return customizedName
	}
	
	//
	
	def getId(Declaration declaration) {
		if (declaration.global) {
			return Namings.GLOBAL_RECORD_IDENTIFIER
		}
		return Namings.LOCAL_RECORD_IDENTIFIER
	}
	
}