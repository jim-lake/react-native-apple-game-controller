#include "RNGameController.h"
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <atomic>

// MARK: - Singleton Helper

@interface RNGameControllerHelper : NSObject
@property(nonatomic, assign) facebook::react::RNGameController *module;
+ (instancetype)shared;
@end

@implementation RNGameControllerHelper
+ (instancetype)shared {
  static RNGameControllerHelper *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ instance = [[RNGameControllerHelper alloc] init]; });
  return instance;
}
@end

// MARK: - Controller State

static constexpr int kMaxAnalog = 6;

struct ControllerState {
  std::atomic<float> analog[kMaxAnalog];
  std::atomic<uint32_t> buttons{0};
};

// MARK: - Controller Entry

struct ControllerEntry {
  int controllerId;
  __strong GCController *controller;
  ControllerState state;
  int analogCount;
  // Profile metadata stored as ObjC collections for easy serialization
  NSArray<NSDictionary *> *buttonInfos;
  NSArray<NSDictionary *> *axisInfos;
  NSArray<NSDictionary *> *dpadInfos;
};

static NSMutableArray<NSValue *> *sControllerEntries = nil;
static int sNextControllerId = 1;
static id sConnectObserver = nil;
static id sDisconnectObserver = nil;

static ControllerEntry *findEntry(int cid) {
  for (NSValue *v in sControllerEntries) {
    auto *e = (ControllerEntry *)v.pointerValue;
    if (e->controllerId == cid) return e;
  }
  return nullptr;
}

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

  // Button inputs and their bit positions
  struct BtnDef { GCControllerButtonInput *input; NSString *name; };
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
        @"name": bd.name,
        @"sfSymbol": sfSymbol ?: [NSNull null],
        @"localizedName": locName ?: [NSNull null],
        @"bit": @(bit)
      }];
      bit++;
    }
  }

  // Dpad digital bits
  int dpadUpBit = bit++;
  int dpadDownBit = bit++;
  int dpadLeftBit = bit++;
  int dpadRightBit = bit++;

  [buttons addObject:@{@"name": @"D-pad Up", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"bit": @(dpadUpBit)}];
  [buttons addObject:@{@"name": @"D-pad Down", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"bit": @(dpadDownBit)}];
  [buttons addObject:@{@"name": @"D-pad Left", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"bit": @(dpadLeftBit)}];
  [buttons addObject:@{@"name": @"D-pad Right", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"bit": @(dpadRightBit)}];

  [dpads addObject:@{@"name": @"Direction Pad", @"up": @(dpadUpBit), @"down": @(dpadDownBit), @"left": @(dpadLeftBit), @"right": @(dpadRightBit)}];

  // Axes: LX=0, LY=1, RX=2, RY=3, LT=4, RT=5
  [axes addObject:@{@"name": @"Left Thumbstick", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"analogIndex": @[@0, @1]}];
  [axes addObject:@{@"name": @"Right Thumbstick", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"analogIndex": @[@2, @3]}];
  [axes addObject:@{@"name": @"Left Trigger", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"analogIndex": @[@4]}];
  [axes addObject:@{@"name": @"Right Trigger", @"sfSymbol": [NSNull null], @"localizedName": [NSNull null], @"analogIndex": @[@5]}];

  entry->analogCount = kMaxAnalog;
  for (int i = 0; i < kMaxAnalog; i++) entry->state.analog[i].store(0.0f);
  entry->buttonInfos = buttons;
  entry->axisInfos = axes;
  entry->dpadInfos = dpads;

  // Capture values needed in handler
  int cid = entry->controllerId;
  ControllerState *cs = &entry->state;

  // Track which bits correspond to which buttons (by order)
  // bit positions for standard buttons: 0..N-1 for present buttons
  int numStdButtons = 0;
  for (auto &bd : btnDefs) { if (bd.input) numStdButtons++; }

  gp.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element) {
    // Update analog atomics
    cs->analog[0].store(gamepad.leftThumbstick.xAxis.value);
    cs->analog[1].store(gamepad.leftThumbstick.yAxis.value);
    cs->analog[2].store(gamepad.rightThumbstick.xAxis.value);
    cs->analog[3].store(gamepad.rightThumbstick.yAxis.value);
    cs->analog[4].store(gamepad.leftTrigger.value);
    cs->analog[5].store(gamepad.rightTrigger.value);

    // Rebuild button bitfield
    uint32_t bval = 0;
    int b = 0;
    if (gamepad.buttonA && gamepad.buttonA.pressed) bval |= (1u << b); if (gamepad.buttonA) b++;
    if (gamepad.buttonB && gamepad.buttonB.pressed) bval |= (1u << b); if (gamepad.buttonB) b++;
    if (gamepad.buttonX && gamepad.buttonX.pressed) bval |= (1u << b); if (gamepad.buttonX) b++;
    if (gamepad.buttonY && gamepad.buttonY.pressed) bval |= (1u << b); if (gamepad.buttonY) b++;
    if (gamepad.leftShoulder && gamepad.leftShoulder.pressed) bval |= (1u << b); if (gamepad.leftShoulder) b++;
    if (gamepad.rightShoulder && gamepad.rightShoulder.pressed) bval |= (1u << b); if (gamepad.rightShoulder) b++;
    if (gamepad.leftThumbstickButton && gamepad.leftThumbstickButton.pressed) bval |= (1u << b); if (gamepad.leftThumbstickButton) b++;
    if (gamepad.rightThumbstickButton && gamepad.rightThumbstickButton.pressed) bval |= (1u << b); if (gamepad.rightThumbstickButton) b++;
    if (gamepad.buttonOptions && gamepad.buttonOptions.pressed) bval |= (1u << b); if (gamepad.buttonOptions) b++;
    if (gamepad.buttonMenu && gamepad.buttonMenu.pressed) bval |= (1u << b); if (gamepad.buttonMenu) b++;
    if (gamepad.buttonHome && gamepad.buttonHome.pressed) bval |= (1u << b); if (gamepad.buttonHome) b++;

    if (gamepad.dpad.up.pressed) bval |= (1u << dpadUpBit);
    if (gamepad.dpad.down.pressed) bval |= (1u << dpadDownBit);
    if (gamepad.dpad.left.pressed) bval |= (1u << dpadLeftBit);
    if (gamepad.dpad.right.pressed) bval |= (1u << dpadRightBit);

    uint32_t prev = cs->buttons.exchange(bval);
    if (prev != bval) {
      auto *helper = [RNGameControllerHelper shared];
      if (helper.module) {
        helper.module->handleButtonChange(cid, bval);
      }
    }
  };
}

