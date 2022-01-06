import re
import subprocess
import time
import os
import sys

# Extracts a propertyValue from a dart file. 
def getPropertyValue(filePath, propertyName):
    file = open(filePath, 'r')
    lines = file.readlines()
    pattern = r"(?<="+propertyName+" = [\"|'])[a-zA-Z]+"

    for line in lines:
        match = re.search(pattern, line)
        if match is not None:
            return match.group()

# Runs shell commands
def runShellCommands(commands, cwd):
    for command in commands:
        try:
            subprocess.check_output(command, shell=True, cwd=cwd)
        except subprocess.CalledProcessError as err:
            print('\n ***** Shell Command Failed *****')
            print('***** Error output is likely above ***** \n')
            sys.exit(err)
            
        time.sleep(2)

# Writes the provided versioncode to a codename file in bundle path.
def stampCodename(bundlePath, versionCodename):
    # Write the kVersionCodename into the codename file in the bundle.
    with open(os.path.join(bundlePath, 'codename'), 'w+') as f:
        f.write(versionCodename)

# Extracts the value of kVersionCodename from the /lib/versionCodename.dart file.
def extractCodename(projectRootPath):
    # Extract the kVersionCodename literal value.
    return getPropertyValue(os.path.join(projectRootPath, '/lib/versionCodename.dart'), 'kVersionCodename')

# Reads the codename value from a stamped codename file.
def readCodenameFile(codenameFilePath):
    with open(codenameFilePath, 'r') as file:
        return file.read().replace('\n', '')