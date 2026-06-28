#import "RNGameControllerHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

@implementation RNGameControllerHelper {
  std::shared_ptr<facebook::jsi::Function> _eventCallback;
  NSMutableArray<NSValue *> *_controllerEntries;
  NSMutableDictionary<NSString *, NSValue *> *_uuidToController;
  NSMapTable<GCController *, NSString *> *_controllerToUuid;
  id _connectObserver;
  id _disconnectObserver;
  id _currentObserver;
  id _stopCurrentObserver;
}

+ (instancetype)shared {
  static RNGameControllerHelper *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[RNGameControllerHelper alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _controllerEntries = [NSMutableArray array];
    _uuidToController = [NSMutableDictionary dictionary];
    _controllerToUuid = [NSMapTable strongToStrongObjectsMapTable];
  }
  return self;
}

// MARK: - Profile Assignment

- (void)_assignProfile:(ControllerEntry *)entry
            controller:(GCController *)controller {
  GCExtendedGamepad *gp = controller.extendedGamepad;
  if (!gp) {
    entry->analogCount = 0;
    entry->buttonInfos = @[];
    entry->axisInfos = @[];
    entry->dpadInfos = @[];
    return;
  }

  NSMutableArray *buttons = [NSMutableArray array];
  NSMutableArray *axes = [NSMutableArray array];
  NSMutableArray *dpads = [NSMutableArray array];

  struct BtnDef {
    GCControllerButtonInput *input;
    NSString *name;
  };
  BtnDef btnDefs[] = {
      {gp.buttonA, @"Button A"},
      {gp.buttonB, @"Button B"},
      {gp.buttonX, @"Button X"},
      {gp.buttonY, @"Button Y"},
      {gp.leftShoulder, @"Left Shoulder"},
      {gp.rightShoulder, @"Right Shoulder"},
      {gp.leftThumbstickButton, @"Left Stick Button"},
      {gp.rightThumbstickButton, @"Right Stick Button"},
      {gp.buttonOptions, @"Options"},
      {gp.buttonMenu, @"Menu"},
      {gp.buttonHome, @"Home"},
  };

  int bit = 0;
  for (auto &bd : btnDefs) {
    if (bd.input) {
      NSString *sfSymbol = nil;
      NSString *locName = nil;
      if (@available(macOS 14.0, *)) {
        sfSymbol = bd.input.sfSymbolsName;
        locName = bd.input.localizedName;
      }
      [buttons addObject:@{
        @"name" : bd.name,
        @"sfSymbol" : sfSymbol ?: [NSNull null],
        @"localizedName" : locName ?: [NSNull null],
        @"bit" : @(bit)
      }];
      bit++;
    }
  }

  int dpadUpBit = bit++;
  int dpadDownBit = bit++;
  int dpadLeftBit = bit++;
  int dpadRightBit = bit++;

  [buttons addObject:@{
    @"name" : @"D-pad Up",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"bit" : @(dpadUpBit)
  }];
  [buttons addObject:@{
    @"name" : @"D-pad Down",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"bit" : @(dpadDownBit)
  }];
  [buttons addObject:@{
    @"name" : @"D-pad Left",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"bit" : @(dpadLeftBit)
  }];
  [buttons addObject:@{
    @"name" : @"D-pad Right",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"bit" : @(dpadRightBit)
  }];

  [dpads addObject:@{
    @"name" : @"Direction Pad",
    @"up" : @(dpadUpBit),
    @"down" : @(dpadDownBit),
    @"left" : @(dpadLeftBit),
    @"right" : @(dpadRightBit)
  }];

  [axes addObject:@{
    @"name" : @"Left Thumbstick",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"analogCount" : @(2)
  }];
  [axes addObject:@{
    @"name" : @"Right Thumbstick",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"analogCount" : @(2)
  }];
  [axes addObject:@{
    @"name" : @"Left Trigger",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"analogCount" : @(1)
  }];
  [axes addObject:@{
    @"name" : @"Right Trigger",
    @"sfSymbol" : [NSNull null],
    @"localizedName" : [NSNull null],
    @"analogCount" : @(1)
  }];

  entry->analogCount = kMaxAnalog;
  for (int i = 0; i < kMaxAnalog; i++) {
    entry->state.analog[i].store(0.0f);
  }
  entry->buttonInfos = buttons;
  entry->axisInfos = axes;
  entry->dpadInfos = dpads;

  // Value changed handler
  std::string cid = entry->controllerId;
  ControllerState *cs = &entry->state;

  gp.valueChangedHandler = ^(GCExtendedGamepad *gamepad,
                             GCControllerElement *element) {
    cs->analog[0].store(gamepad.leftThumbstick.xAxis.value);
    cs->analog[1].store(gamepad.leftThumbstick.yAxis.value);
    cs->analog[2].store(gamepad.rightThumbstick.xAxis.value);
    cs->analog[3].store(gamepad.rightThumbstick.yAxis.value);
    cs->analog[4].store(gamepad.leftTrigger.value);
    cs->analog[5].store(gamepad.rightTrigger.value);

    uint32_t bval = 0;
    int b = 0;
    if (gamepad.buttonA && gamepad.buttonA.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonA) {
      b++;
    }
    if (gamepad.buttonB && gamepad.buttonB.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonB) {
      b++;
    }
    if (gamepad.buttonX && gamepad.buttonX.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonX) {
      b++;
    }
    if (gamepad.buttonY && gamepad.buttonY.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonY) {
      b++;
    }
    if (gamepad.leftShoulder && gamepad.leftShoulder.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.leftShoulder) {
      b++;
    }
    if (gamepad.rightShoulder && gamepad.rightShoulder.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.rightShoulder) {
      b++;
    }
    if (gamepad.leftThumbstickButton && gamepad.leftThumbstickButton.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.leftThumbstickButton) {
      b++;
    }
    if (gamepad.rightThumbstickButton &&
        gamepad.rightThumbstickButton.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.rightThumbstickButton) {
      b++;
    }
    if (gamepad.buttonOptions && gamepad.buttonOptions.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonOptions) {
      b++;
    }
    if (gamepad.buttonMenu && gamepad.buttonMenu.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonMenu) {
      b++;
    }
    if (gamepad.buttonHome && gamepad.buttonHome.pressed) {
      bval |= (1u << b);
    }
    if (gamepad.buttonHome) {
      b++;
    }

    if (gamepad.dpad.up.pressed) {
      bval |= (1u << dpadUpBit);
    }
    if (gamepad.dpad.down.pressed) {
      bval |= (1u << dpadDownBit);
    }
    if (gamepad.dpad.left.pressed) {
      bval |= (1u << dpadLeftBit);
    }
    if (gamepad.dpad.right.pressed) {
      bval |= (1u << dpadRightBit);
    }

    uint32_t prev = cs->buttons.exchange(bval);
    cs->lastUpdated.store(CACurrentMediaTime());
    if (prev != bval) {
      if (self.module) {
        if (self->_eventCallback) {
          auto cb = self->_eventCallback;
          auto invoker = self.module->jsInvoker_;
          invoker->invokeAsync([cb, cs, cid](facebook::jsi::Runtime &rt) {
            uint32_t b = cs->buttons.load(std::memory_order_relaxed);
            uint32_t lastCb =
                cs->lastCallbackButtons.exchange(b, std::memory_order_relaxed);
            if (b != lastCb) {
              double ts = cs->lastUpdated.load(std::memory_order_relaxed);
              cb->call(rt, facebook::jsi::String::createFromUtf8(rt, cid),
                       static_cast<int>(b), ts);
            }
          });
        }
        if (self.buttonEventsEnabled) {
          facebook::react::ControllerButtonEventStruct evt{
              cid, (double)bval, CACurrentMediaTime()};
          self.module->emitOnControllerButton(evt);
        }
      }
    }
  };
}

