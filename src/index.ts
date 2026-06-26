import { nativeModule } from "../spec/NativeGameController";
import type {
  ControllerSharedBuffers,
  Spec,
} from "../spec/NativeGameController";
export type * from "../spec/NativeGameController";

export interface PublicSpec extends Omit<
  Spec,
  "_startControllerCapture" | "getMouseMoveDelta"
> {
  startControllerCapture(): Promise<ControllerSharedBuffers[]>;
  getMouseMoveDeltaAndReset(deltas: Int32Array): void;
}

async function startControllerCapture(): Promise<ControllerSharedBuffers[]> {
  const result = await nativeModule._startControllerCapture();

  return result.map((r) => ({
    controllerId: r.controllerId,
    analog: new Float32Array(r.analog as ArrayBuffer),
    buttons: new Uint32Array(r.buttons as ArrayBuffer),
    lastUpdated: new Float64Array(r.lastUpdated as ArrayBuffer),
  }));
}

const exportedModule = nativeModule as unknown as PublicSpec;

exportedModule.startControllerCapture = startControllerCapture;

export default exportedModule;
