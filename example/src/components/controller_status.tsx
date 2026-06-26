import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import GameController from 'react-native-apple-game-controller';
import type { ControllerState } from 'react-native-apple-game-controller';
import { addLine } from '../log_store';

interface Props {
  controllerId: string;
  pollingEnabled: boolean;
}

export function ControllerStatus({ controllerId, pollingEnabled }: Props) {
  const [state, setState] = useState<ControllerState | null>(null);
  const rafRef = useRef<number>(0);

  useEffect(() => {
    if (!pollingEnabled) {
      addLine(`[poll] Stopped for ${controllerId.slice(0, 8)}`);
      return;
    }
    addLine(`[poll] Started for ${controllerId.slice(0, 8)}`);
    let active = true;
    const poll = () => {
      if (!active) return;
      try {
        setState(GameController.getControllerState(controllerId));
      } catch (e: any) {
        addLine(`[error] getControllerState: ${e.message}`);
      }
      rafRef.current = requestAnimationFrame(poll);
    };
    rafRef.current = requestAnimationFrame(poll);
    return () => {
      active = false;
      cancelAnimationFrame(rafRef.current);
    };
  }, [controllerId, pollingEnabled]);

  if (!state) {
    return (
      <View style={styles.container}>
        <Text style={styles.label}>Controller: {controllerId}</Text>
        <Text style={styles.text}>No state</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Controller: {controllerId.slice(0, 8)}…</Text>
      <Text style={styles.text}>
        Buttons: 0b{(state.buttons >>> 0).toString(2).padStart(16, '0')}
      </Text>
      <Text style={styles.text}>
        Analog: [{state.analog.map(v => v.toFixed(2)).join(', ')}]
      </Text>
      <Text style={styles.text}>
        Updated: {state.lastUpdated.toFixed(3)}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 8, borderWidth: 1, borderColor: '#555', marginBottom: 8, borderRadius: 4 },
  label: { fontSize: 12, color: '#aaa', marginBottom: 4 },
  text: { fontSize: 11, color: '#ccc', fontFamily: 'Menlo' },
});