// MARK: - Lifecycle

- (void)start {
  for (GCController *c in [GCController controllers]) {
    [self _controllerConnected:c];
  }

  _connectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                [self _controllerConnected:(GCController *)note.object];
              }];
  _disconnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidDisconnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                [self _controllerDisconnected:(GCController *)note.object];
              }];
}

- (void)stop {
  for (NSValue *v in [_controllerEntries copy]) {
    auto *e = (ControllerEntry *)v.pointerValue;
    [self _controllerDisconnected:e->controller];
  }
  if (_connectObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_connectObserver];
    _connectObserver = nil;
  }
  if (_disconnectObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_disconnectObserver];
    _disconnectObserver = nil;
  }
  [self toggleCurrentEvents:false];
}

- (void)toggleCurrentEvents:(bool)enable {
  if (enable && !_currentObserver) {
    _currentObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GCControllerDidBecomeCurrentNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                  GCController *controller = note.object;
                  NSString *uuid =
                      [self->_controllerToUuid objectForKey:controller];
                  if (!uuid) {
                    return;
                  }
                  if (self.module) {
                    self.module->emitOnControllerCurrentChange(
                        std::string([uuid UTF8String]));
                  }
                }];
    _stopCurrentObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GCControllerDidStopBeingCurrentNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note){
                }];
  } else if (!enable && _currentObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_currentObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_stopCurrentObserver];
    _currentObserver = nil;
    _stopCurrentObserver = nil;
  }
}

