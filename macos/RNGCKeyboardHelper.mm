#import "RNGCKeyboardHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

@implementation RNGCKeyboardHelper {
  std::shared_ptr<facebook::jsi::Function> _callback;
  id _connectObserver;
  id _disconnectObserver;
}

+ (instancetype)shared {
  static RNGCKeyboardHelper *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[RNGCKeyboardHelper alloc] init];
  });
  return instance;
}

- (void)start {
  [self _attachHandler:GCKeyboard.coalescedKeyboard];

  _connectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCKeyboardDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                [self _attachHandler:GCKeyboard.coalescedKeyboard];
                if (self.module) {
                  self.module->emitOnKeyboardConnected();
                }
              }];

  _disconnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCKeyboardDidDisconnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                if (self.module) {
                  self.module->emitOnKeyboardDisconnected();
                }
              }];
}

- (void)_attachHandler:(GCKeyboard *)keyboard {
  if (!keyboard) {
    return;
  }

  keyboard.keyboardInput.keyChangedHandler =
      ^(GCKeyboardInput *input, GCControllerButtonInput *key, GCKeyCode keyCode,
        BOOL pressed) {
        if (!self.module) {
          return;
        }

        if (self->_callback) {
          auto cb = self->_callback;
          int kc = (int)keyCode;
          bool p = pressed;
          self.module->jsInvoker_->invokeAsync(
              [cb, kc, p](facebook::jsi::Runtime &rt) { cb->call(rt, kc, p); });
        }

        if (self.eventsEnabled) {
          facebook::react::KeyboardEventStruct evt{(int)keyCode, pressed};
          self.module->emitOnKeyboardEvent(evt);
        }
      };
}

- (void)stop {
  // FIRST: Disable all event emitters and clear callbacks so no emits can fire
  // during teardown. The module/runtime may be gone after this point.
  self.eventsEnabled = false;
  self.module = nullptr;
  _callback.reset();

  GCKeyboard *keyboard = GCKeyboard.coalescedKeyboard;
  if (keyboard) {
    keyboard.keyboardInput.keyChangedHandler = nil;
  }
  if (_connectObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_connectObserver];
    _connectObserver = nil;
  }
  if (_disconnectObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_disconnectObserver];
    _disconnectObserver = nil;
  }
}

- (void)setCallback:(std::shared_ptr<facebook::jsi::Function>)callback {
  _callback = std::move(callback);
}

- (std::shared_ptr<facebook::jsi::Function>)clearCallback {
  return std::move(_callback);
}

@end
