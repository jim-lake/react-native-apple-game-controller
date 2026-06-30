#import "RNGCMouseHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

std::atomic<int32_t> g_mouseDeltaX{0};
std::atomic<int32_t> g_mouseDeltaY{0};
static std::atomic<int32_t> g_mouseCallbackDeltaX{0};
static std::atomic<int32_t> g_mouseCallbackDeltaY{0};

@implementation RNGCMouseHelper {
  std::shared_ptr<facebook::jsi::Function> _buttonCallback;
  std::shared_ptr<facebook::jsi::Function> _moveCallback;
  id _connectObserver;
  id _disconnectObserver;
  NSHashTable<GCMouse *> *_attachedMice;
}

+ (instancetype)shared {
  static RNGCMouseHelper *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[RNGCMouseHelper alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _attachedMice = [NSHashTable weakObjectsHashTable];
  }
  return self;
}

- (void)start {
  // Attach to all currently connected mice
  for (GCMouse *mouse in GCMouse.mice) {
    [self _attachHandlers:mouse];
  }

  _connectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCMouseDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                GCMouse *mouse = note.object;
                [self _attachHandlers:mouse];
                if (self.module) {
                  self.module->emitOnMouseConnected();
                }
              }];

  _disconnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCMouseDidDisconnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                GCMouse *mouse = note.object;
                [self _detachHandlers:mouse];
                if (self.module) {
                  self.module->emitOnMouseDisconnected();
                }
              }];
}

- (void)_attachHandlers:(GCMouse *)mouse {
  if (!mouse || [_attachedMice containsObject:mouse]) {
    return;
  }
  [_attachedMice addObject:mouse];

  GCMouseInput *input = mouse.mouseInput;

  input.mouseMovedHandler = ^(GCMouseInput *mouseInput, float deltaX,
                              float deltaY) {
    if (!self.module) {
      return;
    }

    int32_t dx = (int32_t)deltaX;
    int32_t dy = (int32_t)deltaY;

    if (self.deltaCollectEnabled) {
      g_mouseDeltaX.fetch_add(dx, std::memory_order_relaxed);
      g_mouseDeltaY.fetch_add(dy, std::memory_order_relaxed);
    }

    if (self->_moveCallback) {
      g_mouseCallbackDeltaX.fetch_add(dx, std::memory_order_relaxed);
      g_mouseCallbackDeltaY.fetch_add(dy, std::memory_order_relaxed);
      auto cb = self->_moveCallback;
      self.module->jsInvoker_->invokeAsync([cb](facebook::jsi::Runtime &rt) {
        int32_t cdx =
            g_mouseCallbackDeltaX.exchange(0, std::memory_order_relaxed);
        int32_t cdy =
            g_mouseCallbackDeltaY.exchange(0, std::memory_order_relaxed);
        if (cdx != 0 || cdy != 0) {
          cb->call(rt, cdx, cdy);
        }
      });
    }

    if (self.moveEventsEnabled) {
      facebook::react::MouseMoveEventStruct evt{dx, dy};
      self.module->emitOnMouseMoveEvent(evt);
    }
  };

  NSArray<GCControllerButtonInput *> *allButtons = input.buttons.allValues;
  for (GCControllerButtonInput *btn in allButtons) {
    btn.pressedChangedHandler =
        ^(GCControllerButtonInput *button, float value, BOOL pressed) {
          if (!self.module) {
            return;
          }

          int32_t buttonIndex = 0;
          for (NSUInteger i = 0; i < allButtons.count; i++) {
            if (allButtons[i] == button) {
              buttonIndex = (int32_t)i;
              break;
            }
          }

          bool p = pressed;

          if (self->_buttonCallback) {
            auto cb = self->_buttonCallback;
            self.module->jsInvoker_->invokeAsync(
                [cb, buttonIndex, p](facebook::jsi::Runtime &rt) {
                  cb->call(rt, buttonIndex, p);
                });
          }

          if (self.buttonEventsEnabled) {
            facebook::react::MouseButtonEventStruct evt{buttonIndex, p};
            self.module->emitOnMouseButton(evt);
          }
        };
  }
}

- (void)_detachHandlers:(GCMouse *)mouse {
  if (!mouse) {
    return;
  }
  [_attachedMice removeObject:mouse];
  mouse.mouseInput.mouseMovedHandler = nil;
  for (GCControllerButtonInput *btn in mouse.mouseInput.buttons.allValues) {
    btn.pressedChangedHandler = nil;
  }
}

- (void)stop {
  // FIRST: Disable all event emitters and clear callbacks so no emits can fire
  // during teardown. The module/runtime may be gone after this point.
  self.buttonEventsEnabled = false;
  self.moveEventsEnabled = false;
  self.deltaCollectEnabled = false;
  self.module = nullptr;
  _buttonCallback.reset();
  _moveCallback.reset();

  for (GCMouse *mouse in [_attachedMice allObjects]) {
    [self _detachHandlers:mouse];
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

- (void)setButtonCallback:(std::shared_ptr<facebook::jsi::Function>)callback {
  _buttonCallback = std::move(callback);
}

- (std::shared_ptr<facebook::jsi::Function>)clearButtonCallback {
  return std::move(_buttonCallback);
}

- (void)setMoveCallback:(std::shared_ptr<facebook::jsi::Function>)callback {
  _moveCallback = std::move(callback);
}

- (std::shared_ptr<facebook::jsi::Function>)clearMoveCallback {
  return std::move(_moveCallback);
}

@end
