import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";
import type { EventEmitter } from "react-native/Libraries/Types/CodegenTypes";

export interface LightColor {
  r: number;
  g: number;
  b: number;
}
export interface ControllerButtonInfo {
  name: string;
  sfSymbol: string | null;
  localizedName: string | null;
  bit: number;
}
export interface AxisInfo {
  name: string;
  sfSymbol: string | null;
  localizedName: string | null;
  analogCount: number;
}
export interface DpadInfo {
  name: string;
  up: number;
  down: number;
  left: number;
  right: number;
}
export interface ControllerInfo {
  controllerId: string;
  isCurrent: boolean;
  vendorName: string | null;
  productCategory: string | null;
  playerIndex: number;
  batteryLevel: number | null;
  batteryState: string | null;
  lightColor: LightColor | null;
  isAttached: boolean;
  buttons: ControllerButtonInfo[];
  axes: AxisInfo[];
  dpads: DpadInfo[];
}
export interface ControllerState {
  analog: number[];
  buttons: number;
}
export interface ControllerButtonEvent {
  controllerId: string;
  buttons: number;
  lastUpdated: number;
}
export interface KeyboardEvent {
  keyCode: number;
  pressed: boolean;
}
export interface MouseButtonEvent {
  button: number;
  pressed: boolean;
}
export interface MouseMoveEvent {
  deltaX: number;
  deltaY: number;
}

export type ControllerEventCallback = (event: ControllerButtonEvent) => void;
export type KeyboardEventCallback = (event: KeyboardEvent) => void;
export type MouseButtonEventCallback = (event: MouseButtonEvent) => void;
export type MouseMoveEventCallback = (event: MouseMoveEvent) => void;

export interface InternalControllerSharedBuffers {
  controllerId: string;
  analog: object;
  buttons: object;
  lastUpdated: object;
}
export interface ControllerSharedBuffers {
  controllerId: string;
  analog: Float32Array;
  buttons: Uint32Array;
  lastUpdated: Float64Array;
}
export interface Spec extends TurboModule {
  getControllers(): Promise<ControllerInfo[]>;
  getControllerState(controllerId: string): ControllerState;
  registerControllerEventCallback(
    callback: ControllerEventCallback | null,
  ): void;
  registerKeyboardEventCallback(callback: KeyboardEventCallback | null): void;
  registerMouseButtonEventCallback(
    callback: MouseButtonEventCallback | null,
  ): void;
  registerMouseMoveEventCallback(callback: MouseMoveEventCallback | null): void;
  _startControllerCapture(): Promise<InternalControllerSharedBuffers[]>;
  stopControllerCapture(): Promise<void>;
  toggleMouseMoveDeltaCollect(enable: boolean): void;
  getMouseMoveDeltaAndReset(deltas: object): void;

  toggleControllerButtonEvents(enable: boolean): void;
  toggleKeyboardEvents(enable: boolean): void;
  toggleMouseButtonEvents(enable: boolean): void;
  toggleMouseMoveEvents(enable: boolean): void;
  setLightColor(
    controllerId: string,
    r: number,
    g: number,
    b: number,
  ): Promise<void>;
  setPlayerIndex(controllerId: string, index: number): Promise<void>;
  shouldMonitorBackgroundEvents(enable: boolean): Promise<void>;

  readonly onControllerConnected: EventEmitter<string>;
  readonly onControllerDisconnected: EventEmitter<string>;
  readonly onControllerCurrentChange: EventEmitter<string | null>;
  readonly onControllerButton: EventEmitter<ControllerButtonEvent>;
  readonly onKeyboardEvent: EventEmitter<KeyboardEvent>;
  readonly onMouseButton: EventEmitter<MouseButtonEvent>;
  readonly onMouseMoveEvent: EventEmitter<MouseMoveEvent>;
}

export const nativeModule = TurboModuleRegistry.getEnforcing<Spec>(
  "GameControllerModule",
);
