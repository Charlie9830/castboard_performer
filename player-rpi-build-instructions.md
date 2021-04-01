# Building the Player for RPI 4 (RPI Running Ubuntu Server 20.04)

## Device Setup
### X64 Engine Builder
- Install Ubuntu Server 20.04
- Ensure you have at least 100gb of space available or can run the build process from an external storage device such as a USB Stick
- Remember Ubuntu Server doesn't come with wpa-supplicant installed, you will need a wired internet connection to get WIFI working.

### RPI4 
- Install Ubuntu Server 20.04 https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04.2&architecture=server-arm64+raspi
- Once installed edit the contents of /boot/firmnware/usercfg.txt and add the following line 
```dtoverlay=vc4-fkms-v3d```

Here you can also edit the HDMI Output parameters for the RPI.

- Reboot the RPI. After reboot you should now have entries in to /dev/dri/ directory like card0 and card1, we will reference these later when running the Flutter App with DRM Backend.


## Building
Follow the Instructions at
https://github.com/sony/flutter-embedded-linux as of 1/04/2021 commit tag ```62107d5```
Targeting Arm64 Wayland DRM Backend

## Steps performed on an X64 Device running Ubuntu Server 20.04
1. Install Libraries (Both Mandatory and DRM Backend)
    - Instructions Available at https://github.com/sony/flutter-embedded-linux/blob/master/BUILDING-ENGINE-EMBEDDER.md as of 1/04/2021 commit tag ```ab541d0```
    - You will also need to install ```ninja-build```. It is not currently listed as a dependency in the instructions.
    - You have to build this yourself as there is currently no cloud built binaries available for Arm64
    - Follow the above instructions targeting ARM64 Release (Debug may work as well, but technically Release will build a 'simpler' binary, so if debug is not requried don't do it)
    - depot_tools can take up to 100gb of space. Best to build it on an external USB Device with sufficent space.
    - When Creating the .gclient file in the same directory as depot_tools, NOT inside the depot_tools directory itself.
    - When running ```gclient sync``` run it from the parent directory of depot_tools (where your .gclient file is)
    - In the .gclient file, target the flutter engine version detailed in this repository in the engine.version file.
    - ```gclient sync``` can take a surprisingly long amount of time, even after it says Sync 100%, WAIT until it exits.
    - If ```gclient sync``` fails delete depot_tools and src. Restart again from from cloning depot_tools step.
    - Don't run ```gclient sync``` with the ```--no-history``` flag.
    - The final instruction will instruct you to install the outputted ```libflutter_engine.so``` into the cmake build dir. We however will copy it to a USB to then move over onto the RPI4.

## Steps performed on an RPI4 Device running Ubuntu Server 20.04
2. The Instructions here list these as examples, except you do need them as part of the build so don't skip this step.
    - Clone the flutter-embedded-linux repo onto the RPI then follow the instructions for building the DRM Backend.
    - Make sure you copy the libflutter_engine.so you created in step 1 to both the /flutter-embedded-linux/build dir as well as /usr/lib

3. Build as instructions say.

4. Follow the instructions to clone the flutter repo onto your device. Before running any flutter commands, navigate into the flutter directory and run ```git checkout <FRAMEWORK COMMIT DETAILS IN ENGINE.VERSION>``` to checkout the exact version of Framework that matches the engine you built the embedder for.
- Clone in the castboard_player repo and run ```flutter build linux```
- Even though you copied libflutter_engine.so to the build directory. You will still need to ensure you have copied it to /usr/lib
- Navigate to the flutter-embedded-linux/build dir and run ```sudo FLUTTER_DRM_DEVICE="/dev/dri/card0" ./flutter-drm-backend <PATH_TO_CASTBOARD_PLAYER_DIR>/build/linux/arm64/release/bundle```


## Notes
- DRM Backend for Wayland does not require a Weston Compositor or Desktop. Best choice for Embedded Software that needs Direct fullscreen access.