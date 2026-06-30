import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import GameController from 'react-native-apple-game-controller';
import type { EnrichedControllerInfo } from 'react-native-apple-game-controller';
import { addLine } from './log_store';
import { ToggleButton } from './components/toggle_button';
import { ControllerStatus } from './components/controller_status';
import { LogBox } from './components/log_box';
import { MouseTest } from './mouse_test';
import { KeyboardTest } from './keyboard_test';

function App(): React.JSX.Element {
  const [controllers, setControllers] = useState<EnrichedControllerInfo[]>([]);
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
          // Log button names using the cached controller info
          const info = GameController.getControllerInfo(e.controllerId);
          if (info) {
            const mask = e.buttons;
            const pressedNames = info.buttons
              .filter((b) => (mask & (1 << b.bit)) !== 0)
              .map((b) => b.name);
            addLine(
              `[btn] ${e.controllerId} pressed: [${pressedNames.join(', ')}]`
            );
          } else {
            addLine(
              `[btn] ${e.controllerId} buttons=0x${(e.buttons >>> 0).toString(16)}`
            );
          }
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

  const handleGetControllers = async () => {
    try {
      const c = await GameController.getControllers();
      setControllers(c);
      addLine(`[get-controllers] Found ${c.length} controller(s)`);
      for (const ctrl of c) {
        addLine(`[controller] --- ID: ${ctrl.controllerId} ---`);
        addLine(`[controller]   vendorName: ${ctrl.vendorName ?? 'N/A'}`);
        addLine(
          `[controller]   productCategory: ${ctrl.productCategory ?? 'N/A'}`
        );
        addLine(`[controller]   isCurrent: ${ctrl.isCurrent}`);
        addLine(`[controller]   isAttached: ${ctrl.isAttached}`);
        addLine(`[controller]   playerIndex: ${ctrl.playerIndex}`);
        addLine(
          `[controller]   battery: ${ctrl.batteryLevel != null ? `${(ctrl.batteryLevel * 100).toFixed(0)}% (${ctrl.batteryState})` : 'N/A'}`
        );
        addLine(
          `[controller]   lightColor: ${ctrl.lightColor ? `r=${ctrl.lightColor.r} g=${ctrl.lightColor.g} b=${ctrl.lightColor.b}` : 'N/A'}`
        );
        addLine(`[controller]   buttons (${ctrl.buttons.length}):`);
        for (const b of ctrl.buttons) {
          addLine(
            `[controller]     bit ${b.bit}: "${b.name}" sf=${b.sfSymbol ?? 'none'} local="${b.localizedName ?? ''}"`
          );
        }
        addLine(`[controller]   axes (${ctrl.axes.length}):`);
        for (const a of ctrl.axes) {
          addLine(
            `[controller]     "${a.name}" analogCount=${a.analogCount} sf=${a.sfSymbol ?? 'none'}`
          );
        }
        addLine(`[controller]   dpads (${ctrl.dpads.length}):`);
        for (const d of ctrl.dpads) {
          addLine(
            `[controller]     "${d.name}" up=${d.up} down=${d.down} left=${d.left} right=${d.right}`
          );
        }
      }
    } catch (e: any) {
      addLine(`[error] getControllers: ${e.message}`);
    }
  };

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

      <View style={styles.buttonRow}>
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

        <Pressable style={styles.btn} onPress={handleGetControllers}>
          <Text style={styles.btnText}>Get Controllers</Text>
        </Pressable>
      </View>

      {controllers.map((c) => (
        <ControllerStatus
          key={c.controllerId}
          controller={c}
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
  buttonRow: { flexDirection: 'row', gap: 8, marginBottom: 8 },
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
