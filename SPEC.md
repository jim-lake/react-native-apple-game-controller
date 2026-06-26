# react-native-apple-game-controller Specification

## Overview

`react-native-apple-game-controller` is a React Native macOS native module that exposes Apple Game Controller input using `GameController.framework` and a JSI-based high-performance polling model.

The module is designed for low-latency input handling with:

* Frame-synced polling for analog state
* Bitfield-based button state
* Self-describing controller profiles (buttons, axes, dpads with bit/index mappings)
* Optional event callbacks for discrete button transitions
* Multiple controller support

It intentionally avoids high-frequency JS event spam and avoids any global input interception.

---

# Architecture

## Objective-C++ Layer (.mm)

The `.mm` layer owns all interaction with Apple APIs:

* `GameController.framework`
* `GCController` lifecycle management
* `valueChangedHandler` callbacks
* Controller discovery notifications (`GCControllerDidConnectNotification` / `GCControllerDidDisconnectNotification`)
* JSI function installation

Allowed imports:

```objc
#import <GameController/GameController.h>
```

This layer is the ONLY place Apple GameController types may appear.

---

## C++ Layer (.cpp)

The C++ layer owns:

* Controller state storage
* Atomic synchronization
* Button bitfield logic
* Snapshot serialization
* JSI host objects / functions

The C++ layer MUST NOT import:

* GameController.framework
* Foundation
* AppKit
* Objective-C types

---

# Controller Model

Each controller is assigned a session-stable integer ID:

```ts
type ControllerId = number;
```

IDs remain valid until disconnect. There is no persistent cross-session identifier available from the Game Controller framework — Apple does not expose hardware serial numbers or UUIDs for controllers.

---

# Controller Info

Retrieved via `getControllers(): Promise<ControllerInfo[]>`. This is an infrequent call (on connect, on demand) that returns the full self-describing profile for each controller.

```ts
export interface ControllerInfo {
  controllerId: number;
  vendorName: string | null;
  productCategory: string | null;   // e.g. "DualSense Wireless Controller"
  playerIndex: number;               // -1 if unset (GCControllerPlayerIndexUnset)
  batteryLevel: number | null;       // 0.0–1.0, null if not reported
  batteryState: string | null;       // "charging" | "discharging" | "full" | null
  lightColor: LightColor | null;     // current color, null if no light
  isAttached: boolean;               // wired vs wireless
  buttons: ButtonInfo[];
  axes: AxisInfo[];
  dpads: DpadInfo[];
}
```

### ButtonInfo

Each button reports its position in the bitfield:

```ts
export interface ButtonInfo {
  name: string;              // canonical name e.g. "Button A"
  sfSymbol: string | null;   // SF Symbol name for rendering prompts
  localizedName: string | null; // user-facing name (after remapping)
  bit: number;               // bit position in ControllerState.buttons
}
```

### AxisInfo

Each axis reports which indices it occupies in the analog array:

```ts
export interface AxisInfo {
  name: string;
  sfSymbol: string | null;
  localizedName: string | null;
  analogIndex: number[];     // indices into ControllerState.analog
}
```

A single-axis element (e.g. trigger) has one index: `[4]`.
A two-axis element (e.g. thumbstick) has two indices: `[0, 1]` for X, Y.

### DpadInfo

Dpads are a convenience grouping of four directional bits in the button bitfield:

```ts
export interface DpadInfo {
  name: string;
  up: number;      // bit position in buttons
  down: number;
  left: number;
  right: number;
}
```

If a dpad also reports analog values, those appear separately in the `axes` array. The `DpadInfo` only describes the digital (pressed/not-pressed) aspect.

---

# Controller State

Retrieved via `getControllerState(controllerId: number): ControllerState`. This is the hot-path polling API, called every frame.

```ts
export interface ControllerState {
  analog: number[];   // float values, layout described by AxisInfo.analogIndex
  buttons: number;    // uint32 bitfield, layout described by ButtonInfo.bit
}
```

## Analog Values

* Sticks: -1.0 → 1.0
* Triggers: 0.0 → 1.0
* Array length is dynamic per controller (determined by axes present)

## Button Bitfield

A 32-bit unsigned integer. Bit assignments are NOT hardcoded — they are discovered from `ControllerInfo.buttons[].bit` and `ControllerInfo.dpads[].{up,down,left,right}`.

The native layer assigns bit positions based on the physical input profile. Standard extended gamepad controllers will use a conventional layout:

```text
bit 0  = A
bit 1  = B
bit 2  = X
bit 3  = Y
bit 4  = leftShoulder
bit 5  = rightShoulder
bit 6  = leftStickButton
bit 7  = rightStickButton
bit 8  = options (start)
bit 9  = menu (select)
bit 10 = home
bit 11 = dpad up
bit 12 = dpad down
bit 13 = dpad left
bit 14 = dpad right
```

Non-standard buttons (paddles, extra buttons) get assigned to higher bits. The JS consumer MUST use the `bit` field from `ButtonInfo` rather than hardcoding positions.

---

# Event System

## Direct Callback (Fast Path)

```ts
registerEventCallback(callback: GamepadEventCallback | null): void;
```

Stores a raw `jsi::Function` and invokes it via `jsInvoker_->invokeAsync()` on button state transitions. This is the lowest-latency path for button events.

