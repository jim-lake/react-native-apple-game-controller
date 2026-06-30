import { nativeModule } from '../spec/NativeGameController';
import type {
  ControllerSharedBuffers,
  ControllerInfo,
  ControllerButtonInfo,
  AxisInfo,
  Spec,
} from '../spec/NativeGameController';
export type * from '../spec/NativeGameController';

// --- Enriched Controller Info ---

export interface EnrichedControllerInfo extends ControllerInfo {
  buttonMap: Map<string, number>; // name → bit
  axisMap: Map<string, number>; // name → offset into analog buffer
}

// --- Internal cache ---

const _controllerCache = new Map<number, EnrichedControllerInfo>();

function buildAxisMap(axes: AxisInfo[]): Map<string, number> {
  const map = new Map<string, number>();
  let offset = 0;
  for (const axis of axes) {
    map.set(axis.name, offset);
    offset += axis.analogCount;
  }
  return map;
}

// --- Public API type ---

export interface PublicSpec extends Omit<
  Spec,
  '_startControllerCapture' | '_getMouseMoveDeltaAndReset' | 'getControllers'
> {
  getControllers(): Promise<EnrichedControllerInfo[]>;
  startControllerCapture(): Promise<ControllerSharedBuffers[]>;
  getMouseMoveDeltaAndReset(deltas: Int32Array): void;
  getMouseMoveAndReset(): [number, number];
  getControllerInfo(controllerId: number): EnrichedControllerInfo | undefined;
  isButtonPressed(buffers: ControllerSharedBuffers, bit: number): boolean;
  isButtonPressedByName(
    buffers: ControllerSharedBuffers,
    name: string
  ): boolean;
  getPressedButtons(buffers: ControllerSharedBuffers): ControllerButtonInfo[];
  getAxisByName(
    buffers: ControllerSharedBuffers,
    name: string
  ): number | undefined;
  getStickByName(
    buffers: ControllerSharedBuffers,
    name: string
  ): { x: number; y: number } | undefined;
  getDpad(
    buffers: ControllerSharedBuffers,
    dpadIndex?: number
  ): { up: boolean; down: boolean; left: boolean; right: boolean } | undefined;
  didButtonChange(
    prevMask: number,
    buffers: ControllerSharedBuffers,
    bit: number
  ): { pressed: boolean; released: boolean };
}

// --- Implementations ---

// Capture original native getControllers before we overwrite it on the shared object
const _nativeGetControllers = nativeModule.getControllers.bind(nativeModule);

async function getControllers(): Promise<EnrichedControllerInfo[]> {
  const controllers = await _nativeGetControllers();
  _controllerCache.clear();

  return controllers.map((c) => {
    const enriched: EnrichedControllerInfo = {
      ...c,
      buttonMap: new Map(c.buttons.map((b) => [b.name, b.bit])),
      axisMap: buildAxisMap(c.axes),
    };
    _controllerCache.set(c.controllerId, enriched);
    return enriched;
  });
}

async function startControllerCapture(): Promise<ControllerSharedBuffers[]> {
  const result = await nativeModule._startControllerCapture();

  return result.map((r) => ({
    controllerId: r.controllerId,
    analog: new Float32Array(r.analog as ArrayBuffer),
    buttons: new Int32Array(r.buttons as ArrayBuffer),
    lastUpdated: new Float64Array(r.lastUpdated as ArrayBuffer),
  }));
}

const _mouseDeltaBuf = new Int32Array(2);

function getMouseMoveAndReset(): [number, number] {
  nativeModule._getMouseMoveDeltaAndReset(_mouseDeltaBuf.buffer);
  return [_mouseDeltaBuf[0], _mouseDeltaBuf[1]];
}

function getControllerInfo(
  controllerId: number
): EnrichedControllerInfo | undefined {
  return _controllerCache.get(controllerId);
}

function isButtonPressed(
  buffers: ControllerSharedBuffers,
  bit: number
): boolean {
  return (buffers.buttons[0] & (1 << bit)) !== 0;
}

function isButtonPressedByName(
  buffers: ControllerSharedBuffers,
  name: string
): boolean {
  const info = _controllerCache.get(buffers.controllerId);
  if (!info) {
    return false;
  }
  const bit = info.buttonMap.get(name);
  if (bit === undefined) {
    return false;
  }
  return (buffers.buttons[0] & (1 << bit)) !== 0;
}

function getPressedButtons(
  buffers: ControllerSharedBuffers
): ControllerButtonInfo[] {
  const info = _controllerCache.get(buffers.controllerId);
  if (!info) {
    return [];
  }
  const mask = buffers.buttons[0];
  return info.buttons.filter((b) => (mask & (1 << b.bit)) !== 0);
}

function getAxisByName(
  buffers: ControllerSharedBuffers,
  name: string
): number | undefined {
  const info = _controllerCache.get(buffers.controllerId);
  if (!info) {
    return undefined;
  }
  const offset = info.axisMap.get(name);
  if (offset === undefined) {
    return undefined;
  }
  return buffers.analog[offset];
}

function getStickByName(
  buffers: ControllerSharedBuffers,
  name: string
): { x: number; y: number } | undefined {
  const info = _controllerCache.get(buffers.controllerId);
  if (!info) {
    return undefined;
  }
  const offset = info.axisMap.get(name);
  if (offset === undefined) {
    return undefined;
  }
  return { x: buffers.analog[offset], y: buffers.analog[offset + 1] };
}

function getDpad(
  buffers: ControllerSharedBuffers,
  dpadIndex: number = 0
): { up: boolean; down: boolean; left: boolean; right: boolean } | undefined {
  const info = _controllerCache.get(buffers.controllerId);
  if (!info) {
    return undefined;
  }
  const dpad = info.dpads[dpadIndex];
  if (!dpad) {
    return undefined;
  }
  const mask = buffers.buttons[0];
  return {
    up: (mask & (1 << dpad.up)) !== 0,
    down: (mask & (1 << dpad.down)) !== 0,
    left: (mask & (1 << dpad.left)) !== 0,
    right: (mask & (1 << dpad.right)) !== 0,
  };
}

function didButtonChange(
  prevMask: number,
  buffers: ControllerSharedBuffers,
  bit: number
): { pressed: boolean; released: boolean } {
  const was = (prevMask & (1 << bit)) !== 0;
  const is = (buffers.buttons[0] & (1 << bit)) !== 0;
  return { pressed: !was && is, released: was && !is };
}

// --- Build exported module ---

const exportedModule = nativeModule as unknown as PublicSpec;

exportedModule.getControllers = getControllers;
exportedModule.startControllerCapture = startControllerCapture;
exportedModule.getMouseMoveDeltaAndReset = (deltas: Int32Array) => {
  nativeModule._getMouseMoveDeltaAndReset(deltas.buffer);
};
exportedModule.getMouseMoveAndReset = getMouseMoveAndReset;
exportedModule.getControllerInfo = getControllerInfo;
exportedModule.isButtonPressed = isButtonPressed;
exportedModule.isButtonPressedByName = isButtonPressedByName;
exportedModule.getPressedButtons = getPressedButtons;
exportedModule.getAxisByName = getAxisByName;
exportedModule.getStickByName = getStickByName;
exportedModule.getDpad = getDpad;
exportedModule.didButtonChange = didButtonChange;

export default exportedModule;
