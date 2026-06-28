import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import GameController from 'react-native-apple-game-controller';
import type { ControllerInfo } from 'react-native-apple-game-controller';
import { addLine } from './log_store';
import { ToggleButton } from './components/toggle_button';
import { ControllerStatus } from './components/controller_status';
import { LogBox } from './components/log_box';
import { MouseTest } from './mouse_test';
import { KeyboardTest } from './keyboard_test';

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

  useEffect(() => {
    addLine('[events] Subscribing to all EventEmitters...');
    try {
      const subs = [
        GameController.onControllerConnected((id) => {
          addLine(`[connect] ${id}`);
          GameController.getControllers()
            .then((c) => {
              addLine(`[connect] Refreshed controllers: ${c.length}`);
              setControllers(c);
            })
            .catch((e: any) =>
              addLine(`[error] getControllers on connect: ${e.message}`)
            );
        }),
        GameController.onControllerDisconnected((id) => {
          addLine(`[disconnect] ${id}`);
          GameController.getControllers()
            .then((c) => {
              addLine(`[disconnect] Refreshed controllers: ${c.length}`);
              setControllers(c);
            })
            .catch((e: any) =>
              addLine(`[error] getControllers on disconnect: ${e.message}`)
            );
        }),
        GameController.onControllerCurrentChange((id) => {
          addLine(`[current] ${id}`);
        }),
        GameController.onControllerButton((e) => {
          addLine(
            `[btn] ${e.controllerId.slice(0, 8)} buttons=0x${(e.buttons >>> 0).toString(16)}`
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
        <View style={styles.toggleColumns}>
          <View style={styles.toggleColumn}>
            <ToggleButton
              label='ControllerButton'
              onToggle={(v) => GameController.toggleControllerButtonEvents(v)}
            />
            <ToggleButton
              label='ControllerCurrent'
              onToggle={(v) => GameController.toggleControllerCurrentEvents(v)}
            />
            <KeyboardTest />
          </View>
          <View style={styles.toggleColumn}>
            <MouseTest />
          </View>
        </View>
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
  toggleColumns: { flexDirection: 'row', gap: 16 },
  toggleColumn: { flex: 1 },
  btn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#333',
    borderRadius: 4,
  },
  btnText: { color: '#fff', fontSize: 11 },
  logContainer: { flex: 1, marginTop: 12 },
});

export default App;
