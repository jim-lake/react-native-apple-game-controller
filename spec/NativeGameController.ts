import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";
import type {
  Double,
  EventEmitter,
  Float,
  Int32,
} from "react-native/Libraries/Types/CodegenTypes";

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
  analog: Float[];
  buttons: Int32;
  lastUpdated: Double;
}
export interface ControllerButtonEvent {
  controllerId: string;
  buttons: Int32;
  lastUpdated: Double;
}
export interface KeyboardEvent {
  keyCode: Int32;
  pressed: boolean;
}
export interface MouseButtonEvent {
  button: Int32;
  pressed: boolean;
}
export interface MouseMoveEvent {
  deltaX: Int32;
  deltaY: Int32;
}

export type ControllerEventCallback = (
  controllerId: string,
  buttons: Int32,
  lastUpdated: Double,
) => void;
export type KeyboardEventCallback = (keyCode: Int32, pressed: boolean) => void;
export type MouseButtonEventCallback = (
  button: number,
  pressed: boolean,
) => void;
export type MouseMoveEventCallback = (deltaX: Int32, deltaY: Int32) => void;

export interface InternalControllerSharedBuffers {
  controllerId: string;
  analog: Object;
  buttons: Object;
  lastUpdated: Object;
}
export interface ControllerSharedBuffers {
  controllerId: string;
  analog: Float32Array;
  buttons: Int32Array;
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
  getMouseMoveDeltaAndReset(deltas: Object): void;

  toggleControllerCurrentEvents(enable: boolean): void;
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
  readonly onControllerCurrentChange: EventEmitter<string>;
  readonly onControllerButton: EventEmitter<ControllerButtonEvent>;
  readonly onKeyboardEvent: EventEmitter<KeyboardEvent>;
  readonly onMouseButton: EventEmitter<MouseButtonEvent>;
  readonly onMouseMoveEvent: EventEmitter<MouseMoveEvent>;
}

export const nativeModule = TurboModuleRegistry.getEnforcing<Spec>(
  "GameControllerModule",
);
