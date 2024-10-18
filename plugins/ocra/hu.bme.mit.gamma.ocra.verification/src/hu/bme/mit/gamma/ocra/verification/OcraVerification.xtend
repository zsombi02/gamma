package hu.bme.mit.gamma.ocra.verification

import hu.bme.mit.gamma.verification.util.AbstractVerification
import hu.bme.mit.gamma.querygenerator.serializer.NuxmvPropertySerializer
import java.io.File
import java.util.concurrent.TimeUnit
import hu.bme.mit.gamma.verification.util.AbstractVerifier.Result
import hu.bme.mit.gamma.verification.result.ThreeStateBoolean
import java.io.BufferedReader
import java.io.FileReader
import java.io.IOException
import hu.bme.mit.gamma.trace.model.impl.ExecutionTraceImpl

class OcraVerification extends AbstractVerification {
		// Singleton
	public static final OcraVerification INSTANCE = new OcraVerification
	protected new() {}
	//
	
	override protected getTraceabilityFileName(String fileName) {
		return "ocra/" + fileName.getOcraFileName
	}
	
	override protected createVerifier() {
		return new OcraVerifier
	}
	
	override getDefaultArguments() {
		return #[OcraVerifier.SET_OCRA_TIMED]
	}
	
	override protected getArgumentPattern() {
		return ".*" // TODO
	}
	
	override protected createPropertySerializer() {
		return NuxmvPropertySerializer.INSTANCE
	}
	
	override Result execute(File modelFile, File queryFile, String[] arguments,
        long timeout, TimeUnit unit) throws InterruptedException {
        	
    	try {
        val reader = new BufferedReader(new FileReader(queryFile))
        var String line
        while ((line = reader.readLine) !== null) {
            println(line) // Print each line
        }
        reader.close
	    } catch (IOException e) {
	        e.printStackTrace
	    }
    	return new Result(ThreeStateBoolean.TRUE, execTrace)
	}
	
	def ExecutionTraceImpl getExecTrace() {
		return null as ExecutionTraceImpl
	}
	
}