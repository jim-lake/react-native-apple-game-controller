# react-native-apple-game-controller Specification

## Overview

`react-native-apple-game-controller` is a React Native macOS native module that exposes Apple Game Controller input using `GameController.framework` and a JSI-based high-performance polling model.

The module is designed for low-latency input handling with:

* Frame-synced polling for analog state (including zero-copy shared buffer mode)
* Bitfield-based button state
* Self-describing controller profiles (buttons, axes, dpads with bit/index mappings)
* Optional event callbacks for discrete button transitions
* Multiple controller support
* Keyboard and mouse input capture

It intentionally avoids high-frequency JS event spam and avoids any global input interception (unless explicitly opted in via `shouldMonitorBackgroundEvents`).

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
* Shared buffer management
* JSI host objects / functions

The C++ layer MUST NOT import:

* GameController.framework
* Foundation
* AppKit
* Objective-C types

---

# Controller Model

Each controller is assigned a session-stable UUID string (generated via `NSUUID`):

```ts
type ControllerId = string; // UUID e.g. "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
```

The native layer maintains a bidirectional mapping:
* `Map<string, GCController*>` — UUID → controller (for API calls by ID)
* `Map<GCController*, string>` — controller → UUID (for event dispatch from native callbacks)

UUIDs are generated on connect and both map entries are removed on disconnect.

There is no persistent cross-session identifier available from the Game Controller framework — Apple does not expose hardware serial numbers or UUIDs for controllers. The UUIDs are module-generated and ephemeral.

---

# Controller Info

Retrieved via `getControllers(): Promise<ControllerInfo[]>`. This is an infrequent call (on connect, on demand) that returns the full self-describing profile for each controller.

```ts
export interface LightColor {
  r: number;
  g: number;
  b: number;
}

export interface ControllerInfo {
  controllerId: string;
  isCurrent: boolean;                // whether this is the current/active controller
  vendorName: string | null;
  productCategory: string | null;    // e.g. "DualSense Wireless Controller"
  playerIndex: number;               // -1 if unset (GCControllerPlayerIndexUnset)
  batteryLevel: number | null;       // 0.0–1.0, null if not reported
  batteryState: string | null;       // "charging" | "discharging" | "full" | null
  lightColor: LightColor | null;     // current color, null if no light
  isAttached: boolean;               // wired vs wireless
  buttons: ControllerButtonInfo[];
  axes: AxisInfo[];
  dpads: DpadInfo[];
}
```

### ControllerButtonInfo

Each button reports its position in the bitfield:

```ts
export interface ControllerButtonInfo {
  name: string;              // canonical name e.g. "Button A"
  sfSymbol: string | null;   // SF Symbol name for rendering prompts
  localizedName: string | null; // user-facing name (after remapping)
  bit: number;               // bit position in ControllerState.buttons
}
```

### AxisInfo

Each axis reports how many analog values it contributes:

```ts
export interface AxisInfo {
  name: string;
  sfSymbol: string | null;
  localizedName: string | null;
  analogCount: number;       // number of analog values (1 for trigger, 2 for thumbstick)
}
```

A single-axis element (e.g. trigger) has `analogCount: 1`.
A two-axis element (e.g. thumbstick) has `analogCount: 2` (X, Y).

Analog indices are assigned sequentially based on axis order — the consumer walks the `axes` array and accumulates `analogCount` values to determine each axis's position in the analog array.

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

## Standard Polling

Retrieved via `getControllerState(controllerId: string): ControllerState`. This is the hot-path polling API, called every frame.

```ts
export interface ControllerState {
  analog: Float[];    // float values, layout described by AxisInfo
  buttons: Int32;     // uint32 bitfield, layout described by ControllerButtonInfo.bit
  lastUpdated: Double; // timestamp of last native state change
}
```

## Shared Buffer Polling (Zero-Copy)

For maximum performance, the module supports shared ArrayBuffer-based polling that avoids all JS allocations:

```ts
export interface ControllerSharedBuffers {
  controllerId: string;
  analog: Float32Array;      // shared buffer for analog values
  buttons: Uint32Array;      // shared buffer for button bitfield
  lastUpdated: Float64Array; // timestamp of last native state change
}
```

Start shared buffer capture with `startControllerCapture()` (public API wraps `_startControllerCapture()`). The native module writes directly into these buffers; JS reads them each frame with zero allocation.

Stop capture with `stopControllerCapture(): Promise<void>`.

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

