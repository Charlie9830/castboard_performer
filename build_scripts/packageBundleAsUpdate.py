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

def packageBundleAsUpdate(projectRootPath, bundlePath, outputDirPath, versionCodename):
    # Remove any remnant .zip files from the bundle.
    runShellCommands([
        'rm -f *.zip',
    ], bundlePath)

    # Zip the contents of bundle.
    print('Archiving bundle contents..')
    runShellCommands([
        'zip -r ' +versionCodename+'.zip ./*',
    ], bundlePath)

    # Make an output Directory.
    runShellCommands([
        'mkdir -p '+'"'+outputDirPath+'"'
    ], projectRootPath)

    # Delete any existing matching artifact in the output directory.
    print('Deleting matching artifacts from output directory')
    runShellCommands([
        'rm -f '+'"'+os.path.join(outputDirPath, versionCodename)+'.zip'+'"'
    ], projectRootPath)


    # Move the archived bundle to that directory.
    print('Moving zipped file to output directory.')
    runShellCommands([
        'mv ' + '"'+os.path.join(bundlePath, versionCodename+'.zip')+'"'+ ' ' +'"'+outputDirPath+'"'
    ], projectRootPath)

    print('Update file output to '+outputDirPath+'/'+versionCodename)

