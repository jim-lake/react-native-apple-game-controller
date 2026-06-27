import { useSyncExternalStore } from 'react';

const g_consoleEnabled = false;
let g_lines: string[] = [];
let g_paused = false;
let g_pendingLines: string[] = [];
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

function _getPausedSnapshot() {
  return g_paused;
}

export function addLine(line: string) {
  if (g_consoleEnabled) {
    console.log(line);
  }
  if (g_paused) {
    g_pendingLines.push(line);
    return;
  }
  g_lines = [line, ...g_lines];
  _notify();
}

export function clearLog() {
  g_lines = [];
  g_pendingLines = [];
  _notify();
}

export function pauseLog() {
  g_paused = true;
  _notify();
}

export function resumeLog() {
  g_paused = false;
  if (g_pendingLines.length > 0) {
    g_lines = [...g_pendingLines.reverse(), ...g_lines];
    g_pendingLines = [];
  }
  _notify();
}

export function useLogLines(): readonly string[] {
  return useSyncExternalStore(_subscribe, _getSnapshot, _getSnapshot);
}

export function useLogPaused(): boolean {
  return useSyncExternalStore(
    _subscribe,
    _getPausedSnapshot,
    _getPausedSnapshot
  );
}
