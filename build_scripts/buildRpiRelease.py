import os
from helpers import runShellCommands

def buildRpiRelease():
    # Configuration
    elinuxBuildCmd = "flutter-elinux build elinux " \
    "--dart-define=ELINUX_IS_ELINUX=true " \
    "--dart-define=ELINUX_TMP_PATH=/tmp/ " \
    "--dart-define=ELINUX_HOME_PATH=/home/cage " \
    "--target-arch=arm64 " \
    "--target-sysroot=/opt/ubuntu18-arm64-sysroot " \
    "--system-include-directories=/usr/aarch64-linux-gnu/include/c++/9/aarch64-linux-gnu " \
    
    projectRootPath = os.path.abspath('././')
    absBundlePath = os.path.abspath('././build/elinux/arm64/release/bundle')
    outputDirPath = os.path.join(projectRootPath, 'build', 'elinux', 'rpi', 'release')

    # Prepare the project Directory.
    runShellCommands([
        'rm -rf ./elinux',
        'flutter-elinux clean',
        'flutter-elinux create --platforms elinux .',
        'flutter-elinux pub get',
    ], projectRootPath)

    # Build for Arm64 eLinux
    runShellCommands([
        elinuxBuildCmd,
    ], projectRootPath)

    # Rename the exectuable to match what the Yocto build does.
    runShellCommands([
        'mv '+'"'+absBundlePath+'"'+'/castboard_performer'+ ' ' +'"'+absBundlePath+'"'+'/performer'
    ], projectRootPath)
