import React, { useRef, useEffect } from 'react';
import { View, Text, ScrollView, StyleSheet, Pressable } from 'react-native';
import { useLogLines, clearLog } from '../log_store';

export function LogBox() {
  const lines = useLogLines();
  const scrollRef = useRef<ScrollView>(null);

  useEffect(() => {
    scrollRef.current?.scrollToEnd({ animated: false });
  }, [lines.length]);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>Log</Text>
        <Pressable onPress={clearLog}>
          <Text style={styles.clearBtn}>Clear</Text>
        </Pressable>
      </View>
      <ScrollView ref={scrollRef} style={styles.scroll}>
        {lines.map((line, i) => (
          <Text key={i} style={styles.line}>
            {line}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, borderWidth: 1, borderColor: '#555', borderRadius: 4 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 4,
    borderBottomWidth: 1,
    borderBottomColor: '#555',
  },
  headerText: { color: '#aaa', fontSize: 12 },
  clearBtn: { color: '#6af', fontSize: 12 },
  scroll: { flex: 1, padding: 4 },
  line: { fontSize: 10, color: '#ccc', fontFamily: 'Menlo' },
});
