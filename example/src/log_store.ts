import { useSyncExternalStore } from 'react';

let lines: string[] = [];
const listeners = new Set<() => void>();

function _notify() {
  for (const listener of listeners) {
    listener();
  }
}

function _subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function _getSnapshot() {
  return lines;
}

export function addLine(line: string) {
  console.log(line);
  lines = [...lines, line];
  _notify();
}

export function clearLog() {
  lines = [];
  _notify();
}

export function useLogLines(): readonly string[] {
  return useSyncExternalStore(_subscribe, _getSnapshot, _getSnapshot);
}
