# KIRO.md — Project Guide

## Overview

`react-native-apple-game-controller` is a React Native macOS TurboModule that exposes Apple's `GameController.framework` via JSI. It provides frame-rate polling for analog/button state plus optional event callbacks for button transitions.

The module uses the New Architecture (Fabric/TurboModules) with C++ codegen. No bridge, no Java, no iOS — macOS only.

## Directory Layout

```
react-native-apple-game-controller/
├── spec/NativeGameController.ts     # Codegen source of truth (TurboModule spec)
├── src/index.ts                     # Public API re-export
├── macos/
│   ├── RNGameController.h           # C++ class header (extends generated CxxSpec)
│   ├── RNGameController.mm          # Implementation (ObjC++ for GameController.framework access)
│   └── RNGameControllerLoader.mm    # +load registration with RN module map
├── example/                         # Consuming app for development/testing
│   ├── App.tsx                      # Example UI
│   ├── macos/                       # Xcode project, Podfile, native app shell
│   ├── metro.config.js              # Resolves parent library via watchFolders
│   └── package.json                 # file:.. dependency on the library
├── package.json                     # Library package (codegenConfig lives here)
├── react-native-apple-game-controller.podspec
├── react-native.config.js           # Autolinking config (macos: {})
├── tsconfig.json
├── GAME.md                          # Full implementation spec
├── NATIVE.md                        # Reference guide for RN macOS addon patterns
└── KIRO.md                          # This file
```

## Key Files

| File | Purpose |
|------|---------|
| `spec/NativeGameController.ts` | Defines all types and methods. Codegen generates `RNGameControllerSpecJSI.h` from this. |
| `macos/RNGameController.h` | C++ class extending `NativeGameControllerCxxSpec<RNGameController>`. Declares all methods. |
| `macos/RNGameController.mm` | Implementation. This is ObjC++ so it can import GameController.framework. |
| `macos/RNGameControllerLoader.mm` | Registers module via `registerCxxModuleToGlobalModuleMap` in `+load`. |
| `package.json` | `codegenConfig.name` = `RNGameControllerSpec`, `jsSrcsDir` = `spec` |

## Commands

### Library root (`/`)

```bash
# Type-check the spec and src
npx tsc --noEmit
```

### Example app (`/example`)

```bash
# Install dependencies (use --legacy-peer-deps if needed)
npm install

# Pod install (required after spec changes or new native deps)
cd macos && pod install && cd ..

# Build macOS app (compiles native + codegen)
npm run build:macos

# Run macOS app (builds + launches)
npm run run:macos

# Start Metro bundler separately (if needed)
npm start
```

## Development Workflow

1. Edit `spec/NativeGameController.ts` — this is the API contract
2. Update `macos/RNGameController.h` and `.mm` to match new/changed methods
3. Run `cd example/macos && pod install` — this regenerates `build/generated/ios/RNGameControllerSpecJSI.h`
4. Run `npm run build:macos` in `example/` — compiles everything
5. The generated header lands at `example/macos/build/generated/ios/RNGameControllerSpecJSI.h`

If you change the spec interface (add/remove methods, change types), you MUST update both the `.h` and `.mm` to match or the build will fail with pure virtual function errors.

## Codegen

The codegen config in `package.json`:

```json
"codegenConfig": {
  "name": "RNGameControllerSpec",
  "type": "modules",
  "jsSrcsDir": "spec"
}
```

This generates `RNGameControllerSpecJSI.h` containing:
- Struct templates for all interface types (bridging to/from JSI)
- `NativeGameControllerCxxSpecJSI` abstract base class
- `NativeGameControllerCxxSpec<T>` CRTP template your class extends
- `emitOn*` methods for EventEmitters

## Autolinking

`react-native.config.js` declares `macos: {}` which tells the RN CLI to autolink this pod on macOS. The podspec uses `install_modules_dependencies(s)` which handles all React Native codegen/build dependencies automatically.

## Notes

- `example/macos/.xcode.env.local` must point to your node binary (nvm path)
- The example uses `fabric_enabled => true` in the Podfile
- The AppDelegate uses `RCTAppDependencyProvider` for new architecture module discovery
- Metro config has `watchFolders: [libraryRoot]` so edits to `src/` and `spec/` hot-reload