Non-standard buttons (paddles, extra buttons) get assigned to higher bits. The JS consumer MUST use the `bit` field from `ControllerButtonInfo` rather than hardcoding positions.

---

# Event System

## Controller Button Events

### Direct Callback (Fast Path)

```ts
registerControllerEventCallback(callback: ControllerEventCallback | null): void;
```

Stores a raw `jsi::Function` and invokes it via `jsInvoker_->invokeAsync()` on button state transitions. This is the lowest-latency path for button events. The callback uses flat arguments to avoid per-event object allocation.

```ts
export type ControllerEventCallback = (
  controllerId: string,
  buttons: Int32,
  lastUpdated: Double,
) => void;
```

The callback receives the entire bitfield. JS diffs against previous to determine which buttons changed (XOR). This avoids per-button event overhead.

Passing `null` unregisters the callback.

### EventEmitter (Slow Path)

The EventEmitter path still uses the struct form:

```ts
export interface ControllerButtonEvent {
  controllerId: string;
  buttons: Int32;
  lastUpdated: Double;
}

readonly onControllerButton: EventEmitter<ControllerButtonEvent>;
```

Same payload as the direct callback, but delivered through the standard RN EventEmitter system. Only fires when `toggleControllerButtonEvents(true)` has been called. Disabled by default because EventEmitter has higher overhead.

```ts
toggleControllerButtonEvents(enabled: boolean): void;
```

This gate ONLY controls the EventEmitter path. The direct callback (if registered) always fires regardless of this toggle.

## Connection Events

```ts
readonly onControllerConnected: EventEmitter<string>;      // controllerId
readonly onControllerDisconnected: EventEmitter<string>;   // controllerId
```

Always active. These are infrequent events — EventEmitter overhead is acceptable.

## Current Controller Change

```ts
readonly onControllerCurrentChange: EventEmitter<string>;  // controllerId
```

Fires when the "current" controller changes (e.g. user switches active controller). Gated by:

```ts
toggleControllerCurrentEvents(enabled: boolean): void;
```

---

# Keyboard Input

## Keyboard Event Callback (Fast Path)

```ts
export type KeyboardEventCallback = (keyCode: Int32, pressed: boolean) => void;

registerKeyboardEventCallback(callback: KeyboardEventCallback | null): void;
```

Flat arguments avoid per-event object allocation. Invoked via `jsInvoker_->invokeAsync`.

## Keyboard EventEmitter (Slow Path)

```ts
export interface KeyboardEvent {
  keyCode: Int32;
  pressed: boolean;
}

readonly onKeyboardEvent: EventEmitter<KeyboardEvent>;
```

Gated by:

```ts
toggleKeyboardEvents(enabled: boolean): void;
```

---

# Mouse Input

## Mouse Button Events

```ts
export type MouseButtonEventCallback = (button: Int32, pressed: boolean) => void;

registerMouseButtonEventCallback(callback: MouseButtonEventCallback | null): void;
```

### EventEmitter

```ts
export interface MouseButtonEvent {
  button: Int32;
  pressed: boolean;
}

readonly onMouseButton: EventEmitter<MouseButtonEvent>;
```

Gated by:

```ts
toggleMouseButtonEvents(enabled: boolean): void;
```

## Mouse Move Events

```ts
export type MouseMoveEventCallback = (deltaX: Int32, deltaY: Int32) => void;

registerMouseMoveEventCallback(callback: MouseMoveEventCallback | null): void;
```

### EventEmitter

```ts
export interface MouseMoveEvent {
  deltaX: Int32;
  deltaY: Int32;
}

readonly onMouseMoveEvent: EventEmitter<MouseMoveEvent>;
```

Gated by:

```ts
toggleMouseMoveEvents(enabled: boolean): void;
```

## Mouse Delta Collection (Polling)

For frame-synced mouse delta without event spam:

```ts
toggleMouseMoveDeltaCollect(enable: boolean): void;
getMouseMoveDeltaAndReset(deltas: Object): void;
```

When enabled, the native layer accumulates mouse deltas. `getMouseMoveDeltaAndReset` writes the accumulated delta into the provided buffer and resets the accumulator. The `deltas` parameter is an `Int32Array` (passed as opaque Object through codegen).

---

# Actions

## setLightColor

```ts
setLightColor(controllerId: string, r: number, g: number, b: number): Promise<void>;
```

