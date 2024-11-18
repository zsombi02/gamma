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

class ImlApiHelper {
	
	static def String getBasicCode(String modelString, String command, String commandlessQuery) '''
		import imandra
		
		with imandra.session() as session:
			session.eval("""«System.lineSeparator»«modelString»""")
			result = session.«command»("«commandlessQuery»")
			print(result)
	'''
	
	static def String getBasicCall(String src) '''
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
			«src»
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
	
}