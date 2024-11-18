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
package hu.bme.mit.gamma.iml.verification

import hu.bme.mit.gamma.util.FileUtil
import hu.bme.mit.gamma.util.ScannerLogger
import java.io.File
import java.util.Scanner
import java.util.logging.Logger

class ImlSemanticDiffer {
	//
	public static final String IMANDRA_TEMPORARY_COMMAND_FOLDER = ".imandra"
	final String DIFF_FUNCTION_NAME = "trans"
	final String NEW_DIFF_FUNCTION_NAME = DIFF_FUNCTION_NAME + 2
	//
	protected final static extension FileUtil fileUtil = FileUtil.INSTANCE
	protected final Logger logger = Logger.getLogger("GammaLogger")
	//
	
	def execute(Object traceability, File modelFile, File modelFile2) {
		val src = modelFile.loadString
		val src2 = modelFile2.loadString
		
		val trans2 = src2.extractTransFunction
		
		val model = '''
			«src»
			«trans2»
		'''
		
		val DIFF_PREDICATE_NAME = "diff"
		val diffFunction = '''
			let «DIFF_PREDICATE_NAME» (r : t) = ((«DIFF_FUNCTION_NAME» r) <> («NEW_DIFF_FUNCTION_NAME» r));;
		'''
		
		val decomp = '''
			Modular_decomp.top ~assuming:"«DIFF_PREDICATE_NAME»" "«NEW_DIFF_FUNCTION_NAME»";;
		'''
		
		val cmd = ImlApiHelper.getBasicCall('''
			«model»
			«diffFunction»
			«decomp»
		''')
		
		///
		
		val parentFile = modelFile.parentFile + File.separator + IMANDRA_TEMPORARY_COMMAND_FOLDER
		val pythonFile = new File(parentFile, '''.imandra-commands-«Thread.currentThread.name».py''')
		pythonFile.deleteOnExit
		pythonFile.saveString(cmd)
		
		// python3 .\imandra-test.py
		val imandraCommand = #["python3", pythonFile.absolutePath]
		logger.info("Running Imandra: " + imandraCommand.join(" "))
		
		var Scanner resultReader = null
		var ScannerLogger errorReader = null
		var Process process = null
		try {
			process = Runtime.getRuntime().exec(imandraCommand)
			
			// Reading the result of the command
			resultReader = new Scanner(process.inputReader)
			errorReader = new ScannerLogger(
					new Scanner(process.errorReader),
					#["imandra_http_api_client.exceptions.ServiceException", "HTTP Error", "urllib.error.HTTPError", "ValueError"],
					true)
			errorReader.start
			
			while (resultReader.hasNextLine) {
				println(resultReader.nextLine)
			}
			
			logger.info("Quitting Imandra session")
		} finally {
			resultReader?.close
			errorReader?.cancel
			process?.destroyForcibly
		}
	}
	
	protected def extractTransFunction(String src) {
		val START_STRING = "let init ="
		
		val start = src.indexOf(START_STRING)
		val offset = START_STRING.length
		val end = src.indexOf("let env ")
		
		val newStart = '''let init2 ='''
		
		val newSrc = newStart + src.substring(start + offset, end)
				.replaceAll('''let «DIFF_FUNCTION_NAME» ''', '''let «NEW_DIFF_FUNCTION_NAME» ''')
		return newSrc
	}
	
}