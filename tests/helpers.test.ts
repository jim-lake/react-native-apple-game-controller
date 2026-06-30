/**
 * Unit tests for src/index.ts helper functions.
 * Uses Node built-in test runner + tsx for TypeScript execution.
 * Mocks the native TurboModule so tests run without React Native.
 */
import { describe, it, beforeEach, mock } from 'node:test';
import assert from 'node:assert';

import type {
  ControllerInfo,
  ControllerSharedBuffers,
} from '../spec/NativeGameController';

// --- Mock native module ---

const mockControllers: ControllerInfo[] = [
  {
    controllerId: 1,
    isCurrent: true,
    vendorName: 'Test Vendor',
    productCategory: 'Gamepad',
    playerIndex: 0,
    batteryLevel: 0.75,
    batteryState: 'charging',
    lightColor: null,
    isAttached: false,
    buttons: [
      { name: 'Button A', sfSymbol: null, localizedName: 'A', bit: 0 },
      { name: 'Button B', sfSymbol: null, localizedName: 'B', bit: 1 },
      { name: 'Button X', sfSymbol: null, localizedName: 'X', bit: 2 },
      { name: 'Button Y', sfSymbol: null, localizedName: 'Y', bit: 3 },
      { name: 'Left Shoulder', sfSymbol: null, localizedName: 'LB', bit: 4 },
      { name: 'Right Shoulder', sfSymbol: null, localizedName: 'RB', bit: 5 },
      { name: 'Left Trigger', sfSymbol: null, localizedName: 'LT', bit: 6 },
      { name: 'Right Trigger', sfSymbol: null, localizedName: 'RT', bit: 7 },
    ],
    axes: [
      { name: 'Left Thumbstick', sfSymbol: null, localizedName: null, analogCount: 2 },
      { name: 'Right Thumbstick', sfSymbol: null, localizedName: null, analogCount: 2 },
      { name: 'Left Trigger', sfSymbol: null, localizedName: null, analogCount: 1 },
      { name: 'Right Trigger', sfSymbol: null, localizedName: null, analogCount: 1 },
    ],
    dpads: [
      { name: 'Direction Pad', up: 8, down: 9, left: 10, right: 11 },
    ],
  },
];

let mockMouseDelta = [0, 0];

const fakeNativeModule = {
  getControllers: async () => mockControllers,
  _startControllerCapture: async () => [],
  _getMouseMoveDeltaAndReset: (buffer: ArrayBuffer) => {
    const view = new Int32Array(buffer);
    view[0] = mockMouseDelta[0];
    view[1] = mockMouseDelta[1];
    mockMouseDelta = [0, 0];
  },
};

// Mock the spec module before importing src/index
mock.module('../spec/NativeGameController', {
  namedExports: {
    nativeModule: fakeNativeModule,
  },
});

// Now import the module under test (after mock is registered)
const GameController = await import('../src/index');
const GC = GameController.default;

// --- Helper to create fake shared buffers ---

function makeBuffers(
  controllerId: number,
  buttonMask: number,
  analogValues: number[] = []
): ControllerSharedBuffers {
  const buttons = new Int32Array(1);
  buttons[0] = buttonMask;
  const analog = new Float32Array(analogValues.length);
  for (let i = 0; i < analogValues.length; i++) {
    analog[i] = analogValues[i];
  }
  const lastUpdated = new Float64Array(1);
  lastUpdated[0] = Date.now();
  return { controllerId, buttons, analog, lastUpdated };
}

// --- Tests ---

