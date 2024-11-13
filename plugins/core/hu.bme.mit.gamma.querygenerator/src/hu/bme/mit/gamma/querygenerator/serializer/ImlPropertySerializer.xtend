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
package hu.bme.mit.gamma.querygenerator.serializer

import hu.bme.mit.gamma.expression.model.Comment
import hu.bme.mit.gamma.property.model.AtomicFormula
import hu.bme.mit.gamma.property.model.BinaryLogicalOperator
import hu.bme.mit.gamma.property.model.BinaryOperandPathFormula
import hu.bme.mit.gamma.property.model.BinaryPathOperator
import hu.bme.mit.gamma.property.model.PathFormula
import hu.bme.mit.gamma.property.model.PathQuantifier
import hu.bme.mit.gamma.property.model.QuantifiedFormula
import hu.bme.mit.gamma.property.model.StateFormula
import hu.bme.mit.gamma.property.model.TemporalPathFormula
import hu.bme.mit.gamma.property.model.UnaryLogicalOperator
import hu.bme.mit.gamma.property.model.UnaryOperandPathFormula
import hu.bme.mit.gamma.property.model.UnaryPathOperator
import hu.bme.mit.gamma.xsts.iml.transformation.util.Namings

import static com.google.common.base.Preconditions.checkArgument

import static extension hu.bme.mit.gamma.property.derivedfeatures.PropertyModelDerivedFeatures.*

class ImlPropertySerializer extends ThetaPropertySerializer {
	//
	public static final ImlPropertySerializer INSTANCE = new ImlPropertySerializer
	protected new() {
		super.serializer = new ImlPropertyExpressionSerializer(ImlReferenceSerializer.INSTANCE)
	}
	//
	
