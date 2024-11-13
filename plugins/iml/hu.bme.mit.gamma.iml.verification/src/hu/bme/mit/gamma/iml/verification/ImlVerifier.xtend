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

import hu.bme.mit.gamma.statechart.interface_.Package
import hu.bme.mit.gamma.util.FileUtil
import hu.bme.mit.gamma.util.ScannerLogger
import hu.bme.mit.gamma.verification.result.ThreeStateBoolean
import hu.bme.mit.gamma.verification.util.AbstractVerifier
import java.io.File
import java.util.Scanner

class ImlVerifier extends AbstractVerifier {
	public static final String IMANDRA_TEMPORARY_COMMAND_FOLDER = ".imandra"
	//
	protected final static extension FileUtil fileUtil = FileUtil.INSTANCE
	//
	
	override verifyQuery(Object traceability, String parameters, File modelFile, File queryFile) {
		val query = fileUtil.loadString(queryFile)
		var Result result = null
		
		for (singleQuery : query.splitLines) {
			var newResult = traceability.verifyQuery(parameters, modelFile, singleQuery)
			
			val oldTrace = result?.trace
			val newTrace = newResult?.trace
			if (oldTrace === null) {
				result = newResult
			}
			else if (newTrace !== null) {
				oldTrace.extend(newTrace)
				result = new Result(ThreeStateBoolean.UNDEF, oldTrace)
			}
		}
		
		return result
	}
	
	override verifyQuery(Object traceability, String parameters, File modelFile, String query) {
		val modelString = fileUtil.loadString(modelFile)
		
		val command = query.substring(0, query.indexOf("("))
		val commandelssQuery = query.substring(command.length)
		
		val arguments = parameters.parseArguments
		val argument = arguments.key
		val postArgument = arguments.value
		
		val parentFile = modelFile.parentFile + File.separator + IMANDRA_TEMPORARY_COMMAND_FOLDER
		val pythonFile = new File(parentFile, '''.imandra-commands-«Thread.currentThread.name».py''')
		pythonFile.deleteOnExit
		
		val serializedPython = modelString.getTracedCode(command, argument, postArgument, commandelssQuery)
		fileUtil.saveString(pythonFile, serializedPython)
		
		// python3 .\imandra-test.py
		val imandraCommand = #["python3", pythonFile.absolutePath]
		logger.info("Running Imandra: " + imandraCommand.join(" "))
		
		var Scanner resultReader = null
		var ScannerLogger errorReader = null
		var Result traceResult = null
		
		try {
			process = Runtime.getRuntime().exec(imandraCommand)
			
			// Reading the result of the command
			resultReader = new Scanner(process.inputReader)
			errorReader = new ScannerLogger(
					new Scanner(process.errorReader), "ValueError: ",  true)
			errorReader.start
			
			result = ThreeStateBoolean.UNDEF
			
			val gammaPackage = traceability as Package
			val backAnnotator = new TraceBackAnnotator(gammaPackage, resultReader)
			val trace = backAnnotator.synchronizeAndExecute
			
			if (!errorReader.error) {
				if (trace === null && command.contains("verify") || trace !== null && command.contains("instance")) {
					result = ThreeStateBoolean.TRUE
				}
				else if (trace !== null && command.contains("verify") || trace === null && command.contains("instance")) {
					result = ThreeStateBoolean.FALSE
				}
			}
			
			traceResult = new Result(result, trace)
			
			logger.info("Quitting Imandra session")
		} finally {
			resultReader?.close
			errorReader?.cancel
			cancel
		}
		
		return traceResult
	}
	
	protected def String getBasicCode(String modelString, String command, String commandlessQuery) '''
		import imandra
		
		with imandra.session() as session:
			session.eval("""«System.lineSeparator»«modelString»""")
			result = session.«command»("«commandlessQuery»")
			print(result)
	'''
	
	protected def String getTracedCode(String modelString, String command,
			String arguments, String postArguments, String commandlessQuery) '''
		import imandra.auth
		import imandra.instance
		import imandra_http_api_client
		
		# Starting an Imandra instance
		
		auth = imandra.auth.Auth()
		instance = imandra.instance.create(auth, None, "imandra-http-api")
		
		config = imandra_http_api_client.Configuration(
		    host = instance['new_pod']['url'],
		    access_token = instance['new_pod']['exchange_token'],
		)
		
		# Doing the low-level call to the API
		
		src = """
			«modelString»;;
			«commandlessQuery.utilityMethods»;;
			«command»«IF !arguments.nullOrEmpty» «arguments» «ENDIF»(«commandlessQuery»)«postArguments»;; (* The trace is automatically printed *)
			#trace trans;;
			init;;
			let path = collect_path «FOR inputsOfLevels : commandlessQuery.parseInputsOfLevels.values»«FOR inputOfLevels : inputsOfLevels»CX.«inputOfLevels» «ENDFOR»«ENDFOR» in
			run init path;;
		"""
		
		with imandra_http_api_client.ApiClient(config) as api_client:
		    api_instance = imandra_http_api_client.DefaultApi(api_client)
		    req = {
		        "src": src,
		        "syntax": "iml",
		        "hints": {
		            "method": {
		                "type": "auto"
		            }
		        }
		    }
		    request_src = imandra_http_api_client.EvalRequestSrc.from_dict(req)
		    try:
		        api_response = api_instance.eval_with_http_info(request_src)
		    except ApiException as e:
		        print("Exception when calling DefaultApi->eval_with_http_info: %s\n" % e)
		
		# json parse the raw_data yourself and take the raw_stdio
		
		import json
		raw_response = json.loads(api_response.raw_data)
		print(raw_response.get("raw_stdio"))
		
		# Delete the Imandra instance
		
		imandra.instance.delete(auth, instance['new_pod']['id'])
	'''
	
