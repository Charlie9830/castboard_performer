from helpers import runShellCommands
import os

##
## Packages the contents of the bundle into a zip. Providing a codename file along with it.
##
## Generated output zip structure:
## /lib/
## /data/
## /player
## /codename

def packageBundleAsUpdate(projectRootPath, absBundlePath, outputDirPath, versionCodename):
    # Remove any remnant .zip files from the bundle.
    runShellCommands([
        'rm -f *.zip',
    ], absBundlePath)

    # Zip the contents of bundle.
    runShellCommands([
        'zip -r ' +versionCodename+'.zip ./*',
    ], absBundlePath)

    # Make an output Directory.
    runShellCommands([
        'mkdir -p '+'"'+outputDirPath+'"'
    ], projectRootPath)

    # Delete any existing matching artifact in the output directory.
    print('Deleting matching artifacts from output directory')
    runShellCommands([
        'rm '+'"'+os.path.join(absBundlePath, versionCodename)+'.zip'+'"'
    ])

    # Move the archived bundle to that directory.
    runShellCommands([
        'mv ' + '"'+os.path.join(absBundlePath, versionCodename+'.zip')+'"'+ ' ' +'"'+outputDirPath+'"'
    ], projectRootPath)

    print('Update file output to '+outputDirPath+'/'+versionCodename)

