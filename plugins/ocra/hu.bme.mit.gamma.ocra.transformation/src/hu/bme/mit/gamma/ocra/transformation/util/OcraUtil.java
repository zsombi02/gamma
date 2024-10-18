package hu.bme.mit.gamma.ocra.transformation.util;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class OcraUtil {
	
	// Singleton
	public static final OcraUtil INSTANCE = new OcraUtil();
	protected OcraUtil() {}
	
	public Map<String, String> parseContractsFromFile(String fileUrl) {
	    Map<String, String> componentContractsMap = new HashMap<>();

	    try {
	        // Read the file content
	        List<String> lines = Files.readAllLines(Paths.get(fileUrl));

	        String currentComponent = null;
	        StringBuilder contractBuilder = null;

	        // Patterns to match the start and end of a component's contract block
	        Pattern startPattern = Pattern.compile("START_CONTRACTS_FOR\\s+(.+)");
	        Pattern endPattern = Pattern.compile("END_CONTRACTS_FOR\\s+(.+)");

	        for (String line : lines) {
	            Matcher startMatcher = startPattern.matcher(line);
	            Matcher endMatcher = endPattern.matcher(line);

	            // Detect the start of a contract block for a component
	            if (startMatcher.find()) {
	                currentComponent = startMatcher.group(1);  // Get the component name
	                contractBuilder = new StringBuilder();     // Initialize contract builder
	            } 
	            // Detect the end of a contract block for a component
	            else if (endMatcher.find() && currentComponent != null) {
	                // Add the contract block to the map without the START/END lines
	                componentContractsMap.put(currentComponent, contractBuilder.toString().trim());
	                currentComponent = null;  // Reset after the end of a component block
	                contractBuilder = null;
	            } 
	            // Continue adding lines to the contract block
	            else if (contractBuilder != null) {
	                contractBuilder.append(line).append("\n");  // Append the contract lines
	            }
	        }
	    } catch (IOException e) {
	        e.printStackTrace();
	    }

	    return componentContractsMap;
	}

    public Map<String, Set<String>> extractInVars(String input) {
        Pattern pattern = Pattern.compile("(?s)COMPONENT\\s+(\\w+)\\s+INTERFACE\\s+(.*?)(?:REFINEMENT|COMPONENT|$)");
        Matcher matcher = pattern.matcher(input);

        Map<String, Set<String>> componentValues = new HashMap<>();

        while (matcher.find()) {
            String componentName = matcher.group(1);
            String componentContent = matcher.group(2);

            Pattern inputPortPattern = Pattern.compile("INPUT\\s+PORT\\s+(\\w+)\\s*:\\s*(\\w+);");
            Matcher inputPortMatcher = inputPortPattern.matcher(componentContent);

            Pattern parameterPattern = Pattern.compile("PARAMETER\\s+(\\w+)\\s*:\\s*(\\w+);");
            Matcher parameterMatcher = parameterPattern.matcher(componentContent);

            Set<String> values = new HashSet<>();

            while (inputPortMatcher.find()) {
                String portName = inputPortMatcher.group(1);
                String portType = inputPortMatcher.group(2);
                values.add(portName + " : " + portType);
            }

            while (parameterMatcher.find()) {
                String paramName = parameterMatcher.group(1);
                String paramType = parameterMatcher.group(2);
                System.out.print(": "+paramType+" :");
                if (paramType.equals("event")) {
					paramType = "boolean";
				}
                values.add(paramName + " : " + paramType);
            }

            componentValues.computeIfAbsent(componentName, k -> new HashSet<>()).addAll(values);
        }

        return componentValues;
    }

    public void copyContent(String basePath, Set<String> inVars, String componentName) {
        String tempFileName = componentName + "_TEMP.smv";
        String nonTempFileName = componentName + ".smv";
        java.nio.file.Path tempFilePath = Paths.get(basePath, tempFileName);
        java.nio.file.Path nonTempFilePath = Paths.get(basePath, nonTempFileName);

        try {
        	try {
	            List<String> tempContent = Files.readAllLines(tempFilePath);
	            List<String> nonTempContent = Files.readAllLines(nonTempFilePath);
	
	            int nonTempVarIndex = -1;
	            for (int i = 0; i < nonTempContent.size(); i++) {
	                if (nonTempContent.get(i).startsWith("MODULE " + componentName)) {
	                    nonTempVarIndex = i + 1;
	                }
	            }
	
	            StringBuilder copiedContentBuilder = new StringBuilder();
	            boolean foundVar = false;
	            for (String line : tempContent) {
	                if (foundVar) {
	                    copiedContentBuilder.append(line).append("\n");
	                } else if (line.startsWith("VAR")) {
	                    copiedContentBuilder.append(line).append("\n");
	                    foundVar = true;
	                }
	            }
	
	            String[] copiedContent = copiedContentBuilder.toString().split("\n");
	
	            for (String inVar : inVars) {
	                for (int i = 0; i < copiedContent.length; i++) {
	                    if (copiedContent[i].contains(inVar)) {
	                        copiedContent[i] = "";
	                        break;
	                    }
	                }
	            }
	
	            nonTempContent.subList(nonTempVarIndex, nonTempContent.size()).clear();
	            for (String content : copiedContent) {
	                nonTempContent.add(nonTempVarIndex++, content);
	            }
	
	            Files.write(nonTempFilePath, nonTempContent);
        	} catch (NoSuchFileException e) {
    			System.out.print("No Temp file found on path: " + tempFilePath.toString());
    		}
        } catch (IOException e) {
            e.printStackTrace();
        } 
    }

    public void deleteTempFiles(String folderPath) {
        File folder = new File(folderPath);
		if (folder.exists() && folder.isDirectory()) {
		    File[] files = folder.listFiles();
		    if (files != null) {
		        for (File file : files) {
		            if (file.isFile() && file.getName().contains("_TEMP")) {
		                file.delete();
		                System.out.println("Deleted file: " + file.getName());
		            }
		        }
		    }
		} else {
		    System.out.println("Folder does not exist or is not a directory: " + folderPath);
		}
    }
    
    public List<String> extractPortNames(String filePath) {
        List<String> portNames = new ArrayList<>();

        try {
            // Read file content
            List<String> lines = Files.readAllLines(Paths.get(filePath));

            // Define regex pattern for matching PORT names
            Pattern portPattern = Pattern.compile("(INPUT|OUTPUT)\\s+PORT\\s+(\\w+)");

            for (String line : lines) {
                Matcher matcher = portPattern.matcher(line);
                if (matcher.find()) {
                    // Add the PORT name to the list (group 2 matches the port name)
                    portNames.add(matcher.group(2));
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }

        return portNames;
    }
}
