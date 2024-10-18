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
package hu.bme.mit.gamma.property.language.validation

import hu.bme.mit.gamma.property.model.Contract
import hu.bme.mit.gamma.property.model.PathQuantifier
import hu.bme.mit.gamma.property.model.QuantifiedFormula
import hu.bme.mit.gamma.property.model.StateFormula
import hu.bme.mit.gamma.property.util.PropertyModelValidator
import hu.bme.mit.gamma.statechart.composite.ComponentInstanceReferenceExpression
import hu.bme.mit.gamma.statechart.statechart.PortEventReference
import java.util.List
import org.eclipse.xtext.validation.Check

import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*

class PropertyLanguageValidator extends AbstractPropertyLanguageValidator {
	
	protected final PropertyModelValidator validator = PropertyModelValidator.INSTANCE
	
	new() {
		super.expressionModelValidator = validator
		super.actionModelValidator = validator
		super.statechartModelValidator = validator
	}
	
	@Check
	override checkComponentInstanceReferences(ComponentInstanceReferenceExpression reference) {
		handleValidationResultMessage(validator.checkComponentInstanceReferences(reference))
	}
	
	
	@Check
	def checkContractInstance(Contract contract) {
		//contract.instance = contract.instance.lastInstanceReference
	    if (contract.instance !== null) {
	        checkMatchingComponentInstance(contract)
	        checkRootReferencesWhenInstanceProvided(contract)
	    } else {
	        checkNoInstanceProvided(contract)
	    }
	}
	
	def checkMatchingComponentInstance(Contract contract) {
	    val assumeReferences = getLastComponentInstanceReferences(contract.assume)
	    val guaranteeReferences = getLastComponentInstanceReferences(contract.guarantee)
	    val contractLastInstance = contract.instance.lastInstanceReference
	    
	    assumeReferences.forEach [ref |
	        if (!isSameComponentInstance(ref, contractLastInstance)) {
	        	error('The ComponentInstanceReferenceExpression in the assume formula does not match the instance declared in the contract header.', contract.assume, null)
	        }
	    ]
	    guaranteeReferences.forEach [ref |
	        if (!isSameComponentInstance(ref, contractLastInstance)) {
	            error('The ComponentInstanceReferenceExpression in the guarantee formula does not match the instance declared in the contract header.', contract.guarantee, null)
	        }
	    ]
	}
	
	def checkRootReferencesWhenInstanceProvided(Contract contract) {
	    val assumeRootReferences = getAllRootElementReferences(contract.assume)
	    val guaranteeRootReferences = getAllRootElementReferences(contract.guarantee)
	    if (!assumeRootReferences.empty) {
	        error('RootElementReference (e.g., "self") is not allowed in the assume formula when an instance is declared in the contract header.', contract.assume, null)
	    }
	    if (!guaranteeRootReferences.empty) {
	        error('RootElementReference (e.g., "self") is not allowed in the guarantee formula when an instance is declared in the contract header.', contract.assume, null)
	    }
	}
	
	def checkNoInstanceProvided(Contract contract) {
	    val assumeReferences = getLastComponentInstanceReferences(contract.assume)
	    val guaranteeReferences = getLastComponentInstanceReferences(contract.guarantee)
	    if (!assumeReferences.empty) {
	        error('No ComponentInstanceReferenceExpression is allowed in the assume formula since no instance is declared in the contract header.', contract.assume, null)
	    }
	    if (!guaranteeReferences.empty) {
	        error('No ComponentInstanceReferenceExpression is allowed in the guarantee formula since no instance is declared in the contract header.', contract.assume, null)
	    }
	}
	
	@Check
	def checkNoExistentialQuantifierInContracts(Contract contract) {
	    // Get all QuantifiedFormulas in the assume and guarantee formulas
	    val assumeQuantifiedFormulas = ecoreUtil.getSelfAndAllContentsOfType(contract.assume, QuantifiedFormula)
	    val guaranteeQuantifiedFormulas = ecoreUtil.getSelfAndAllContentsOfType(contract.guarantee, QuantifiedFormula)
	
	    // Check if any QuantifiedFormula uses the 'EXISTS (E)' quantifier
	    assumeQuantifiedFormulas.forEach [quantifiedFormula |
	        if (quantifiedFormula.quantifier == PathQuantifier.EXISTS) {
	            error('EXISTS (E) quantifier is not allowed in the assume formula of contracts.', contract.assume, null)
	        }
	    ]
	    
	    guaranteeQuantifiedFormulas.forEach [quantifiedFormula |
	        if (quantifiedFormula.quantifier == PathQuantifier.EXISTS) {
	            error('EXISTS (E) quantifier is not allowed in the guarantee formula of contracts.', contract.guarantee, null)
	        }
	    ]
	}
	
	def List<PortEventReference> getAllRootElementReferences(StateFormula formula) {
    return ecoreUtil.getAllContentsOfType(formula, PortEventReference)
	}
	
	def List<ComponentInstanceReferenceExpression> getLastComponentInstanceReferences(StateFormula formula) {
        // Collect all ComponentInstanceReferenceExpression from the formula
    val references = ecoreUtil.getAllContentsOfType(formula, ComponentInstanceReferenceExpression)
    
    // Map each reference to its last instance
    return references.map [
        it.lastInstanceReference
    ]
}
	
	def boolean isSameComponentInstance(ComponentInstanceReferenceExpression instance1, ComponentInstanceReferenceExpression instance2) {
	    if (instance1 === null || instance2 === null) {
	        return false
	    }
	    val componentInstance1 = instance1.componentInstance
	    val componentInstance2 = instance2.componentInstance
	    return componentInstance1 == componentInstance2
	}
	
}