	protected def getUtilityMethods(String query) { // TODO move to Prop-ser
		val builder = new StringBuilder
		if (query.contains("exists_prefix ")) {
			builder.append('''
				let rec exists_prefix r e p =
					match e with
					| [] -> false (* No p r check *)
					| [_] -> p r (* 1 last element will be unchecked *)
					| hd :: tl -> p r || (* At least two elements (note the ||) *)
						let r = run_cycle r hd in (* Run r based on the head *)
						exists_prefix r tl p (* Check the tail *)
				[@@adm e] (* Needed by Imandra to prove termination *)
				
			''')
		}
		if (query.contains("forall_prefix ")) {
			builder.append('''
				let rec forall_prefix r e p =
					match e with
					| [] -> true (* No p r check *)
					| [_] -> p r (* 1 last element will be unchecked *)
					| hd :: tl -> p r && (* At least two elements (note the &&) *)
						let r = run_cycle r hd in (* Run r based on the head *)
						forall_prefix r tl p (* Check the tail *)
				[@@adm e] (* Needed by Imandra to prove termination *)
				
			''')
		}
		if (query.contains("is_one_prefix_of_other ")) {
			builder.append('''
				let rec is_one_prefix_of_other l r =
					if l = [] || r = []
					then true
					else
						List.hd l = List.hd r && is_one_prefix_of_other (List.tl l) (List.tl r)
				
			''')
		}
		
		builder.append('''
			let rec select_longest list_of_lists =
				match list_of_lists with
					| [] -> []
					| hd::tl ->
						let so_far_longest = select_longest tl in
						if List.length hd >= List.length so_far_longest then
							hd
						else
							so_far_longest
			
		''')
		
		var count = 0
		builder.append('''
			let collect_path «query.parseInputs» =
				let path_«count++» = [] in
				«FOR inputsOfLevel : query.parseInputsOfLevels.values»
					let path_«count++» = path_«count - 2» @ select_longest [«
						FOR inputOfLevel : inputsOfLevel SEPARATOR ';'»«IF inputOfLevel.contains("_NEXT") /* TODO based on ImlPropertySerializer.getInputId */»[«inputOfLevel»]«ELSE»«inputOfLevel»«ENDIF»«ENDFOR»] in
				«ENDFOR»
				path_«count - 1»
			
		''')
		
		return builder.toString
	}
	
	protected def parseArguments(String arguments) {
		val argument = new StringBuilder
		val postArgument = new StringBuilder
		
		val splits = arguments.split("\\s") // Split based on any whitespace
		for (split : splits) {
			if (split.startsWith("[") && split.endsWith("]")) { // [@@auto]
				postArgument.append(split + " ")
			}
			else {
				argument.append(split + " ")
			}
		}
		
		return argument.toString.trim -> postArgument.toString.trim
	}
	
	protected def parseInputs(String query) {
		val funKeyword = "fun"
		val funIndex = query.indexOf(funKeyword)
		val lastIndex = query.indexOf("->")
		val input = query.substring(funIndex + funKeyword.length, lastIndex).trim
		return input
	}
	
	protected def parseInputsOfLevels(String query) {
		val input = query.parseInputs
		val inputs = input.split("\\s")
		// Sorted map needed!
		val inputsOfLevels = inputs.groupBy[Integer.valueOf(it.split("\\_").get(1))] // TODO based on ImlPropertySerializer.getInputId
		return inputsOfLevels
	}
	
	//
	
	override getTemporaryQueryFilename(File modelFile) {
		return "." + modelFile.extensionlessName + ".i"
	}
	
	override getHelpCommand() {
		return #["python3", "-h"]
//		return #["imandra-cli", "-h"]
	}
	
	override getUnavailableBackendMessage() {
		return "The command line tool of Imandra ('Imandra') cannot be found. " +
				"Imandra can be downloaded from 'https://www.imandra.ai/'. "
	}
	
}