import { useSyncExternalStore } from 'react';

const g_consoleEnabled = false;
let g_lines: string[] = [];
const g_listeners = new Set<() => void>();

function _notify() {
  for (const listener of g_listeners) {
    listener();
  }
}

function _subscribe(listener: () => void) {
  g_listeners.add(listener);
  return () => g_listeners.delete(listener);
}

function _getSnapshot() {
  return g_lines;
}

export function addLine(line: string) {
  if (g_consoleEnabled) {
    console.log(line);
  }
  g_lines = [line, ...g_lines];
  _notify();
}

export function clearLog() {
  g_lines = [];
  _notify();
}

export function useLogLines(): readonly string[] {
  return useSyncExternalStore(_subscribe, _getSnapshot, _getSnapshot);
}
