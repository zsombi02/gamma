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
package hu.bme.mit.gamma.api.headless;

import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.eclipse.equinox.app.IApplication;
import org.eclipse.equinox.app.IApplicationContext;

// The application class that gets executed and exported as Headless Gamma
public class Application implements IApplication {
	//
	private GammaEntryPoint gammaEntryPoint;
	private ProjectImporter projectImporter;
	private WorkspaceGenerator workspaceGenerator;
	//
	protected Logger logger = Logger.getLogger("GammaLogger");
	
	@Override
	public Object start(final IApplicationContext context) throws Exception {
		final Map<?, ?> args = context.getArguments(); // ./eclipse.exe -data ./ws gamma info .../Genmodelfile.ggen
		final String[] appArgs = (String[]) args.get(IApplicationContext.APPLICATION_ARGS);
		
		Level level = Level.INFO;
		try {
			/*
			 * Checks the number of arguments, which decide the operation the Headless Gamma
			 * executes Note that these arguments are passed through the web server, not by
			 * the user, so this error should not appear, as the server always passes these arguments.
			 */
			if (appArgs.length == 0) {
				logger.warning("No argument given. Either a \"workspace\", \"import\" or \"gamma\" argument is expected.");
			}
			else {
				// The second argument is the log level. This is INFO by default. This can be
				// modified through the web server. Throws and exception if the setting is incorrect.
				if (appArgs.length > 1) {
					switch (appArgs[1]) {
						case "info":
							level = Level.INFO;
							break;
						case "warning":
							level = Level.WARNING;
							break;
						case "severe":
							level = Level.SEVERE;
							break;
						case "off":
							level = Level.OFF;
							break;
						default:
							logger.warning("Invalid argument for setting log level: " + appArgs[1]);
					}
				}
				// The first argument is the operation type: creating workspace, importing
				// project or executing Gamma .ggen file
				switch (appArgs[0]) {
					case "workspace":
						workspaceGenerator = new WorkspaceGenerator(context, appArgs, level);
						workspaceGenerator.execute();
						break;
					case "import":
						projectImporter = new ProjectImporter(context, appArgs, level);
						projectImporter.execute();
						break;
					case "gamma":
						gammaEntryPoint = new GammaEntryPoint(context, appArgs, level);
						gammaEntryPoint.execute();
						break;
					default:
						logger.warning("Invalid argument for operation type: " + appArgs[0] + ". Use \"workspace\", \"import\" or \"gamma\".");
				}
			}
		} catch (Throwable t) {
			logger.severe(t.getMessage());
			t.printStackTrace();
		}
		return IApplication.EXIT_OK;
	}

	@Override
	public void stop() {
		logger.info("Headless Gamma application stopped");
	}

}