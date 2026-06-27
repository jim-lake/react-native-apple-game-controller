import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import GameController from 'react-native-apple-game-controller';
import type { ControllerInfo } from 'react-native-apple-game-controller';
import { addLine } from './log_store';
import { ControllerStatus } from './components/controller_status';
import { LogBox } from './components/log_box';

import { startReportingRAF, cancelReportingRAF } from './tools/reporting_raf';

const g_mouseBuffer = new Int32Array(2);

function ToggleButton({
  label,
  onToggle,
}: {
  label: string;
  onToggle: (v: boolean) => void;
}) {
  const [on, setOn] = useState(false);
  return (
    <View style={styles.toggleRow}>
      <Text style={styles.toggleLabel}>
        {label}: {on ? 'ON' : 'OFF'}
      </Text>
      <Pressable
        style={[styles.btn, on && styles.btnOn]}
        onPress={() => {
          const next = !on;
          setOn(next);
          try {
            addLine(`[toggle] ${label} → ${next ? 'ON' : 'OFF'}`);
            onToggle(next);
          } catch (e: any) {
            addLine(`[error] toggle ${label}: ${e.message}`);
          }
        }}
      >
        <Text style={styles.btnText}>{on ? 'Disable' : 'Enable'}</Text>
      </Pressable>
    </View>
  );
}

function fpsReporter(fps: number) {
  addLine(`[mouse-delta]: fps: ${fps}`);
}

function MouseDeltaPolling() {
  const [enabled, setEnabled] = useState(false);
  const enabledRef = React.useRef(false);

  useEffect(() => {
    enabledRef.current = enabled;
    if (!enabled) {
      return;
    }
    GameController.toggleMouseMoveDeltaCollect(true);
    function work() {
      GameController.getMouseMoveDeltaAndReset(g_mouseBuffer);
      if (g_mouseBuffer[0] !== 0 || g_mouseBuffer[1] !== 0) {
        addLine(`[mouse-delta] dx=${g_mouseBuffer[0]} dy=${g_mouseBuffer[1]}`);
      }
    }
    addLine(`[mouse-delta] start polling`);
    const handle = startReportingRAF({ work, fpsReporter });
    return () => {
      addLine(`[mouse-delta] stop polling`);
      cancelReportingRAF(handle);
      GameController.toggleMouseMoveDeltaCollect(false);
    };
  }, [enabled]);

  return (
    <View style={styles.toggleRow}>
      <Text style={styles.toggleLabel}>
        Mouse Move Polling: {enabled ? 'ON' : 'OFF'}
      </Text>
      <Pressable
        style={[styles.btn, enabled && styles.btnOn]}
        onPress={() => setEnabled((v) => !v)}
      >
        <Text style={styles.btnText}>{enabled ? 'Disable' : 'Enable'}</Text>
      </Pressable>
    </View>
  );
}

