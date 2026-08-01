# Building and installing

## Required toolchain

The native iOS application is built with:

- a Mac running a version of macOS supported by the selected Xcode release;
- Xcode and the matching iOS/iPadOS SDK;
- an Apple Account added to Xcode;
- Go and `gomobile` for the embedded Syncthing XCFramework; and
- a physical iPhone or iPad for folder-access and networking tests.

Windows or Linux can be used for Git, documentation, UI planning, and most Go
unit tests. Android Studio may be used as a text editor, but it cannot replace
Xcode's iOS SDK, code signing, Simulator, provisioning, or device debugger.

## Development installation on an iPad

Once the Xcode project exists:

1. Clone the repository onto the Mac.
2. Install the pinned Go toolchain and mobile build dependencies.
3. Run the repository's core build command to generate the XCFramework.
4. Open the Xcode project or workspace.
5. In Xcode Settings, add the Apple Account used for development.
6. Select the application target, open **Signing & Capabilities**, enable
   automatic signing, and choose the corresponding team.
7. Connect the iPad to the Mac, accept the trust prompt, and enable Developer
   Mode when iPadOS requests it.
8. Select the iPad as the run destination and press **Run**.

Xcode registers the device, creates a development provisioning profile, signs
the app, installs it, launches it, and attaches the debugger.

No jailbreak, custom tablet sandbox, or Android-style APK sideloading is used.
The application's normal folder picker requests permission for the Obsidian
vault after the signed app is running.

## Apple Account choices

### Personal Team

A normal Apple Account is enough for early physical-device development. Apple
currently limits Personal Team provisioning and makes the installed profile
expire after seven days, so the app must periodically be rebuilt and reinstalled
from Xcode.

### Apple Developer Program

Program membership is the practical choice for stable device provisioning,
TestFlight, or App Store distribution. It is not required for the first spike.

## Build pipeline target

The completed pipeline will have four independently visible stages:

```text
Go checks -> XCFramework build -> Xcode build/tests -> physical-device tests
```

Every executed build is recorded in `BUILD_LOG.md`. Tests and their exact scope
are recorded in `TEST_LOG.md`; a simulator pass is never reported as a physical
device pass.