// MARK: - Controller Lifecycle

static void controllerConnected(GCController *controller) {
  auto *entry = new ControllerEntry();
  entry->controllerId = sNextControllerId++;
  entry->controller = controller;
  assignProfile(entry, controller);

  if (!sControllerEntries) sControllerEntries = [NSMutableArray array];
  [sControllerEntries addObject:[NSValue valueWithPointer:entry]];

  auto *helper = [RNGameControllerHelper shared];
  if (helper.module) {
    helper.module->handleConnect(entry->controllerId);
  }
}

static void controllerDisconnected(GCController *controller) {
  int cid = -1;
  for (NSInteger i = 0; i < (NSInteger)sControllerEntries.count; i++) {
    auto *e = (ControllerEntry *)sControllerEntries[i].pointerValue;
    if (e->controller == controller) {
      cid = e->controllerId;
      delete e;
      [sControllerEntries removeObjectAtIndex:i];
      break;
    }
  }
  if (cid >= 0) {
    auto *helper = [RNGameControllerHelper shared];
    if (helper.module) {
      helper.module->handleDisconnect(cid);
    }
  }
}

static void setupNotifications() {
  if (sConnectObserver) return;
  if (!sControllerEntries) sControllerEntries = [NSMutableArray array];

  sConnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidConnectNotification
                  object:nil queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                controllerConnected((GCController *)note.object);
              }];
  sDisconnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCControllerDidDisconnectNotification
                  object:nil queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                controllerDisconnected((GCController *)note.object);
              }];

  for (GCController *c in [GCController controllers]) {
    controllerConnected(c);
  }
}

// MARK: - C++ Implementation