```ts
export interface ButtonEvent {
  controllerId: number;
  buttons: number;         // full bitfield snapshot at time of transition
}
```

The callback receives the entire bitfield. JS diffs against previous to determine which buttons changed (XOR). This avoids per-button event overhead.

Passing `null` unregisters the callback.

## EventEmitter (Slow Path)

```ts
readonly onGamepadButton: EventEmitter<ButtonEvent>;
```

Same payload as the direct callback, but delivered through the standard RN EventEmitter system. Only fires when `toggleButtonEvents(true)` has been called. Disabled by default because EventEmitter has higher overhead.

```ts
toggleButtonEvents(enabled: boolean): void;
```

This gate ONLY controls the EventEmitter path. The direct callback (if registered) always fires regardless of this toggle.

## Connection Events

```ts
readonly onConnected: EventEmitter<number>;     // controllerId
readonly onDisconnected: EventEmitter<number>;  // controllerId
```

Always active. These are infrequent events — EventEmitter overhead is acceptable.

---

# Actions

## setLightColor

```ts
setLightColor(controllerId: number, r: number, g: number, b: number): Promise<void>;
```

Sets the controller's light bar color (DualSense, etc). Values are 0.0–1.0 per channel. Rejects if the controller has no light (`controller.light == nil`).

## setPlayerIndex

```ts
setPlayerIndex(controllerId: number, index: number): Promise<void>;
```

Sets the player index (0–3). Pass -1 to unset (`GCControllerPlayerIndexUnset`).

---

# Polling Model

The app may ignore events entirely and rely purely on polling.

Typical usage:

```ts
const controllers = await GameController.getControllers();
const c = controllers[0];

// discover layout once
const leftStick = c.axes.find(a => a.name === 'Left Thumbstick');
const aButton = c.buttons.find(b => b.name === 'Button A');

// poll every frame
requestAnimationFrame(function loop() {
  const state = GameController.getControllerState(c.controllerId);

  if (leftStick) {
    const lx = state.analog[leftStick.analogIndex[0]];
    const ly = state.analog[leftStick.analogIndex[1]];
  }

  if (aButton) {
    const aPressed = (state.buttons & (1 << aButton.bit)) !== 0;
  }

  requestAnimationFrame(loop);
});
```

---

# Threading Model

## Main Thread

Owns:

* GCController lifecycle
* valueChangedHandler
* Button diff + event generation
* State mutation (writes to atomics)

---

## JavaScript Thread

Owns:

* Polling via JSI (`getControllerState`)
* Direct callback invocation (via `jsInvoker_->invokeAsync`)
* EventEmitter delivery

---

## Synchronization

All shared state is lock-free using:

* `std::atomic<float>` for analog values
* `std::atomic<uint32_t>` for button bitfield

No mutexes. No locks. No condition variables.

---

# Performance Requirements

## Must achieve

* No JS allocations per frame in polling path
* No ObjC calls during `getControllerState`
* O(1) snapshot read per controller
* Stable 60–240Hz polling support

---

# Design Constraints

## Required

* Multiple controllers supported
* Session-stable controller IDs
* Self-describing profiles (no hardcoded bit layouts in JS)
* Frame-based polling for analog input
* Optional event system for buttons (two tiers: fast callback, slow EventEmitter)
* No analog event spam
* No GC pressure from polling API

---

## Not Supported

* Motion sensors (accelerometer/gyro)
* Force feedback / haptics
* Controller emulation
* Global input interception
* Background input capture
* Persistent cross-session controller identification

---

# Implementation Notes

## Bit Assignment Strategy

On controller connect, iterate `physicalInputProfile.allButtons` and assign bit positions. Use the standard layout (A=0, B=1, ...) for `GCExtendedGamepad` elements. Assign remaining non-standard buttons to bits 15+.

## Analog Array Layout

On controller connect, iterate axes and assign sequential indices into the analog array. A thumbstick contributes 2 indices (X, Y). A trigger contributes 1 index. Record the mapping in `AxisInfo.analogIndex`.

## Battery State Mapping

Map `GCDeviceBattery.batteryState`:
* `GCDeviceBatteryStateDischarging` → `"discharging"`
* `GCDeviceBatteryStateCharging` → `"charging"`
* `GCDeviceBatteryStateFull` → `"full"`
* No battery object → `null` for both `batteryLevel` and `batteryState`

## Light Color

Read from `controller.light.color` as NSColor, convert to 0.0–1.0 RGB. Controllers without `controller.light` report `null`.

## Dpad Analog vs Digital

A `GCControllerDirectionPad` exposes both analog axes (xAxis/yAxis) and digital buttons (up/down/left/right). The digital aspect maps to `DpadInfo` bit positions. If the dpad reports meaningful analog values, its axes also appear in the `axes` array with their own `AxisInfo`. This means a dpad may be represented in both `dpads` and `axes` simultaneously.

## Event Callback Thread Safety

The stored `jsi::Function` from `registerEventCallback` must only be invoked on the JS thread via `jsInvoker_->invokeAsync()`. The main thread computes the diff and dispatches to JS thread for invocation.

## Module Lifecycle

Use the singleton helper pattern from NATIVE.md for bridging the C++ instance to the main thread. Clear the pointer in the destructor to handle JS reloads (Cmd+R) safely.
