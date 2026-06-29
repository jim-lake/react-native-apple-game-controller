#import "RNGameControllerHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

@implementation RNGameControllerHelper {
  std::shared_ptr<facebook::jsi::Function> _eventCallback;
  std::unordered_map<int, ControllerEntry *> _entries;
  NSMapTable<GCController *, NSNumber *> *_controllerToId;
  id _connectObserver;
  id _disconnectObserver;
  id _currentObserver;
  id _stopCurrentObserver;
  int _nextControllerId;
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
    _controllerToId = [NSMapTable strongToStrongObjectsMapTable];
    _nextControllerId = 1;
  }
  return self;
}

// MARK: - Profile Assignment

- (void)_assignProfile:(ControllerEntry *)entry
            controller:(GCController *)controller {
  GCPhysicalInputProfile *profile = controller.physicalInputProfile;
  if (!profile) {
    entry->analogCount = 0;
    entry->buttonInfos = @[];
    entry->axisInfos = @[];
    entry->dpadInfos = @[];
    return;
  }

  NSMutableArray *buttons = [NSMutableArray array];
  NSMutableArray *axes = [NSMutableArray array];
  NSMutableArray *dpads = [NSMutableArray array];

  // Discover all buttons dynamically from the physical input profile.
  // Sort keys for deterministic bit assignment across launches.
  NSArray<NSString *> *buttonNames =
      [[profile.buttons allKeys] sortedArrayUsingSelector:@selector(compare:)];

  // Collect which button names are part of dpads so we can tag them
  NSMutableSet<NSString *> *dpadButtonNames = [NSMutableSet set];
  NSArray<NSString *> *dpadNames =
      [[profile.dpads allKeys] sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *dpadName in dpadNames) {
    GCControllerDirectionPad *dpad = profile.dpads[dpadName];
    // Each dpad direction is also in profile.buttons; track them
    for (NSString *bName in buttonNames) {
      GCControllerButtonInput *btn = profile.buttons[bName];
      if (btn == dpad.up || btn == dpad.down || btn == dpad.left ||
          btn == dpad.right) {
        [dpadButtonNames addObject:bName];
      }
    }
  }

  // Assign bits to all non-dpad buttons first
  int bit = 0;
  NSMutableArray<NSString *> *orderedButtonKeys = [NSMutableArray array];
  for (NSString *name in buttonNames) {
    if ([dpadButtonNames containsObject:name]) {
      continue;
    }
    GCControllerButtonInput *btn = profile.buttons[name];
    if (!btn) {
      continue;
    }

    NSString *sfSymbol = nil;
    NSString *locName = nil;
    if (@available(macOS 14.0, *)) {
      sfSymbol = btn.sfSymbolsName;
      locName = btn.localizedName;
    }
    [buttons addObject:@{
      @"name" : name,
      @"sfSymbol" : sfSymbol ?: [NSNull null],
      @"localizedName" : locName ?: [NSNull null],
      @"bit" : @(bit)
    }];
    [orderedButtonKeys addObject:name];
    bit++;
  }

  // Assign bits for dpad directions and build dpad info
  NSMutableArray<NSString *> *orderedDpadKeys = [NSMutableArray array];
  for (NSString *dpadName in dpadNames) {
    GCControllerDirectionPad *dpad = profile.dpads[dpadName];
    if (!dpad) {
      continue;
    }

    int upBit = bit++;
    int downBit = bit++;
    int leftBit = bit++;
    int rightBit = bit++;

    [buttons addObject:@{
      @"name" : [NSString stringWithFormat:@"%@ Up", dpadName],
      @"sfSymbol" : [NSNull null],
      @"localizedName" : [NSNull null],
      @"bit" : @(upBit)
    }];
    [buttons addObject:@{
      @"name" : [NSString stringWithFormat:@"%@ Down", dpadName],
      @"sfSymbol" : [NSNull null],
      @"localizedName" : [NSNull null],
      @"bit" : @(downBit)
    }];
    [buttons addObject:@{
      @"name" : [NSString stringWithFormat:@"%@ Left", dpadName],
      @"sfSymbol" : [NSNull null],
      @"localizedName" : [NSNull null],
      @"bit" : @(leftBit)
    }];
    [buttons addObject:@{
      @"name" : [NSString stringWithFormat:@"%@ Right", dpadName],
      @"sfSymbol" : [NSNull null],
      @"localizedName" : [NSNull null],
      @"bit" : @(rightBit)
    }];

    [dpads addObject:@{
      @"name" : dpadName,
      @"up" : @(upBit),
      @"down" : @(downBit),
      @"left" : @(leftBit),
      @"right" : @(rightBit)
    }];
    [orderedDpadKeys addObject:dpadName];
  }

  // Discover all axes dynamically. Axes that are part of dpads get grouped.
  // Each dpad contributes 2 analog values (x, y). Standalone axes contribute 1.
  NSArray<NSString *> *axisNames =
      [[profile.axes allKeys] sortedArrayUsingSelector:@selector(compare:)];

  // Track which axes belong to dpads
  NSMutableSet<NSString *> *dpadAxisNames = [NSMutableSet set];
  for (NSString *dpadName in dpadNames) {
    GCControllerDirectionPad *dpad = profile.dpads[dpadName];
    for (NSString *aName in axisNames) {
      GCControllerAxisInput *ax = profile.axes[aName];
      if (ax == dpad.xAxis || ax == dpad.yAxis) {
        [dpadAxisNames addObject:aName];
      }
    }
  }

  int analogIdx = 0;

  // Dpad-based axes (2 analogs per dpad: x, y)
  for (NSString *dpadName in dpadNames) {
    if (analogIdx + 2 > kMaxAnalog) {
      break;
    }
    NSString *sfSymbol = nil;
    NSString *locName = nil;
    if (@available(macOS 14.0, *)) {
      GCControllerDirectionPad *dpad = profile.dpads[dpadName];
      sfSymbol = dpad.sfSymbolsName;
      locName = dpad.localizedName;
    }
    [axes addObject:@{
      @"name" : dpadName,
      @"sfSymbol" : sfSymbol ?: [NSNull null],
      @"localizedName" : locName ?: [NSNull null],
      @"analogCount" : @(2)
    }];
    analogIdx += 2;
  }

  // Standalone axes (1 analog each)
  for (NSString *axisName in axisNames) {
    if ([dpadAxisNames containsObject:axisName]) {
      continue;
    }
    if (analogIdx + 1 > kMaxAnalog) {
      break;
    }
    GCControllerAxisInput *ax = profile.axes[axisName];
    if (!ax) {
      continue;
    }
    NSString *sfSymbol = nil;
    NSString *locName = nil;
    if (@available(macOS 14.0, *)) {
      sfSymbol = ax.sfSymbolsName;
      locName = ax.localizedName;
    }
    [axes addObject:@{
      @"name" : axisName,
      @"sfSymbol" : sfSymbol ?: [NSNull null],
      @"localizedName" : locName ?: [NSNull null],
      @"analogCount" : @(1)
    }];
    analogIdx += 1;
  }

  entry->analogCount = analogIdx;
  for (int i = 0; i < kMaxAnalog; i++) {
    entry->state.analog[i].store(0.0f);
  }
  entry->buttonInfos = buttons;
  entry->axisInfos = axes;
  entry->dpadInfos = dpads;

  // Build O(1) lookup maps: element pointer -> index/bit
  // buttonMap: GCControllerButtonInput* -> bit index
  // axisMap: GCControllerElement* (axis or dpad) -> analog base index
  NSMapTable<GCControllerElement *, NSNumber *> *buttonMap =
      [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory |
                                         NSPointerFunctionsOpaquePersonality
                            valueOptions:NSPointerFunctionsStrongMemory];
  NSMapTable<GCControllerElement *, NSNumber *> *axisMap =
      [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory |
                                         NSPointerFunctionsOpaquePersonality
                            valueOptions:NSPointerFunctionsStrongMemory];

  // Map each non-dpad button to its bit
  {
    int b = 0;
    for (NSString *name in orderedButtonKeys) {
      GCControllerButtonInput *btn = profile.buttons[name];
      [buttonMap setObject:@(b) forKey:(GCControllerElement *)btn];
      b++;
    }
  }

  // Map dpad direction buttons to their bits
  for (NSString *dpadName in orderedDpadKeys) {
    GCControllerDirectionPad *dpad = profile.dpads[dpadName];
    // Find the dpad info entry to get the bit values
    for (NSDictionary *dInfo in dpads) {
      if ([dInfo[@"name"] isEqualToString:dpadName]) {
        [buttonMap setObject:dInfo[@"up"]
                      forKey:(GCControllerElement *)dpad.up];
        [buttonMap setObject:dInfo[@"down"]
                      forKey:(GCControllerElement *)dpad.down];
        [buttonMap setObject:dInfo[@"left"]
                      forKey:(GCControllerElement *)dpad.left];
        [buttonMap setObject:dInfo[@"right"]
                      forKey:(GCControllerElement *)dpad.right];
        break;
      }
    }
    // Also map the dpad itself so when the dpad element fires we can update all
    // 4 Store negative base index to signal "dpad" in the handler
  }

  // Map axes/dpads to analog indices
  int aIdx = 0;
  for (NSString *dpadName in dpadNames) {
    GCControllerDirectionPad *dpad = profile.dpads[dpadName];
    [axisMap setObject:@(aIdx) forKey:(GCControllerElement *)dpad];
    [axisMap setObject:@(aIdx) forKey:(GCControllerElement *)dpad.xAxis];
    [axisMap setObject:@(aIdx + 1) forKey:(GCControllerElement *)dpad.yAxis];
    aIdx += 2;
  }
  for (NSString *axisName in axisNames) {
    if ([dpadAxisNames containsObject:axisName]) {
      continue;
    }
    GCControllerAxisInput *ax = profile.axes[axisName];
    if (!ax) {
      continue;
    }
    [axisMap setObject:@(aIdx) forKey:(GCControllerElement *)ax];
    aIdx++;
  }

  int cid = entry->controllerId;
  ControllerState *cs = &entry->state;

  profile.valueDidChangeHandler = ^(GCPhysicalInputProfile *p,
                                    GCControllerElement *element) {
    bool buttonChanged = false;

    // Check if this element is an axis/dpad — O(1) lookup
    NSNumber *analogBase = [axisMap objectForKey:element];
    if (analogBase) {
      int base = [analogBase intValue];
      if ([element isKindOfClass:[GCControllerDirectionPad class]]) {
        GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)element;
        cs->analog[base].store(dpad.xAxis.value);
        cs->analog[base + 1].store(dpad.yAxis.value);
      } else {
        GCControllerAxisInput *ax = (GCControllerAxisInput *)element;
        cs->analog[base].store(ax.value);
      }
    }

    // Check if this element is a button — O(1) lookup
    NSNumber *bitNum = [buttonMap objectForKey:element];
    if (bitNum) {
      int bitIdx = [bitNum intValue];
      GCControllerButtonInput *btn = (GCControllerButtonInput *)element;
      if (btn.pressed) {
        uint32_t prev = cs->buttons.fetch_or(1u << bitIdx);
        buttonChanged = !(prev & (1u << bitIdx));
      } else {
        uint32_t prev = cs->buttons.fetch_and(~(1u << bitIdx));
        buttonChanged = (prev & (1u << bitIdx)) != 0;
      }
    }

    // If element is a dpad, update its 4 direction buttons too
    if ([element isKindOfClass:[GCControllerDirectionPad class]]) {
      GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)element;
      GCControllerButtonInput *dirs[] = {dpad.up, dpad.down, dpad.left,
                                         dpad.right};
      for (int i = 0; i < 4; i++) {
        NSNumber *dBit =
            [buttonMap objectForKey:(GCControllerElement *)dirs[i]];
        if (!dBit) {
          continue;
        }
        int idx = [dBit intValue];
        if (dirs[i].pressed) {
          uint32_t prev = cs->buttons.fetch_or(1u << idx);
          if (!(prev & (1u << idx))) {
            buttonChanged = true;
          }
        } else {
          uint32_t prev = cs->buttons.fetch_and(~(1u << idx));
          if (prev & (1u << idx)) {
            buttonChanged = true;
          }
        }
      }
    }

    cs->lastUpdated.store(p.lastEventTimestamp);

    if (buttonChanged && self.module) {
      if (self->_eventCallback) {
        auto cb = self->_eventCallback;
        auto invoker = self.module->jsInvoker_;
        invoker->invokeAsync([cb, cs, cid](facebook::jsi::Runtime &rt) {
          uint32_t b = cs->buttons.load(std::memory_order_relaxed);
          uint32_t lastCb =
              cs->lastCallbackButtons.exchange(b, std::memory_order_relaxed);
          if (b != lastCb) {
            double ts = cs->lastUpdated.load(std::memory_order_relaxed);
            cb->call(rt, cid, static_cast<int>(b), ts);
          }
        });
      }
      if (self.buttonEventsEnabled) {
        uint32_t bval = cs->buttons.load(std::memory_order_relaxed);
        facebook::react::ControllerButtonEventStruct evt{cid, (double)bval,
                                                         p.lastEventTimestamp};
        self.module->emitOnControllerButton(evt);
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
  // Copy keys since _controllerDisconnected mutates _entries
  std::vector<GCController *> controllers;
  for (auto &pair : _entries) {
    controllers.push_back(pair.second->controller);
  }
  for (GCController *c : controllers) {
    [self _controllerDisconnected:c];
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
                  NSNumber *idNum =
                      [self->_controllerToId objectForKey:controller];
                  if (!idNum) {
                    return;
                  }
                  if (self.module) {
                    self.module->emitOnControllerCurrentChange(
                        [idNum intValue]);
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
  int cid = _nextControllerId++;

  auto *entry = new ControllerEntry();
  entry->controllerId = cid;
  entry->controller = controller;
  [self _assignProfile:entry controller:controller];

  _entries[cid] = entry;
  [_controllerToId setObject:@(cid) forKey:controller];

  if (self.module) {
    self.module->emitOnControllerConnected(cid);
  }
}

- (void)_controllerDisconnected:(GCController *)controller {
  NSNumber *idNum = [_controllerToId objectForKey:controller];
  if (!idNum) {
    return;
  }

  int cid = [idNum intValue];
  auto it = _entries.find(cid);
  if (it != _entries.end()) {
    auto *e = it->second;
    if (e->controller.physicalInputProfile) {
      e->controller.physicalInputProfile.valueDidChangeHandler = nil;
    }
    delete e;
    _entries.erase(it);
  }

  [_controllerToId removeObjectForKey:controller];

  if (self.module) {
    self.module->emitOnControllerDisconnected(cid);
  }
}

// MARK: - Queries

- (ControllerEntry *)findEntryById:(int)controllerId {
  auto it = _entries.find(controllerId);
  return it != _entries.end() ? it->second : nullptr;
}

- (const std::unordered_map<int, ControllerEntry *> &)entries {
  return _entries;
}

// MARK: - Callback

- (void)setEventCallback:(std::shared_ptr<facebook::jsi::Function>)callback {
  _eventCallback = std::move(callback);
}

- (std::shared_ptr<facebook::jsi::Function>)clearEventCallback {
  return std::move(_eventCallback);
}

@end