namespace facebook::react {

RNGameController::RNGameController(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeGameControllerCxxSpec(std::move(jsInvoker)) {
  jsInvoker_ = NativeGameControllerCxxSpec::jsInvoker_;
  dispatch_async(dispatch_get_main_queue(), ^{
    [RNGameControllerHelper shared].module = this;
    setupNotifications();
  });
}

RNGameController::~RNGameController() {
  auto *ptr = this;
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([RNGameControllerHelper shared].module == ptr) {
      [RNGameControllerHelper shared].module = nullptr;
    }
  });
}

void RNGameController::handleConnect(int controllerId) {
  jsInvoker_->invokeAsync([this, controllerId]() {
    emitOnConnected((double)controllerId);
  });
}

void RNGameController::handleDisconnect(int controllerId) {
  jsInvoker_->invokeAsync([this, controllerId]() {
    emitOnDisconnected((double)controllerId);
  });
}

void RNGameController::handleButtonChange(int controllerId, uint32_t btns) {
  if (buttonEventsEnabled_) {
    jsInvoker_->invokeAsync([this, controllerId, btns]() {
      ButtonEventStruct evt{(double)controllerId, (double)btns};
      emitOnGamepadButton(evt);
    });
  }
}

jsi::Value RNGameController::getControllers(jsi::Runtime &rt) {
  return createPromiseAsJSIValue(
      rt, [this](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        dispatch_async(dispatch_get_main_queue(), ^{
          NSMutableArray *results = [NSMutableArray array];
          for (NSValue *v in sControllerEntries) {
            auto *entry = (ControllerEntry *)v.pointerValue;
            GCController *c = entry->controller;
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            info[@"controllerId"] = @(entry->controllerId);
            info[@"vendorName"] = c.vendorName ?: [NSNull null];
            info[@"productCategory"] = c.productCategory ?: [NSNull null];
            info[@"playerIndex"] = @((int)c.playerIndex);
            info[@"isAttached"] = @(c.isAttachedToDevice);

            if (c.battery) {
              info[@"batteryLevel"] = @(c.battery.batteryLevel);
              switch (c.battery.batteryState) {
                case GCDeviceBatteryStateCharging: info[@"batteryState"] = @"charging"; break;
                case GCDeviceBatteryStateFull: info[@"batteryState"] = @"full"; break;
                default: info[@"batteryState"] = @"discharging"; break;
              }
            } else {
              info[@"batteryLevel"] = [NSNull null];
              info[@"batteryState"] = [NSNull null];
            }

            if (c.light) {
              GCColor *color = c.light.color;
              info[@"lightColor"] = @{@"r": @(color.red), @"g": @(color.green), @"b": @(color.blue)};
            } else {
              info[@"lightColor"] = [NSNull null];
            }

            info[@"buttons"] = entry->buttonInfos;
            info[@"axes"] = entry->axisInfos;
            info[@"dpads"] = entry->dpadInfos;
            [results addObject:info];
          }

          // Resolve on JS thread
          this->jsInvoker_->invokeAsync([this, results, promise, &rt]() {
            auto arr = jsi::Array(rt, results.count);
            for (NSUInteger i = 0; i < results.count; i++) {
              NSDictionary *info = results[i];
              auto obj = jsi::Object(rt);
              obj.setProperty(rt, "controllerId", [(NSNumber *)info[@"controllerId"] doubleValue]);
              if (info[@"vendorName"] == [NSNull null]) {
                obj.setProperty(rt, "vendorName", jsi::Value::null());
              } else {
                obj.setProperty(rt, "vendorName", jsi::String::createFromUtf8(rt, [(NSString *)info[@"vendorName"] UTF8String]));
              }
              if (info[@"productCategory"] == [NSNull null]) {
                obj.setProperty(rt, "productCategory", jsi::Value::null());
              } else {
                obj.setProperty(rt, "productCategory", jsi::String::createFromUtf8(rt, [(NSString *)info[@"productCategory"] UTF8String]));
              }
              obj.setProperty(rt, "playerIndex", [(NSNumber *)info[@"playerIndex"] doubleValue]);
              if (info[@"batteryLevel"] == [NSNull null]) {
                obj.setProperty(rt, "batteryLevel", jsi::Value::null());
              } else {
                obj.setProperty(rt, "batteryLevel", [(NSNumber *)info[@"batteryLevel"] doubleValue]);
              }
              if (info[@"batteryState"] == [NSNull null]) {
                obj.setProperty(rt, "batteryState", jsi::Value::null());
              } else {
                obj.setProperty(rt, "batteryState", jsi::String::createFromUtf8(rt, [(NSString *)info[@"batteryState"] UTF8String]));
              }
              if (info[@"lightColor"] == [NSNull null]) {
                obj.setProperty(rt, "lightColor", jsi::Value::null());
              } else {
                NSDictionary *lc = info[@"lightColor"];
                auto lcObj = jsi::Object(rt);
                lcObj.setProperty(rt, "r", [(NSNumber *)lc[@"r"] doubleValue]);
                lcObj.setProperty(rt, "g", [(NSNumber *)lc[@"g"] doubleValue]);
                lcObj.setProperty(rt, "b", [(NSNumber *)lc[@"b"] doubleValue]);
                obj.setProperty(rt, "lightColor", std::move(lcObj));
              }
              obj.setProperty(rt, "isAttached", [(NSNumber *)info[@"isAttached"] boolValue]);

              // Buttons array
              NSArray *btns = info[@"buttons"];
              auto btnsArr = jsi::Array(rt, btns.count);
              for (NSUInteger j = 0; j < btns.count; j++) {
                NSDictionary *b = btns[j];
                auto bObj = jsi::Object(rt);
                bObj.setProperty(rt, "name", jsi::String::createFromUtf8(rt, [(NSString *)b[@"name"] UTF8String]));
                if (b[@"sfSymbol"] == [NSNull null]) {
                  bObj.setProperty(rt, "sfSymbol", jsi::Value::null());
                } else {
                  bObj.setProperty(rt, "sfSymbol", jsi::String::createFromUtf8(rt, [(NSString *)b[@"sfSymbol"] UTF8String]));
                }
                if (b[@"localizedName"] == [NSNull null]) {
                  bObj.setProperty(rt, "localizedName", jsi::Value::null());
                } else {
                  bObj.setProperty(rt, "localizedName", jsi::String::createFromUtf8(rt, [(NSString *)b[@"localizedName"] UTF8String]));
                }
                bObj.setProperty(rt, "bit", [(NSNumber *)b[@"bit"] doubleValue]);
                btnsArr.setValueAtIndex(rt, j, std::move(bObj));
              }
              obj.setProperty(rt, "buttons", std::move(btnsArr));

              // Axes array
              NSArray *axs = info[@"axes"];
              auto axsArr = jsi::Array(rt, axs.count);
              for (NSUInteger j = 0; j < axs.count; j++) {
                NSDictionary *a = axs[j];
                auto aObj = jsi::Object(rt);
                aObj.setProperty(rt, "name", jsi::String::createFromUtf8(rt, [(NSString *)a[@"name"] UTF8String]));
                if (a[@"sfSymbol"] == [NSNull null]) {
                  aObj.setProperty(rt, "sfSymbol", jsi::Value::null());
                } else {
                  aObj.setProperty(rt, "sfSymbol", jsi::String::createFromUtf8(rt, [(NSString *)a[@"sfSymbol"] UTF8String]));
                }
                if (a[@"localizedName"] == [NSNull null]) {
                  aObj.setProperty(rt, "localizedName", jsi::Value::null());
                } else {
                  aObj.setProperty(rt, "localizedName", jsi::String::createFromUtf8(rt, [(NSString *)a[@"localizedName"] UTF8String]));
                }
                NSArray *idxs = a[@"analogIndex"];
                auto idxArr = jsi::Array(rt, idxs.count);
                for (NSUInteger k = 0; k < idxs.count; k++) {
                  idxArr.setValueAtIndex(rt, k, [(NSNumber *)idxs[k] doubleValue]);
                }
                aObj.setProperty(rt, "analogIndex", std::move(idxArr));
                axsArr.setValueAtIndex(rt, j, std::move(aObj));
              }
              obj.setProperty(rt, "axes", std::move(axsArr));

              // Dpads array
              NSArray *dps = info[@"dpads"];
              auto dpsArr = jsi::Array(rt, dps.count);
              for (NSUInteger j = 0; j < dps.count; j++) {
                NSDictionary *d = dps[j];
                auto dObj = jsi::Object(rt);
                dObj.setProperty(rt, "name", jsi::String::createFromUtf8(rt, [(NSString *)d[@"name"] UTF8String]));
                dObj.setProperty(rt, "up", [(NSNumber *)d[@"up"] doubleValue]);
                dObj.setProperty(rt, "down", [(NSNumber *)d[@"down"] doubleValue]);
                dObj.setProperty(rt, "left", [(NSNumber *)d[@"left"] doubleValue]);
                dObj.setProperty(rt, "right", [(NSNumber *)d[@"right"] doubleValue]);
                dpsArr.setValueAtIndex(rt, j, std::move(dObj));
              }
              obj.setProperty(rt, "dpads", std::move(dpsArr));

              arr.setValueAtIndex(rt, i, std::move(obj));
            }
            promise->resolve(std::move(arr));
          });
        });
      });
}