	protected override isValidFormula(StateFormula formula) {
		// Note that this translation supports LTL with FINITE traces (no loops at the end)
		// Also, the formula has to be in NNF while
		// under A, we can have X, G and R, and
		// under E, we can have X, F and U
		val unaryOperators = formula.getSelfAndAllContentsOfType(UnaryOperandPathFormula).map[it.operator]
		val binaryOperators = formula.getSelfAndAllContentsOfType(BinaryOperandPathFormula).map[it.operator]
		
		return formula.ltl &&
			(formula.isAQuantified) ?
		/* A */	unaryOperators.forall[ #[UnaryPathOperator.NEXT, UnaryPathOperator.GLOBAL].contains(it) ] &&
				binaryOperators.forall[ #[BinaryPathOperator.RELEASE].contains(it) ] :
		/* E */	unaryOperators.forall[ #[UnaryPathOperator.NEXT, UnaryPathOperator.FUTURE].contains(it) ] &&
				binaryOperators.forall[ #[BinaryPathOperator.UNTIL].contains(it) ]
	}
	
	override serialize(Comment comment) '''(* «comment.comment» *)'''
	
	override serialize(StateFormula formula) {
		val nnfFormula = formula.createNegationNormalForm
		
		val serializedFormula = nnfFormula.serializeFormula
		
		if (!formula.helperEquals(nnfFormula)) {
			logger.info("Transformed property into negation normal form (NNF): " + serializedFormula)
		}
		checkArgument(nnfFormula.validFormula, "Unsupported property specification: " + serializedFormula)
		
		return serializedFormula
	}
	
	//
	
	protected override dispatch String serializeFormula(AtomicFormula formula) {
		return formula.expression.serialize
	}
	
	protected override dispatch String serializeFormula(QuantifiedFormula formula) {
		val quantifier = formula.quantifier // A or E
		val imandraCall = (quantifier == PathQuantifier.FORALL) ? "verify" : "instance"
		
		val pathFormula = formula.formula
		val inputtableFormulas = formula.relevantTemporalPathFormulas
		return '''«imandraCall»(fun«FOR e : inputtableFormulas» «e.inputId»«ENDFOR» -> let «
				recordId» = «Namings.INIT_FUNCTION_IDENTIFIER» in «pathFormula.serializeFormula»)'''
	}
	
	protected override dispatch String serializeFormula(UnaryOperandPathFormula formula) {
		val operator = formula.operator // G, F or X
		val functionName = operator.functionName
		val operand = formula.operand
		return '''let «recordId» = «functionName» «recordId» «formula.inputId» in «operand.serializeFormula»'''
	}
	
	protected override dispatch String serializeFormula(BinaryOperandPathFormula formula) {
		val operator = formula.operator
		val lhsOperand = formula.leftOperand
		val rhsOperand = formula.rightOperand
		switch (operator) {
			case UNTIL: { // Supported only under E
				return '''((let «recordId» = «Namings.RUN_FUNCTION_IDENTIFIER» «recordId» «
						formula.inputId» in «rhsOperand.serializeFormula») && («
							forallPrefixName» «recordId» «formula.inputId» (fun r -> «lhsOperand.serializeFormula»)))'''
			}
			case RELEASE: { // Supported only under A
				return '''((let «recordId» = «Namings.RUN_FUNCTION_IDENTIFIER» «recordId» «
						formula.inputId» in «rhsOperand.serializeFormula») || («
							existsPrefixName» «recordId» «formula.inputId» (fun r -> «lhsOperand.serializeFormula» && «rhsOperand.serializeFormula»)))'''
			}
			default:
				throw new IllegalArgumentException("Not supported operator: " + operator)
		}
	}
	
	//
	
	protected override transform(UnaryLogicalOperator operator) {
		switch (operator) {
			case NOT: "not"
			default: throw new IllegalArgumentException("Not supported operator: " + operator)
		}
	}
	
	protected override transform(BinaryLogicalOperator operator) {
		switch (operator) {
			case AND: "&&"
			case IMPLY: "==>"
			case OR: "||"
			case XOR: "^"
			default: throw new IllegalArgumentException("Not supported operator: " + operator)
		}
	}
	
	//
	
//	protected def tailorFormula(QuantifiedFormula formula) {
//		if (formula instanceof QuantifiedFormula) {
//			val clonedFormula = formula.clone // So no side-effect
//			val pathFormulas = clonedFormula.relevantTemporalPathFormulas
//			val unaryOperandPathFormulas = pathFormulas.filter(UnaryOperandPathFormula)
//			val quantifier = clonedFormula.quantifier
//			//
//			if (quantifier == PathQuantifier.EXISTS) { // E
//				val globals = unaryOperandPathFormulas.filter[it.operator == UnaryPathOperator.GLOBAL]
//				for (global : globals) { // G cannot be after E, but: G p === !F!p
//					global.changeToDual
//				}
//				return clonedFormula
//			}
//			else { // A
//				val futures = unaryOperandPathFormulas.filter[it.operator == UnaryPathOperator.FUTURE]
//				for (future : futures) { // F cannot be after A, but: F p === !G!p
//					future.changeToDual
//				}
//				return clonedFormula
//			}
//		}
//		return formula
//	}
	
	//
	
	protected def getRelevantTemporalPathFormulas(PathFormula formula) {
		// We consider levels of F, G, X and U operators in-between A and E quantifiers
		// to support multiple level of A/E nesting (CTL*)
		return formula.getAllContentsOfTypeBetweenTypes(QuantifiedFormula, TemporalPathFormula)
	}
	
	protected def getRecordId() {
		return ImlReferenceSerializer.recordIdentifier
	}
	
	protected def getInputId() {
		return "e"
	}
	
	protected def getPostfix(TemporalPathFormula formula) {
		val unaryOperandPathFormulas = formula.relevantTemporalPathFormulas
		val containingTemporalPathFormulas = formula.getAllContainersOfType(TemporalPathFormula)
		
		val operator = if (formula instanceof UnaryOperandPathFormula) {
			formula.operator.toString
		}
		else if (formula instanceof BinaryOperandPathFormula) {
			formula.operator.toString
		}
		else {
			throw new IllegalArgumentException("Not known formula: " + formula)
		}
		
		val postfix = '''_«containingTemporalPathFormulas.size»_«operator»_«unaryOperandPathFormulas.indexOf(formula)»'''
		
		return postfix
	}
	
	protected def getInputId(TemporalPathFormula formula) {
		return inputId + formula.postfix
	}
	
	protected def getFunctionName(UnaryPathOperator operator) {
		switch (operator) {
			case FUTURE,
			case GLOBAL: return Namings.RUN_FUNCTION_IDENTIFIER
			case NEXT: return Namings.SINGLE_RUN_FUNCTION_IDENTIFIER
			default: throw new IllegalArgumentException("Not known operator: " + operator)
		}
	}
	
	protected def getForallPrefixName() '''forall_prefix'''
	protected def getExistsPrefixName() '''exists_prefix'''
	
}