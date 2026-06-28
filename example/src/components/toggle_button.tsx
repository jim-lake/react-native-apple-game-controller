import React, { useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { addLine } from '../log_store';

export function ToggleButton({
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

const styles = StyleSheet.create({
  toggleRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 4 },
  toggleLabel: { color: '#ccc', fontSize: 12, width: 208 },
  btn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#333',
    borderRadius: 4,
  },
  btnOn: { backgroundColor: '#264' },
  btnText: { color: '#fff', fontSize: 11 },
});
