#import "RNGameControllerHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

// MARK: - Storage

static NSMutableArray<NSValue *> *sControllerEntries = nil;
static NSMutableDictionary<NSString *, NSValue *> *sUuidToController = nil;
static NSMapTable<GCController *, NSString *> *sControllerToUuid = nil;
static id sConnectObserver = nil;
static id sDisconnectObserver = nil;

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
  for (NSValue *v in sControllerEntries) {
    auto *e = (ControllerEntry *)v.pointerValue;
    if (e->controllerId == controllerId) {
      return e;
    }
  }
  return nullptr;
}

- (ControllerEntry *)findEntryByController:(GCController *)controller {
  NSString *uuid = [sControllerToUuid objectForKey:controller];
  if (!uuid) {
    return nullptr;
  }
  std::string cid = [uuid UTF8String];
  return [self findEntryById:cid];
}

- (NSArray<NSValue *> *)entries {
  return sControllerEntries ?: @[];
}

@end
