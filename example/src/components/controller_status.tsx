import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import GameController from 'react-native-apple-game-controller';
import type {
  ControllerSharedBuffers,
  EnrichedControllerInfo,
  ControllerButtonInfo,
} from 'react-native-apple-game-controller';
import { addLine } from '../log_store';

interface Props {
  controller: EnrichedControllerInfo;
  pollingEnabled: boolean;
}

interface ControllerVisualState {
  pressedButtons: ControllerButtonInfo[];
  axisValues: Map<string, number[]>;
  dpadStates: {
    name: string;
    up: boolean;
    down: boolean;
    left: boolean;
    right: boolean;
  }[];
  lastUpdated: number;
}

export function ControllerStatus({ controller, pollingEnabled }: Props) {
  const [visualState, setVisualState] = useState<ControllerVisualState | null>(
    null
  );
  const buffersRef = useRef<ControllerSharedBuffers | null>(null);
  const rafRef = useRef<number>(0);
  const prevMaskRef = useRef<number>(0);

  useEffect(() => {
    if (!pollingEnabled) {
      addLine(`[poll] Stopped for ${controller.controllerId}`);
      return;
    }

    addLine(`[poll] Starting capture for ${controller.controllerId}`);
    let active = true;

    GameController.startControllerCapture()
      .then((allBuffers) => {
        if (!active) {
          return;
        }
        const buf = allBuffers.find(
          (b) => b.controllerId === controller.controllerId
        );
        if (!buf) {
          addLine(
            `[error] No shared buffers for controller ${controller.controllerId}`
          );
          return;
        }
        buffersRef.current = buf;

        const poll = () => {
          if (!active) {
            return;
          }
          const b = buffersRef.current;
          if (b) {
            const currentMask = b.buttons[0];

            // Detect newly pressed buttons and log their names
            if (currentMask !== prevMaskRef.current) {
              const newlyPressed = currentMask & ~prevMaskRef.current;
              if (newlyPressed !== 0) {
                const names = controller.buttons
                  .filter((btn) => (newlyPressed & (1 << btn.bit)) !== 0)
                  .map((btn) => btn.name);
                if (names.length > 0) {
                  addLine(`[press] ${names.join(', ')}`);
                }
              }
              const newlyReleased = prevMaskRef.current & ~currentMask;
              if (newlyReleased !== 0) {
                const names = controller.buttons
                  .filter((btn) => (newlyReleased & (1 << btn.bit)) !== 0)
                  .map((btn) => btn.name);
                if (names.length > 0) {
                  addLine(`[release] ${names.join(', ')}`);
                }
              }
              prevMaskRef.current = currentMask;
            }

            // Build visual state
            const pressedButtons = GameController.getPressedButtons(b);

            const axisValues = new Map<string, number[]>();
            for (const axis of controller.axes) {
              const offset = controller.axisMap.get(axis.name);
              if (offset !== undefined) {
                const values: number[] = [];
                for (let i = 0; i < axis.analogCount; i++) {
                  values.push(b.analog[offset + i]);
                }
                axisValues.set(axis.name, values);
              }
            }

            const dpadStates = controller.dpads.map((dpad, idx) => {
              const state = GameController.getDpad(b, idx);
              return {
                name: dpad.name,
                up: state?.up ?? false,
                down: state?.down ?? false,
                left: state?.left ?? false,
                right: state?.right ?? false,
              };
            });

            setVisualState({
              pressedButtons,
              axisValues,
              dpadStates,
              lastUpdated: b.lastUpdated[0],
            });
          }
          rafRef.current = requestAnimationFrame(poll);
        };
        rafRef.current = requestAnimationFrame(poll);
      })
      .catch((e: any) => {
        addLine(`[error] startControllerCapture: ${e.message}`);
      });

    return () => {
      active = false;
      cancelAnimationFrame(rafRef.current);
      GameController.stopControllerCapture().catch(() => {});
    };
  }, [controller, pollingEnabled]);

  return (
    <View style={styles.container}>
      {/* Header: Controller Info */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>
          {controller.vendorName ?? 'Unknown Vendor'} —{' '}
          {controller.productCategory ?? 'Unknown'}
        </Text>
        <Text style={styles.headerDetail}>
          ID: {controller.controllerId} | Player: {controller.playerIndex} |{' '}
          {controller.isCurrent ? '★ Current' : 'Not Current'} |{' '}
          {controller.isAttached ? 'Attached' : 'Wireless'}
        </Text>
        {controller.batteryLevel != null && (
          <Text style={styles.headerDetail}>
            Battery: {(controller.batteryLevel * 100).toFixed(0)}% (
            {controller.batteryState})
          </Text>
        )}
        {controller.lightColor && (
          <View style={styles.lightColorRow}>
            <Text style={styles.headerDetail}>Light: </Text>
            <View
              style={[
                styles.lightSwatch,
                {
                  backgroundColor: `rgb(${Math.round(controller.lightColor.r * 255)}, ${Math.round(controller.lightColor.g * 255)}, ${Math.round(controller.lightColor.b * 255)})`,
                },
              ]}
            />
          </View>
        )}
      </View>

      {!visualState ? (
        <Text style={styles.noState}>Waiting for data...</Text>
      ) : (
        <View style={styles.body}>
          {/* Buttons Grid */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>
              Buttons ({controller.buttons.length})
            </Text>
            <View style={styles.buttonGrid}>
              {controller.buttons.map((btn) => {
                const isPressed = visualState.pressedButtons.some(
                  (p) => p.bit === btn.bit
                );
                return (
                  <View
                    key={btn.bit}
                    style={[
                      styles.buttonCell,
                      isPressed && styles.buttonCellPressed,
                    ]}
                  >
                    <Text
                      style={[
                        styles.buttonName,
                        isPressed && styles.buttonNamePressed,
                      ]}
                      numberOfLines={1}
                    >
                      {btn.name}
                    </Text>
                  </View>
                );
              })}
            </View>
          </View>

          {/* Axes */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>
              Axes ({controller.axes.length})
            </Text>
            {controller.axes.map((axis) => {
              const values = visualState.axisValues.get(axis.name) ?? [];
              if (axis.analogCount === 2) {
                // Stick — show as crosshair
                const x = values[0] ?? 0;
                const y = values[1] ?? 0;
                return (
                  <View key={axis.name} style={styles.stickContainer}>
                    <Text style={styles.axisLabel}>{axis.name}</Text>
                    <View style={styles.stickBox}>
                      <View
                        style={[
                          styles.stickDot,
                          {
                            left: `${50 + x * 50}%` as any,
                            top: `${50 - y * 50}%` as any,
                          },
                        ]}
                      />
                      {/* Crosshair lines */}
                      <View style={styles.stickCrossH} />
                      <View style={styles.stickCrossV} />
                    </View>
                    <Text style={styles.axisValue}>
                      x: {x.toFixed(2)} y: {y.toFixed(2)}
                    </Text>
                  </View>
                );
              }
              // Single axis — show as bar
              const val = values[0] ?? 0;
              return (
                <View key={axis.name} style={styles.axisRow}>
                  <Text style={styles.axisLabel}>{axis.name}</Text>
                  <View style={styles.axisBar}>
                    <View
                      style={[
                        styles.axisBarFill,
                        { width: `${Math.abs(val) * 100}%` as any },
                      ]}
                    />
                  </View>
                  <Text style={styles.axisValue}>{val.toFixed(2)}</Text>
                </View>
              );
            })}
          </View>

          {/* DPads */}
          {controller.dpads.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>
                D-Pads ({controller.dpads.length})
              </Text>
              {visualState.dpadStates.map((dpad) => (
                <View key={dpad.name} style={styles.dpadContainer}>
                  <Text style={styles.axisLabel}>{dpad.name}</Text>
                  <View style={styles.dpadGrid}>
                    <View style={styles.dpadRow}>
                      <View style={styles.dpadEmpty} />
                      <View
                        style={[
                          styles.dpadBtn,
                          dpad.up && styles.dpadBtnActive,
                        ]}
                      >
                        <Text style={styles.dpadText}>▲</Text>
                      </View>
                      <View style={styles.dpadEmpty} />
                    </View>
                    <View style={styles.dpadRow}>
                      <View
                        style={[
                          styles.dpadBtn,
                          dpad.left && styles.dpadBtnActive,
                        ]}
                      >
                        <Text style={styles.dpadText}>◀</Text>
                      </View>
                      <View style={styles.dpadCenter} />
                      <View
                        style={[
                          styles.dpadBtn,
                          dpad.right && styles.dpadBtnActive,
                        ]}
                      >
                        <Text style={styles.dpadText}>▶</Text>
                      </View>
                    </View>
                    <View style={styles.dpadRow}>
                      <View style={styles.dpadEmpty} />
                      <View
                        style={[
                          styles.dpadBtn,
                          dpad.down && styles.dpadBtnActive,
                        ]}
                      >
                        <Text style={styles.dpadText}>▼</Text>
                      </View>
                      <View style={styles.dpadEmpty} />
                    </View>
                  </View>
                </View>
              ))}
            </View>
          )}

          {/* Timestamp */}
          <Text style={styles.timestamp}>
            Last updated: {visualState.lastUpdated.toFixed(3)}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 10,
    borderWidth: 1,
    borderColor: '#555',
    marginBottom: 8,
    borderRadius: 6,
    backgroundColor: '#252525',
  },
  header: {
    marginBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#444',
    paddingBottom: 6,
  },
  headerTitle: {
    fontSize: 13,
    color: '#fff',
    fontWeight: '600',
    marginBottom: 2,
  },
  headerDetail: { fontSize: 10, color: '#aaa', fontFamily: 'Menlo' },
  lightColorRow: { flexDirection: 'row', alignItems: 'center', marginTop: 2 },
  lightSwatch: {
    width: 12,
    height: 12,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#666',
  },
  noState: { fontSize: 11, color: '#888', fontStyle: 'italic' },
  body: {},
  section: { marginBottom: 8 },
  sectionTitle: {
    fontSize: 11,
    color: '#8af',
    marginBottom: 4,
    fontWeight: '500',
  },

  // Buttons
  buttonGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 3 },
  buttonCell: {
    paddingHorizontal: 5,
    paddingVertical: 2,
    borderRadius: 3,
    backgroundColor: '#333',
    borderWidth: 1,
    borderColor: '#555',
  },
  buttonCellPressed: { backgroundColor: '#4a4', borderColor: '#6c6' },
  buttonName: { fontSize: 9, color: '#ccc', fontFamily: 'Menlo' },
  buttonNamePressed: { color: '#fff', fontWeight: '700' },

  // Axes
  stickContainer: { marginBottom: 6 },
  stickBox: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#333',
    borderWidth: 1,
    borderColor: '#555',
    position: 'relative',
    overflow: 'hidden',
  },
  stickDot: {
    position: 'absolute',
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#6f6',
    marginLeft: -5,
    marginTop: -5,
  },
  stickCrossH: {
    position: 'absolute',
    top: '50%',
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: '#555',
  },
  stickCrossV: {
    position: 'absolute',
    left: '50%',
    top: 0,
    bottom: 0,
    width: 1,
    backgroundColor: '#555',
  },
  axisRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 3 },
  axisLabel: { fontSize: 9, color: '#aaa', width: 100, fontFamily: 'Menlo' },
  axisBar: {
    flex: 1,
    height: 8,
    backgroundColor: '#333',
    borderRadius: 4,
    overflow: 'hidden',
    marginHorizontal: 4,
  },
  axisBarFill: { height: '100%', backgroundColor: '#6af', borderRadius: 4 },
  axisValue: {
    fontSize: 9,
    color: '#aaa',
    width: 60,
    textAlign: 'right',
    fontFamily: 'Menlo',
  },

  // DPad
  dpadContainer: { marginBottom: 6 },
  dpadGrid: { alignItems: 'center' },
  dpadRow: { flexDirection: 'row' },
  dpadBtn: {
    width: 20,
    height: 20,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#333',
    borderWidth: 1,
    borderColor: '#555',
    borderRadius: 3,
    margin: 1,
  },
  dpadBtnActive: { backgroundColor: '#4a4', borderColor: '#6c6' },
  dpadText: { fontSize: 10, color: '#ccc' },
  dpadEmpty: { width: 22, height: 22 },
  dpadCenter: { width: 20, height: 20, margin: 1 },

  // Timestamp
  timestamp: { fontSize: 9, color: '#666', fontFamily: 'Menlo', marginTop: 4 },
});