function App(): React.JSX.Element {
  const [controllers, setControllers] = useState<ControllerInfo[]>([]);
  const [polling, setPolling] = useState(true);

  useEffect(() => {
    addLine('[startup] App mounted');
    try {
      addLine('[startup] Fetching controllers...');
      GameController.getControllers()
        .then((c) => {
          addLine(`[startup] Found ${c.length} controller(s)`);
          setControllers(c);
        })
        .catch((e: any) => addLine(`[error] getControllers: ${e.message}`));
      GameController.hasKeyboard()
        .then((v) => addLine(`[startup] hasKeyboard: ${v}`))
        .catch((e: any) => addLine(`[error] hasKeyboard: ${e.message}`));
      GameController.hasMouse()
        .then((v) => addLine(`[startup] hasMouse: ${v}`))
        .catch((e: any) => addLine(`[error] hasMouse: ${e.message}`));
    } catch (e: any) {
      addLine(`[error] startup: ${e.message}`);
    }
  }, []);

  // Subscribe to EventEmitter events
  useEffect(() => {
    addLine('[events] Subscribing to all EventEmitters...');
    try {
      const subs = [
        GameController.onControllerConnected((id) => {
          addLine(`[connect] ${id}`);
          try {
            GameController.getControllers()
              .then((c) => {
                addLine(`[connect] Refreshed controllers: ${c.length}`);
                setControllers(c);
              })
              .catch((e: any) =>
                addLine(`[error] getControllers on connect: ${e.message}`)
              );
          } catch (e: any) {
            addLine(`[error] getControllers on connect: ${e.message}`);
          }
        }),
        GameController.onControllerDisconnected((id) => {
          addLine(`[disconnect] ${id}`);
          try {
            GameController.getControllers()
              .then((c) => {
                addLine(`[disconnect] Refreshed controllers: ${c.length}`);
                setControllers(c);
              })
              .catch((e: any) =>
                addLine(`[error] getControllers on disconnect: ${e.message}`)
              );
          } catch (e: any) {
            addLine(`[error] getControllers on disconnect: ${e.message}`);
          }
        }),
        GameController.onControllerCurrentChange((id) => {
          addLine(`[current] ${id}`);
        }),
        GameController.onControllerButton((e) => {
          addLine(
            `[btn] ${e.controllerId.slice(0, 8)} buttons=0x${(
              e.buttons >>> 0
            ).toString(16)}`
          );
        }),
        GameController.onKeyboardEvent((e) => {
          addLine(`[key] code=${e.keyCode} ${e.pressed ? 'down' : 'up'}`);
        }),
        GameController.onMouseButton((e) => {
          addLine(`[mouse-btn] ${e.button} ${e.pressed ? 'down' : 'up'}`);
        }),
        GameController.onMouseMoveEvent((e) => {
          addLine(`[mouse-move] dx=${e.deltaX} dy=${e.deltaY}`);
        }),
        GameController.onKeyboardConnected(() => {
          addLine('[keyboard] connected');
        }),
        GameController.onKeyboardDisconnected(() => {
          addLine('[keyboard] disconnected');
        }),
        GameController.onMouseConnected(() => {
          addLine('[mouse] connected');
        }),
        GameController.onMouseDisconnected(() => {
          addLine('[mouse] disconnected');
        }),
      ];
      addLine('[events] Subscribed to 11 EventEmitters');
      return () => {
        addLine('[events] Unsubscribing from EventEmitters');
        subs.forEach((s) => s.remove());
      };
    } catch (e: any) {
      addLine(`[error] Subscribing to events: ${e.message}`);
    }
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Game Controller Example</Text>

      <View style={styles.toggles}>
        <ToggleButton
          label='ControllerButton'
          onToggle={(v) => GameController.toggleControllerButtonEvents(v)}
        />
        <ToggleButton
          label='ControllerCurrent'
          onToggle={(v) => GameController.toggleControllerCurrentEvents(v)}
        />
        <ToggleButton
          label='Keyboard'
          onToggle={(v) => GameController.toggleKeyboardEvents(v)}
        />
        <ToggleButton
          label='MouseButton'
          onToggle={(v) => GameController.toggleMouseButtonEvents(v)}
        />
        <ToggleButton
          label='MouseMove'
          onToggle={(v) => GameController.toggleMouseMoveEvents(v)}
        />
        <MouseDeltaPolling />
      </View>

      <Pressable
        style={styles.btn}
        onPress={() => {
          const next = !polling;
          addLine(`[polling] ${next ? 'ON' : 'OFF'}`);
          setPolling(next);
        }}
      >
        <Text style={styles.btnText}>Polling: {polling ? 'ON' : 'OFF'}</Text>
      </Pressable>

      {controllers.map((c) => (
        <ControllerStatus
          key={c.controllerId}
          controllerId={c.controllerId}
          pollingEnabled={polling}
        />
      ))}

      <View style={styles.logContainer}>
        <LogBox />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16, backgroundColor: '#1e1e1e' },
  title: { fontSize: 18, color: '#fff', marginBottom: 12 },
  toggles: { marginBottom: 12 },
  toggleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 4 },
  toggleLabel: { color: '#ccc', fontSize: 12, width: 160 },
  btn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#333',
    borderRadius: 4,
  },
  btnOn: { backgroundColor: '#264' },
  btnText: { color: '#fff', fontSize: 11 },
  logContainer: { flex: 1, marginTop: 12 },
});

export default App;
