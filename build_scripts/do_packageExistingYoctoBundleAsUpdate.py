import sys
from generatePlayerUpdateFromYoctoArtifacts import generatePlayerUpdateFromYoctoArtifacts
import os

projectRootPath = sys.argv[1]
artifactFilePath = sys.argv[2]
outputDirPath = sys.argv[3]

generatePlayerUpdateFromYoctoArtifacts(os.path.abspath(projectRootPath), os.path.abspath(artifactFilePath), os.path.abspath(outputDirPath))