jsi::Object RNGameController::getControllerState(jsi::Runtime &rt,
                                                  double controllerId) {
  int cid = (int)controllerId;
  for (NSValue *v in sControllerEntries) {
    auto *entry = (ControllerEntry *)v.pointerValue;
    if (entry->controllerId == cid) {
      auto obj = jsi::Object(rt);
      int count = entry->analogCount;
      auto analog = jsi::Array(rt, count);
      for (int i = 0; i < count; i++) {
        analog.setValueAtIndex(rt, i, (double)entry->state.analog[i].load(std::memory_order_relaxed));
      }
      obj.setProperty(rt, "analog", std::move(analog));
      obj.setProperty(rt, "buttons", (double)entry->state.buttons.load(std::memory_order_relaxed));
      return obj;
    }
  }
  auto obj = jsi::Object(rt);
  obj.setProperty(rt, "analog", jsi::Array(rt, 0));
  obj.setProperty(rt, "buttons", 0.0);
  return obj;
}

void RNGameController::registerEventCallback(
    jsi::Runtime &rt, std::optional<jsi::Function> callback) {
  std::lock_guard<std::mutex> lock(callbackMutex_);
  if (callback.has_value()) {
    eventCallback_ = std::make_shared<jsi::Function>(std::move(*callback));
  } else {
    eventCallback_ = nullptr;
  }
}

