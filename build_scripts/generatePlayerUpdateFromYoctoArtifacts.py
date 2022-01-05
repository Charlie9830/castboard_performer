import os
from packageBundleAsUpdate import packageBundleAsUpdate
from helpers import runShellCommands, readCodenameFile

def generatePlayerUpdateFromYoctoArtifacts(projectRootPath, artifactFilePath, outputDirPath):
    tarUnpackDir = "/tmp/castboard_build_scripts/yocto_build_artifacts"
    
    print('Deleting existing work directory at '+tarUnpackDir)
    runShellCommands([
        'rm -rf '+'"'+tarUnpackDir+'"'
    ], projectRootPath)

    print('Creating work directory at '+tarUnpackDir)
    runShellCommands([
        'mkdir -p '+'"'+tarUnpackDir+'"'
    ], projectRootPath)

    print('Unpacking Tar Archive from \n'+artifactFilePath+' \n to \n'+tarUnpackDir)

    runShellCommands([
        'tar -xf '+'"'+artifactFilePath+'"'+' -C '+'"'+tarUnpackDir+'"',
    ], cwd=projectRootPath)


    bundlePath = os.path.join(tarUnpackDir, 'usr', 'share', 'castboard-player')

    print('Reading Version Codename value from extracted bundle')
    versionCodename = readCodenameFile(os.path.join(bundlePath, 'codename'))

    print('Packaging bundle as Update file.')
    print('Bundle Path:  '+'"'+bundlePath+'"')
    print('Output Directory:  '+'"'+outputDirPath+'"')

    packageBundleAsUpdate(projectRootPath, bundlePath, outputDirPath, versionCodename)

    