describe('getControllers', () => {
  it('returns enriched controllers with buttonMap and axisMap', async () => {
    const controllers = await GC.getControllers();
    assert.strictEqual(controllers.length, 1);

    const c = controllers[0];
    assert.strictEqual(c.controllerId, 1);
    assert.strictEqual(c.vendorName, 'Test Vendor');

    // buttonMap
    assert.strictEqual(c.buttonMap.get('Button A'), 0);
    assert.strictEqual(c.buttonMap.get('Button B'), 1);
    assert.strictEqual(c.buttonMap.get('Button Y'), 3);
    assert.strictEqual(c.buttonMap.get('Right Trigger'), 7);

    // axisMap: Left Thumbstick=0, Right Thumbstick=2, Left Trigger=4, Right Trigger=5
    assert.strictEqual(c.axisMap.get('Left Thumbstick'), 0);
    assert.strictEqual(c.axisMap.get('Right Thumbstick'), 2);
    assert.strictEqual(c.axisMap.get('Left Trigger'), 4);
    assert.strictEqual(c.axisMap.get('Right Trigger'), 5);
  });

  it('caches controllers for getControllerInfo lookup', async () => {
    await GC.getControllers();
    const info = GC.getControllerInfo(1);
    assert.ok(info);
    assert.strictEqual(info.vendorName, 'Test Vendor');
  });

  it('returns undefined for unknown controller id', async () => {
    await GC.getControllers();
    const info = GC.getControllerInfo(999);
    assert.strictEqual(info, undefined);
  });
});

describe('isButtonPressed', () => {
  it('returns true when bit is set', () => {
    const buf = makeBuffers(1, 0b0101); // bits 0 and 2
    assert.strictEqual(GC.isButtonPressed(buf, 0), true);
    assert.strictEqual(GC.isButtonPressed(buf, 2), true);
  });

  it('returns false when bit is not set', () => {
    const buf = makeBuffers(1, 0b0101);
    assert.strictEqual(GC.isButtonPressed(buf, 1), false);
    assert.strictEqual(GC.isButtonPressed(buf, 3), false);
  });
});

describe('isButtonPressedByName', () => {
  beforeEach(async () => {
    await GC.getControllers(); // ensure cache populated
  });

  it('returns true for pressed button by name', () => {
    const buf = makeBuffers(1, 1 << 0); // Button A pressed
    assert.strictEqual(GC.isButtonPressedByName(buf, 'Button A'), true);
  });

  it('returns false for unpressed button by name', () => {
    const buf = makeBuffers(1, 1 << 0);
    assert.strictEqual(GC.isButtonPressedByName(buf, 'Button B'), false);
  });

  it('returns false for unknown button name', () => {
    const buf = makeBuffers(1, 0xFFFF);
    assert.strictEqual(GC.isButtonPressedByName(buf, 'Nonexistent'), false);
  });

  it('returns false for unknown controller', () => {
    const buf = makeBuffers(999, 0xFFFF);
    assert.strictEqual(GC.isButtonPressedByName(buf, 'Button A'), false);
  });
});

describe('getPressedButtons', () => {
  beforeEach(async () => {
    await GC.getControllers();
  });

  it('returns all pressed buttons', () => {
    const buf = makeBuffers(1, 0b1010); // bits 1 and 3
    const pressed = GC.getPressedButtons(buf);
    const names = pressed.map((b) => b.name).sort();
    assert.deepStrictEqual(names, ['Button B', 'Button Y']);
  });

  it('returns empty when nothing pressed', () => {
    const buf = makeBuffers(1, 0);
    const pressed = GC.getPressedButtons(buf);
    assert.strictEqual(pressed.length, 0);
  });

  it('returns empty for unknown controller', () => {
    const buf = makeBuffers(999, 0xFFFF);
    const pressed = GC.getPressedButtons(buf);
    assert.strictEqual(pressed.length, 0);
  });
});

describe('getAxisByName', () => {
  beforeEach(async () => {
    await GC.getControllers();
  });

  it('returns axis value by name', () => {
    // Left Thumbstick at offset 0, Right Thumbstick at offset 2
    const buf = makeBuffers(1, 0, [0.5, -0.3, 0.8, 0.1, 0.6, 0.9]);
    const val = GC.getAxisByName(buf, 'Left Trigger')!; // offset 4
    assert.ok(Math.abs(val - 0.6) < 0.001);
  });

  it('returns undefined for unknown axis name', () => {
    const buf = makeBuffers(1, 0, [0, 0, 0, 0, 0, 0]);
    assert.strictEqual(GC.getAxisByName(buf, 'Nonexistent'), undefined);
  });

  it('returns undefined for unknown controller', () => {
    const buf = makeBuffers(999, 0, [0.5]);
    assert.strictEqual(GC.getAxisByName(buf, 'Left Thumbstick'), undefined);
  });
});