- (void)_controllerConnected:(GCController *)controller {
  NSString *uuid = [[NSUUID UUID] UUIDString];
  std::string cid = [uuid UTF8String];

  auto *entry = new ControllerEntry();
  entry->controllerId = cid;
  entry->controller = controller;
  [self _assignProfile:entry controller:controller];

  [_controllerEntries addObject:[NSValue valueWithPointer:entry]];
  _uuidToController[uuid] =
      [NSValue valueWithPointer:(__bridge void *)controller];
  [_controllerToUuid setObject:uuid forKey:controller];

  if (self.module) {
    self.module->emitOnControllerConnected(cid);
  }
}

- (void)_controllerDisconnected:(GCController *)controller {
  NSString *uuid = [_controllerToUuid objectForKey:controller];
  if (!uuid) {
    return;
  }

  std::string cid = [uuid UTF8String];

  for (NSInteger i = 0; i < (NSInteger)_controllerEntries.count; i++) {
    auto *e = (ControllerEntry *)_controllerEntries[i].pointerValue;
    if (e->controllerId == cid) {
      if (e->controller.extendedGamepad) {
        e->controller.extendedGamepad.valueChangedHandler = nil;
      }
      delete e;
      [_controllerEntries removeObjectAtIndex:i];
      break;
    }
  }

  [_uuidToController removeObjectForKey:uuid];
  [_controllerToUuid removeObjectForKey:controller];

  if (self.module) {
    self.module->emitOnControllerDisconnected(cid);
  }
}

// MARK: - Queries

- (ControllerEntry *)findEntryById:(const std::string &)controllerId {
  NSString *uuid = [NSString stringWithUTF8String:controllerId.c_str()];
  NSValue *v = _uuidToController[uuid];
  if (!v) {
    return nullptr;
  }
  GCController *controller = (__bridge GCController *)v.pointerValue;
  for (NSValue *ev in _controllerEntries) {
    auto *e = (ControllerEntry *)ev.pointerValue;
    if (e->controller == controller) {
      return e;
    }
  }
  return nullptr;
}

- (NSArray<NSValue *> *)entries {
  return _controllerEntries;
}

// MARK: - Callback

- (void)setEventCallback:(std::shared_ptr<facebook::jsi::Function>)callback {
  _eventCallback = std::move(callback);
}

- (std::shared_ptr<facebook::jsi::Function>)clearEventCallback {
  return std::move(_eventCallback);
}

@end
