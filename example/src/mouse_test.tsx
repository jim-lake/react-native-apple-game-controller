import React, { useEffect, useState } from 'react';
import { View } from 'react-native';
import GameController from 'react-native-apple-game-controller';
import { addLine } from './log_store';
import { ToggleButton } from './components/toggle_button';
import { startReportingRAF, cancelReportingRAF } from './tools/reporting_raf';

const g_mouseBuffer = new Int32Array(2);

function fpsReporter(fps: number) {
  addLine(`[mouse-delta]: fps: ${fps}`);
}

function MouseDeltaPolling() {
  const [enabled, setEnabled] = useState(false);

  useEffect(() => {
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
    <ToggleButton label='Mouse Move Polling' onToggle={(v) => setEnabled(v)} />
  );
}

export function MouseTest() {
  return (
    <View>
      <ToggleButton
        label='MouseButton Events'
        onToggle={(v) => GameController.toggleMouseButtonEvents(v)}
      />
      <ToggleButton
        label='MouseMove Events'
        onToggle={(v) => GameController.toggleMouseMoveEvents(v)}
      />
      <ToggleButton
        label='Mouse Button Callback'
        onToggle={(v) => {
          if (v) {
            GameController.registerMouseButtonEventCallback(
              (button, pressed) => {
                addLine(`[mouse-btn-cb] ${button} ${pressed ? 'down' : 'up'}`);
              }
            );
          } else {
            GameController.registerMouseButtonEventCallback(null);
          }
        }}
      />
      <ToggleButton
        label='Mouse Move Callback'
        onToggle={(v) => {
          if (v) {
            GameController.registerMouseMoveEventCallback((deltaX, deltaY) => {
              addLine(`[mouse-move-cb] dx=${deltaX} dy=${deltaY}`);
            });
          } else {
            GameController.registerMouseMoveEventCallback(null);
          }
        }}
      />
      <MouseDeltaPolling />
    </View>
  );
}
