/********************************************************************************
 * Copyright (c) 2018-2024 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.property.derivedfeatures;

import java.util.List;

import hu.bme.mit.gamma.property.model.AtomicFormula;
import hu.bme.mit.gamma.property.model.BinaryLogicalOperator;
import hu.bme.mit.gamma.property.model.BinaryOperandPathFormula;
import hu.bme.mit.gamma.property.model.BinaryPathOperator;
import hu.bme.mit.gamma.property.model.CommentableStateFormula;
import hu.bme.mit.gamma.property.model.PathFormula;
import hu.bme.mit.gamma.property.model.PathQuantifier;
import hu.bme.mit.gamma.property.model.PropertyPackage;
import hu.bme.mit.gamma.property.model.QuantifiedFormula;
import hu.bme.mit.gamma.property.model.StateFormula;
import hu.bme.mit.gamma.property.model.UnaryOperandPathFormula;
import hu.bme.mit.gamma.property.model.UnaryPathOperator;
import hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures;
import hu.bme.mit.gamma.statechart.interface_.Component;
import hu.bme.mit.gamma.statechart.interface_.Package;

public class PropertyModelDerivedFeatures extends StatechartModelDerivedFeatures {

	public static boolean isUnfolded(PropertyPackage propertyPackage) {
		Component component = propertyPackage.getComponent();
		Package containingPackage = getContainingPackage(component);
		return isUnfolded(containingPackage);
		// Atomic instance references?
	}
	
	public static boolean areAllPropertiesInvariants(PropertyPackage propertyPackage) {
		return propertyPackage.getFormulas().stream()
				.allMatch(it -> isInvariant(it));
	}
	
	public static boolean isInvariant(CommentableStateFormula commentableStateFormula) {
		StateFormula formula = commentableStateFormula.getFormula();
		return isInvariant(formula);
	}
	
	public static boolean isInvariant(StateFormula formula) {
		if (formula instanceof QuantifiedFormula quantifiedFormula) {
			PathQuantifier quantifier = quantifiedFormula.getQuantifier();
			PathFormula pathFormula = quantifiedFormula.getFormula();
			if (pathFormula instanceof UnaryOperandPathFormula unaryOperandPathFormula) {
				UnaryPathOperator operator = unaryOperandPathFormula.getOperator();
				PathFormula operand = unaryOperandPathFormula.getOperand();
				if (operand instanceof AtomicFormula) {
					return quantifier == PathQuantifier.FORALL && operator == UnaryPathOperator.GLOBAL || // AG
							quantifier == PathQuantifier.EXISTS && operator == UnaryPathOperator.FUTURE; // EF
				}
			}
		}
		
		return false;
	}
	
	public static boolean isLtl(PathFormula formula) {
		List<QuantifiedFormula> quantifiedFormulas = ecoreUtil.getSelfAndAllContentsOfType(
				formula, QuantifiedFormula.class);
		return quantifiedFormulas.isEmpty()||
				quantifiedFormulas.size() == 1 && quantifiedFormulas.get(0) == formula;
	}
	
	public static boolean containsBinaryPathOperators(PathFormula formula) {
		return !ecoreUtil.getSelfAndAllContentsOfType(
				formula, BinaryOperandPathFormula.class).isEmpty();
	}
	
	public static UnaryPathOperator getDual(UnaryPathOperator operator) {
		switch (operator) {
			case FUTURE:
				return UnaryPathOperator.GLOBAL;
			case GLOBAL:
				return UnaryPathOperator.FUTURE;
			default:
				return operator;
		}
	}
	
	public static BinaryPathOperator getDual(BinaryPathOperator operator) {
		switch (operator) {
			case RELEASE:
				return BinaryPathOperator.UNTIL;
			case STRONG_RELEASE:
				return BinaryPathOperator.WEAK_UNTIL;
			case UNTIL:
				return BinaryPathOperator.RELEASE;
			case WEAK_UNTIL:
				return BinaryPathOperator.STRONG_RELEASE;
			default:
				throw new IllegalArgumentException("Not known operator: " + operator);
		}
	}
	
	public static BinaryLogicalOperator getDual(BinaryLogicalOperator operator) {
		switch (operator) {
			case AND:
				return BinaryLogicalOperator.OR;
			case OR:
				return BinaryLogicalOperator.AND;
			default:
				throw new IllegalArgumentException("Not known operator: " + operator);
		}
	}
	
}