describe('getStickByName', () => {
  beforeEach(async () => {
    await GC.getControllers();
  });

  it('returns x,y for a 2-axis stick', () => {
    const buf = makeBuffers(1, 0, [0.7, -0.4, 0.2, 0.9, 0, 0]);
    const stick = GC.getStickByName(buf, 'Left Thumbstick');
    assert.ok(stick);
    assert.strictEqual(stick.x.toFixed(1), '0.7');
    assert.strictEqual(stick.y.toFixed(1), '-0.4');
  });

  it('returns x,y for right thumbstick', () => {
    const buf = makeBuffers(1, 0, [0, 0, 0.3, -0.8, 0, 0]);
    const stick = GC.getStickByName(buf, 'Right Thumbstick');
    assert.ok(stick);
    assert.strictEqual(stick.x.toFixed(1), '0.3');
    assert.strictEqual(stick.y.toFixed(1), '-0.8');
  });

  it('returns undefined for unknown stick', () => {
    const buf = makeBuffers(1, 0, [0, 0, 0, 0, 0, 0]);
    assert.strictEqual(GC.getStickByName(buf, 'Nonexistent'), undefined);
  });
});

describe('getDpad', () => {
  beforeEach(async () => {
    await GC.getControllers();
  });

  it('returns dpad state from button mask', () => {
    // dpad: up=8, down=9, left=10, right=11
    const buf = makeBuffers(1, (1 << 8) | (1 << 11)); // up + right
    const dpad = GC.getDpad(buf, 0);
    assert.ok(dpad);
    assert.strictEqual(dpad.up, true);
    assert.strictEqual(dpad.down, false);
    assert.strictEqual(dpad.left, false);
    assert.strictEqual(dpad.right, true);
  });

  it('returns all false when no dpad buttons pressed', () => {
    const buf = makeBuffers(1, 0);
    const dpad = GC.getDpad(buf, 0);
    assert.ok(dpad);
    assert.strictEqual(dpad.up, false);
    assert.strictEqual(dpad.down, false);
    assert.strictEqual(dpad.left, false);
    assert.strictEqual(dpad.right, false);
  });

  it('returns undefined for invalid dpad index', () => {
    const buf = makeBuffers(1, 0);
    assert.strictEqual(GC.getDpad(buf, 5), undefined);
  });

  it('returns undefined for unknown controller', () => {
    const buf = makeBuffers(999, 0xFF);
    assert.strictEqual(GC.getDpad(buf, 0), undefined);
  });
});

describe('didButtonChange', () => {
  it('detects newly pressed button', () => {
    const buf = makeBuffers(1, 0b0001); // bit 0 now pressed
    const result = GC.didButtonChange(0b0000, buf, 0);
    assert.strictEqual(result.pressed, true);
    assert.strictEqual(result.released, false);
  });

  it('detects newly released button', () => {
    const buf = makeBuffers(1, 0b0000); // bit 0 now released
    const result = GC.didButtonChange(0b0001, buf, 0);
    assert.strictEqual(result.pressed, false);
    assert.strictEqual(result.released, true);
  });

  it('detects no change when still pressed', () => {
    const buf = makeBuffers(1, 0b0001);
    const result = GC.didButtonChange(0b0001, buf, 0);
    assert.strictEqual(result.pressed, false);
    assert.strictEqual(result.released, false);
  });

  it('detects no change when still released', () => {
    const buf = makeBuffers(1, 0b0000);
    const result = GC.didButtonChange(0b0000, buf, 0);
    assert.strictEqual(result.pressed, false);
    assert.strictEqual(result.released, false);
  });
});

describe('getMouseMoveAndReset', () => {
  it('returns mouse deltas and resets', () => {
    mockMouseDelta = [42, -17];
    const [dx, dy] = GC.getMouseMoveAndReset();
    assert.strictEqual(dx, 42);
    assert.strictEqual(dy, -17);

    // After reset, should be 0
    const [dx2, dy2] = GC.getMouseMoveAndReset();
    assert.strictEqual(dx2, 0);
    assert.strictEqual(dy2, 0);
  });
});