void RNGameController::toggleButtonEvents(jsi::Runtime &rt, bool enabled) {
  buttonEventsEnabled_ = enabled;
}

jsi::Value RNGameController::setLightColor(jsi::Runtime &rt,
                                           double controllerId, double r,
                                           double g, double b) {
  int cid = (int)controllerId;
  return createPromiseAsJSIValue(
      rt, [this, cid, r, g, b](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        dispatch_async(dispatch_get_main_queue(), ^{
          ControllerEntry *entry = findEntry(cid);
          if (entry && entry->controller.light) {
            entry->controller.light.color = [[GCColor alloc] initWithRed:r green:g blue:b];
            this->jsInvoker_->invokeAsync([promise]() {
              promise->resolve(jsi::Value::undefined());
            });
          } else {
            this->jsInvoker_->invokeAsync([promise]() {
              promise->reject("Controller not found or has no light");
            });
          }
        });
      });
}

jsi::Value RNGameController::setPlayerIndex(jsi::Runtime &rt,
                                            double controllerId, double index) {
  int cid = (int)controllerId;
  int idx = (int)index;
  return createPromiseAsJSIValue(
      rt, [this, cid, idx](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        dispatch_async(dispatch_get_main_queue(), ^{
          ControllerEntry *entry = findEntry(cid);
          if (entry) {
            entry->controller.playerIndex = idx == -1 ? GCControllerPlayerIndexUnset : (GCControllerPlayerIndex)idx;
            this->jsInvoker_->invokeAsync([promise]() {
              promise->resolve(jsi::Value::undefined());
            });
          } else {
            this->jsInvoker_->invokeAsync([promise]() {
              promise->reject("Controller not found");
            });
          }
        });
      });
}

} // namespace facebook::react
