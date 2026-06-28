#import "RNGameControllerHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

// MARK: - Storage

static NSMutableArray<NSValue *> *sControllerEntries = nil;
static NSMutableDictionary<NSString *, NSValue *> *sUuidToController = nil;
static NSMapTable<GCController *, NSString *> *sControllerToUuid = nil;
static id sConnectObserver = nil;
static id sDisconnectObserver = nil;
static id sCurrentObserver = nil;
static id sStopCurrentObserver = nil;

// MARK: - Profile Assignment

static void assignProfile(ControllerEntry *entry, GCController *controller) {
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
      auto *helper = [RNGameControllerHelper shared];
      if (helper.module) {
        if (helper->_eventCallback) {
          auto cb = helper->_eventCallback;
          auto invoker = helper.module->jsInvoker_;
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
        if (helper.module->buttonEventsEnabled_) {
          facebook::react::ControllerButtonEventStruct evt{
              cid, (double)bval, CACurrentMediaTime()};
          helper.module->emitOnControllerButton(evt);
        }
      }
    }
  };
}

// MARK: - Controller Lifecycle

static void controllerConnected(GCController *controller) {
  NSString *uuid = [[NSUUID UUID] UUIDString];
  std::string cid = [uuid UTF8String];

  auto *entry = new ControllerEntry();
  entry->controllerId = cid;
  entry->controller = controller;
  assignProfile(entry, controller);

  if (!sControllerEntries) {
    sControllerEntries = [NSMutableArray array];
    sUuidToController = [NSMutableDictionary dictionary];
    sControllerToUuid = [NSMapTable strongToStrongObjectsMapTable];
  }

  [sControllerEntries addObject:[NSValue valueWithPointer:entry]];
  sUuidToController[uuid] =
      [NSValue valueWithPointer:(__bridge void *)controller];
  [sControllerToUuid setObject:uuid forKey:controller];

  auto *helper = [RNGameControllerHelper shared];
  if (helper.module) {
    helper.module->emitOnControllerConnected(cid);
  }
}

static void controllerDisconnected(GCController *controller) {
  NSString *uuid = [sControllerToUuid objectForKey:controller];
  if (!uuid) {
    return;
  }

  std::string cid = [uuid UTF8String];

  for (NSInteger i = 0; i < (NSInteger)sControllerEntries.count; i++) {
    auto *e = (ControllerEntry *)sControllerEntries[i].pointerValue;
    if (e->controllerId == cid) {
      delete e;
      [sControllerEntries removeObjectAtIndex:i];
      break;
    }
  }

  [sUuidToController removeObjectForKey:uuid];
  [sControllerToUuid removeObjectForKey:controller];

  auto *helper = [RNGameControllerHelper shared];
  if (helper.module) {
    helper.module->emitOnControllerDisconnected(cid);
  }
}

void setupNotifications() {
  if (sConnectObserver) {
    return;
  }
  if (!sControllerEntries) {
    sControllerEntries = [NSMutableArray array];
    sUuidToController = [NSMutableDictionary dictionary];
    sControllerToUuid = [NSMapTable strongToStrongObjectsMapTable];
  }

  sConnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                controllerConnected((GCController *)note.object);
              }];
  sDisconnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidDisconnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                controllerDisconnected((GCController *)note.object);
              }];

  for (GCController *c in [GCController controllers]) {
    controllerConnected(c);
  }
}

void toggleCurrentNotifications(bool enable) {
  if (enable && !sCurrentObserver) {
    sCurrentObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GCControllerDidBecomeCurrentNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                  GCController *controller = note.object;
                  NSString *uuid = [sControllerToUuid objectForKey:controller];
                  if (!uuid) {
                    return;
                  }
                  auto *helper = [RNGameControllerHelper shared];
                  if (helper.module) {
                    helper.module->emitOnControllerCurrentChange(
                        std::string([uuid UTF8String]));
                  }
                }];
    sStopCurrentObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GCControllerDidStopBeingCurrentNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note){
                    // The "become current" notification on the new controller
                    // handles emitting the change; nothing needed here.
                }];
  } else if (!enable && sCurrentObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:sCurrentObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:sStopCurrentObserver];
    sCurrentObserver = nil;
    sStopCurrentObserver = nil;
  }
}

// MARK: - RNGameControllerHelper

@implementation RNGameControllerHelper

+ (instancetype)shared {
  static RNGameControllerHelper *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[RNGameControllerHelper alloc] init];
  });
  return instance;
}

- (ControllerEntry *)findEntryById:(const std::string &)controllerId {
  NSString *uuid = [NSString stringWithUTF8String:controllerId.c_str()];
  NSValue *v = sUuidToController[uuid];
  if (!v) {
    return nullptr;
  }
  GCController *controller = (__bridge GCController *)v.pointerValue;
  for (NSValue *ev in sControllerEntries) {
    auto *e = (ControllerEntry *)ev.pointerValue;
    if (e->controller == controller) {
      return e;
    }
  }
  return nullptr;
}

- (NSArray<NSValue *> *)entries {
  return sControllerEntries ?: @[];
}

- (void)setEventCallback:(std::shared_ptr<facebook::jsi::Function>)callback {
  _eventCallback = std::move(callback);
}

- (std::shared_ptr<facebook::jsi::Function>)clearEventCallback {
  return std::move(_eventCallback);
}

@end
