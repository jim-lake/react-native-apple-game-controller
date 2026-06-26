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
  GCKeyboard *keyboard = GCKeyboard.coalescedKeyboard;
  if (!keyboard) {
    return;
  }

  keyboard.keyboardInput.keyChangedHandler = ^(
      GCKeyboardInput *input, GCControllerButtonInput *key, GCKeyCode keyCode,
      BOOL pressed) {
    if (!self.module) {
      return;
    }

    if (self->_callback) {
      auto cb = self->_callback;
      double kc = (double)keyCode;
      bool p = (bool)pressed;
      self.module->jsInvoker_->invokeAsync(
          [cb, kc, p](facebook::jsi::Runtime &rt) { cb->call(rt, kc, p); });
    }

    if (self.eventsEnabled) {
      facebook::react::KeyboardEventStruct evt{(double)keyCode, (bool)pressed};
      self.module->emitOnKeyboardEvent(evt);
    }
  };

  _connectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCKeyboardDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
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

- (void)stop {
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

- (void)setCallback:(std::optional<facebook::jsi::Function>)callback {
  if (callback.has_value()) {
    _callback = std::make_shared<facebook::jsi::Function>(std::move(*callback));
  } else {
    _callback = nullptr;
  }
}

@end
