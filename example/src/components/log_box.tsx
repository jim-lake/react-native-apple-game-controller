import React from 'react';
import { View, Text, FlatList, StyleSheet, Pressable } from 'react-native';
import {
  useLogLines,
  useLogPaused,
  clearLog,
  pauseLog,
  resumeLog,
} from '../log_store';

export function LogBox() {
  const lines = useLogLines();
  const paused = useLogPaused();

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>Log{paused ? ' (paused)' : ''}</Text>
        <View style={styles.headerButtons}>
          <Pressable onPress={paused ? resumeLog : pauseLog}>
            <Text style={styles.btn}>{paused ? 'Resume' : 'Pause'}</Text>
          </Pressable>
          <Pressable onPress={clearLog}>
            <Text style={styles.btn}>Clear</Text>
          </Pressable>
        </View>
      </View>
      <FlatList
        contentContainerStyle={styles.listContainer}
        data={lines}
        keyExtractor={(_, i) => String(i)}
        renderItem={({ item }) => <Text style={styles.line}>{item}</Text>}
        style={styles.list}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#555',
    borderRadius: 4,
    flexDirection: 'column',
    alignSelf: 'stretch',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 4,
    borderBottomWidth: 1,
    borderBottomColor: '#555',
  },
  headerText: { color: '#aaa', fontSize: 12 },
  headerButtons: { flexDirection: 'row', gap: 8 },
  btn: { color: '#6af', fontSize: 12 },
  list: { flex: 1, padding: 4, transform: [{ scaleY: -1 }] },
  listContainer: { flexDirection: 'column', paddingTop: 20 },
  line: {
    fontSize: 10,
    color: '#ccc',
    fontFamily: 'Menlo',
    transform: [{ scaleY: -1 }],
  },
});
