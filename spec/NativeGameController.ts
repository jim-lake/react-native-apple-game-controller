import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

export interface LightColor {
  r: number;
  g: number;
  b: number;
}

export interface ButtonInfo {
  name: string;
  sfSymbol: string | null;
  localizedName: string | null;
  bit: number;
}

export interface AxisInfo {
  name: string;
  sfSymbol: string | null;
  localizedName: string | null;
  analogIndex: number[];
}

export interface DpadInfo {
  name: string;
  up: number;
  down: number;
  left: number;
  right: number;
}

export interface ControllerInfo {
  controllerId: number;
  vendorName: string | null;
  productCategory: string | null;
  playerIndex: number;
  batteryLevel: number | null;
  batteryState: string | null;
  lightColor: LightColor | null;
  isAttached: boolean;
  buttons: ButtonInfo[];
  axes: AxisInfo[];
  dpads: DpadInfo[];
}
export interface ControllerState {
  analog: number[];
  buttons: number;
}
export interface ButtonEvent {
  controllerId: number;
  buttons: number;
}

export type GamepadEventCallback = (event: ButtonEvent) => void;

export interface Spec extends TurboModule {
  getControllers(): Promise<ControllerInfo[]>;
  getControllerState(controllerId: number): ControllerState;
  registerEventCallback(callback: GamepadEventCallback|null): void;
  toggleButtonEvents(enabled: boolean): void;

  readonly onConnected: EventEmitter<number>;
  readonly onDisconnected: EventEmitter<number>;
  readonly onGamepadButton: EventEmitter<ButtonEvent>;

  setLightColor(controllerId: number, r: number, g: number, b: number): Promise<void>;
  setPlayerIndex(controllerId: number, index: number): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('GameControllerModule');
