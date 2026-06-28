import React from 'react';
import GameController from 'react-native-apple-game-controller';
import { addLine } from './log_store';
import { ToggleButton } from './components/toggle_button';

export function KeyboardTest() {
  return (
    <>
      <ToggleButton
        label='Keyboard Events'
        onToggle={(v) => GameController.toggleKeyboardEvents(v)}
      />
      <ToggleButton
        label='Keyboard Callback'
        onToggle={(v) => {
          if (v) {
            GameController.registerKeyboardEventCallback((keyCode, pressed) => {
              addLine(`[key-cb] code=${keyCode} ${pressed ? 'down' : 'up'}`);
            });
          } else {
            GameController.registerKeyboardEventCallback(null);
          }
        }}
      />
    </>
  );
}
