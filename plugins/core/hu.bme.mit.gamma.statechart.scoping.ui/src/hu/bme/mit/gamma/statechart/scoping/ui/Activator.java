/********************************************************************************
 * Copyright (c) 2018 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.statechart.scoping.ui;

import org.eclipse.ui.plugin.AbstractUIPlugin;
import org.eclipse.xtext.ui.shared.SharedStateModule;
import org.osgi.framework.BundleContext;

import com.google.inject.Guice;
import com.google.inject.Injector;
import com.google.inject.util.Modules;

import hu.bme.mit.gamma.statechart.scoping.GammaRuntimeModule;

/**
 * The activator class controls the plug-in life cycle
 */
public class Activator extends AbstractUIPlugin {

	// The plug-in ID
	public static final String PLUGIN_ID = "hu.bme.mit.gamma.statechart.scoping.ui"; //$NON-NLS-1$

	// The shared instance
	private static Activator plugin;
	
	private Injector injector;
	
	/**
	 * The constructor
	 */
	public Activator() {
	}
	
	public Injector getInjector() {
        return injector;
    }
 
    private void initializeEcoreInjector() {
        injector = Guice.createInjector(
                Modules.override(Modules.override(new GammaRuntimeModule())
                .with(new GammaUiModule(plugin)))
                .with(new SharedStateModule()));
    }

	/*
	 * (non-Javadoc)
	 * @see org.eclipse.ui.plugin.AbstractUIPlugin#start(org.osgi.framework.BundleContext)
	 */
	public void start(BundleContext context) throws Exception {
		super.start(context);
        plugin = this;
        try {
            initializeEcoreInjector();
        } catch(Exception e) {
            throw e;
        }
	}

	/*
	 * (non-Javadoc)
	 * @see org.eclipse.ui.plugin.AbstractUIPlugin#stop(org.osgi.framework.BundleContext)
	 */
	public void stop(BundleContext context) throws Exception {
		plugin = null;
        injector = null;
        super.stop(context);
	}

	/**
	 * Returns the shared instance
	 *
	 * @return the shared instance
	 */
	public static Activator getDefault() {
		return plugin;
	}

}