Sets the controller's light bar color (DualSense, etc). Values are 0.0–1.0 per channel. Rejects if the controller has no light (`controller.light == nil`).

## setPlayerIndex

```ts
setPlayerIndex(controllerId: string, index: number): Promise<void>;
```

Sets the player index (0–3). Pass -1 to unset (`GCControllerPlayerIndexUnset`).

## shouldMonitorBackgroundEvents

```ts
shouldMonitorBackgroundEvents(enable: boolean): Promise<void>;
```

Enables or disables monitoring of input events when the app is not in the foreground. Disabled by default.

---

# Polling Model

The app may ignore events entirely and rely purely on polling.

## Standard Polling

```ts
const controllers = await GameController.getControllers();
const c = controllers[0];

// discover layout once
const leftStick = c.axes.find(a => a.name === 'Left Thumbstick');
const aButton = c.buttons.find(b => b.name === 'Button A');

// compute analog offset for leftStick
let analogOffset = 0;
for (const axis of c.axes) {
  if (axis === leftStick) break;
  analogOffset += axis.analogCount;
}

// poll every frame
requestAnimationFrame(function loop() {
  const state = GameController.getControllerState(c.controllerId);

  if (leftStick) {
    const lx = state.analog[analogOffset];
    const ly = state.analog[analogOffset + 1];
  }

  if (aButton) {
    const aPressed = (state.buttons & (1 << aButton.bit)) !== 0;
  }

  requestAnimationFrame(loop);
});
```

## Shared Buffer Polling (Zero Allocation)

```ts
const buffers = await GameController.startControllerCapture();
const buf = buffers[0];

requestAnimationFrame(function loop() {
  // Read directly from shared memory — no JS call, no allocation
  const lx = buf.analog[0];
  const ly = buf.analog[1];
  const buttons = buf.buttons[0];
  const timestamp = buf.lastUpdated[0];

  requestAnimationFrame(loop);
});

// When done:
await GameController.stopControllerCapture();
```

---

# Threading Model

## Main Thread

Owns:

* GCController lifecycle
* valueChangedHandler
* Button diff + event generation
* State mutation (writes to atomics / shared buffers)

---

## JavaScript Thread

Owns:

* Polling via JSI (`getControllerState`) or shared buffer reads
* Direct callback invocation (via `jsInvoker_->invokeAsync`)
* EventEmitter delivery

---

## Synchronization

All shared state is lock-free using:

* `std::atomic<float>` for analog values
* `std::atomic<uint32_t>` for button bitfield
* Shared `ArrayBuffer` memory for zero-copy buffer mode

No mutexes. No locks. No condition variables.

---

# Performance Requirements

## Must achieve

* No JS allocations per frame in polling path (especially in shared buffer mode)
* No ObjC calls during `getControllerState`
* O(1) snapshot read per controller
* Stable 60–240Hz polling support

---

# Design Constraints

## Required

* Multiple controllers supported
* Session-stable controller IDs (string)
* Self-describing profiles (no hardcoded bit layouts in JS)
* Frame-based polling for analog input (standard and shared buffer modes)
* Optional event system for buttons (two tiers: fast callback, slow EventEmitter)
* Keyboard and mouse input capture with same two-tier event model
* No analog event spam
* No GC pressure from polling API

---

## Not Supported

* Motion sensors (accelerometer/gyro)
* Force feedback / haptics
* Controller emulation
* Persistent cross-session controller identification

---

# Implementation Notes

## Bit Assignment Strategy

On controller connect, iterate `physicalInputProfile.allButtons` and assign bit positions. Use the standard layout (A=0, B=1, ...) for `GCExtendedGamepad` elements. Assign remaining non-standard buttons to bits 15+.

## Analog Array Layout

On controller connect, iterate axes and assign sequential indices into the analog array. A thumbstick contributes 2 indices (X, Y). A trigger contributes 1 index. The consumer uses `analogCount` from `AxisInfo` to compute offsets by walking the axes array in order.

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

The stored `jsi::Function` from `registerControllerEventCallback` (and keyboard/mouse callbacks) must only be invoked on the JS thread via `jsInvoker_->invokeAsync()`. The main thread computes the diff and dispatches to JS thread for invocation.

## Module Lifecycle

Use the singleton helper pattern from NATIVE.md for bridging the C++ instance to the main thread. Clear the pointer in the destructor to handle JS reloads (Cmd+R) safely.
