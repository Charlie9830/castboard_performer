import sys
from generatePlayerUpdateFromYoctoArtifacts import generatePlayerUpdateFromYoctoArtifacts
import os

projectRootPath = sys.argv[1]
artifactFilePath = sys.argv[2]
rootFsPath= sys.argv[3] # Represents the path to castboard-player from the rpi rootfs root.
outputDirPath = sys.argv[4]

generatePlayerUpdateFromYoctoArtifacts(
os.path.abspath(projectRootPath),
os.path.abspath(artifactFilePath),
rootFsPath,
os.path.abspath(outputDirPath)
)

print('\n do_packageExistingYoctoBundleAsUpdate finished successfully. \n')
