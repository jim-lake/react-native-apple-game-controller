#include "RNGameController.h"
#import "RNGCKeyboardHelper.h"
#import "RNGameControllerHelper.h"
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

namespace facebook::react {

RNGameController::RNGameController(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeGameControllerCxxSpec(std::move(jsInvoker)) {
  jsInvoker_ = NativeGameControllerCxxSpec::jsInvoker_;
  dispatch_async(dispatch_get_main_queue(), ^{
    [RNGameControllerHelper shared].module = this;
    [RNGCKeyboardHelper shared].module = this;
    setupNotifications();
    [[RNGCKeyboardHelper shared] start];
  });
}

RNGameController::~RNGameController() {
  auto *ptr = this;
  dispatch_async(dispatch_get_main_queue(), ^{
    if ([RNGameControllerHelper shared].module == ptr) {
      [RNGameControllerHelper shared].module = nullptr;
    }
    if ([RNGCKeyboardHelper shared].module == ptr) {
      [[RNGCKeyboardHelper shared] stop];
      [RNGCKeyboardHelper shared].module = nullptr;
    }
  });
}

// MARK: - getControllers

jsi::Value RNGameController::getControllers(jsi::Runtime &rt) {
  return createPromiseAsJSIValue(rt, [this](jsi::Runtime &rt,
                                            std::shared_ptr<Promise> promise) {
    dispatch_async(dispatch_get_main_queue(), ^{
      auto *helper = [RNGameControllerHelper shared];
      NSArray<NSValue *> *entries = [helper entries];

      NSMutableArray *results = [NSMutableArray array];
      for (NSValue *v in entries) {
        auto *entry = (ControllerEntry *)v.pointerValue;
        GCController *c = entry->controller;
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"controllerId"] =
            [NSString stringWithUTF8String:entry->controllerId.c_str()];
        info[@"isCurrent"] = @(c == [GCController current]);
        info[@"vendorName"] = c.vendorName ?: [NSNull null];
        info[@"productCategory"] = c.productCategory ?: [NSNull null];
        info[@"playerIndex"] = @((int)c.playerIndex);
        info[@"isAttached"] = @(c.isAttachedToDevice);

        if (c.battery) {
          info[@"batteryLevel"] = @(c.battery.batteryLevel);
          switch (c.battery.batteryState) {
          case GCDeviceBatteryStateCharging:
            info[@"batteryState"] = @"charging";
            break;
          case GCDeviceBatteryStateFull:
            info[@"batteryState"] = @"full";
            break;
          default:
            info[@"batteryState"] = @"discharging";
            break;
          }
        } else {
          info[@"batteryLevel"] = [NSNull null];
          info[@"batteryState"] = [NSNull null];
        }

        if (c.light) {
          GCColor *color = c.light.color;
          info[@"lightColor"] = @{
            @"r" : @(color.red),
            @"g" : @(color.green),
            @"b" : @(color.blue)
          };
        } else {
          info[@"lightColor"] = [NSNull null];
        }

        info[@"buttons"] = entry->buttonInfos;
        info[@"axes"] = entry->axisInfos;
        info[@"dpads"] = entry->dpadInfos;
        [results addObject:info];
      }

      this->jsInvoker_->invokeAsync([this, results, promise, &rt]() {
        auto arr = jsi::Array(rt, results.count);
        for (NSUInteger i = 0; i < results.count; i++) {
          NSDictionary *info = results[i];
          auto obj = jsi::Object(rt);

          obj.setProperty(
              rt, "controllerId",
              jsi::String::createFromUtf8(
                  rt, [(NSString *)info[@"controllerId"] UTF8String]));
          obj.setProperty(rt, "isCurrent",
                          [(NSNumber *)info[@"isCurrent"] boolValue]);
          if (info[@"vendorName"] == [NSNull null]) {
            obj.setProperty(rt, "vendorName", jsi::Value::null());
          } else {
            obj.setProperty(
                rt, "vendorName",
                jsi::String::createFromUtf8(
                    rt, [(NSString *)info[@"vendorName"] UTF8String]));
          }
          if (info[@"productCategory"] == [NSNull null]) {
            obj.setProperty(rt, "productCategory", jsi::Value::null());
          } else {
            obj.setProperty(
                rt, "productCategory",
                jsi::String::createFromUtf8(
                    rt, [(NSString *)info[@"productCategory"] UTF8String]));
          }
          obj.setProperty(rt, "playerIndex",
                          [(NSNumber *)info[@"playerIndex"] doubleValue]);
          if (info[@"batteryLevel"] == [NSNull null]) {
            obj.setProperty(rt, "batteryLevel", jsi::Value::null());
          } else {
            obj.setProperty(rt, "batteryLevel",
                            [(NSNumber *)info[@"batteryLevel"] doubleValue]);
          }
          if (info[@"batteryState"] == [NSNull null]) {
            obj.setProperty(rt, "batteryState", jsi::Value::null());
          } else {
            obj.setProperty(
                rt, "batteryState",
                jsi::String::createFromUtf8(
                    rt, [(NSString *)info[@"batteryState"] UTF8String]));
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
          obj.setProperty(rt, "isAttached",
                          [(NSNumber *)info[@"isAttached"] boolValue]);

          // Buttons array
          NSArray *btns = info[@"buttons"];
          auto btnsArr = jsi::Array(rt, btns.count);
          for (NSUInteger j = 0; j < btns.count; j++) {
            NSDictionary *b = btns[j];
            auto bObj = jsi::Object(rt);
            bObj.setProperty(rt, "name",
                             jsi::String::createFromUtf8(
                                 rt, [(NSString *)b[@"name"] UTF8String]));
            if (b[@"sfSymbol"] == [NSNull null]) {
              bObj.setProperty(rt, "sfSymbol", jsi::Value::null());
            } else {
              bObj.setProperty(
                  rt, "sfSymbol",
                  jsi::String::createFromUtf8(
                      rt, [(NSString *)b[@"sfSymbol"] UTF8String]));
            }
            if (b[@"localizedName"] == [NSNull null]) {
              bObj.setProperty(rt, "localizedName", jsi::Value::null());
            } else {
              bObj.setProperty(
                  rt, "localizedName",
                  jsi::String::createFromUtf8(
                      rt, [(NSString *)b[@"localizedName"] UTF8String]));
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
            aObj.setProperty(rt, "name",
                             jsi::String::createFromUtf8(
                                 rt, [(NSString *)a[@"name"] UTF8String]));
            if (a[@"sfSymbol"] == [NSNull null]) {
              aObj.setProperty(rt, "sfSymbol", jsi::Value::null());
            } else {
              aObj.setProperty(
                  rt, "sfSymbol",
                  jsi::String::createFromUtf8(
                      rt, [(NSString *)a[@"sfSymbol"] UTF8String]));
            }
            if (a[@"localizedName"] == [NSNull null]) {
              aObj.setProperty(rt, "localizedName", jsi::Value::null());
            } else {
              aObj.setProperty(
                  rt, "localizedName",
                  jsi::String::createFromUtf8(
                      rt, [(NSString *)a[@"localizedName"] UTF8String]));
            }
            aObj.setProperty(rt, "analogCount",
                             [(NSNumber *)a[@"analogCount"] doubleValue]);
            axsArr.setValueAtIndex(rt, j, std::move(aObj));
          }
          obj.setProperty(rt, "axes", std::move(axsArr));

          // Dpads array
          NSArray *dps = info[@"dpads"];
          auto dpsArr = jsi::Array(rt, dps.count);
          for (NSUInteger j = 0; j < dps.count; j++) {
            NSDictionary *d = dps[j];
            auto dObj = jsi::Object(rt);
            dObj.setProperty(rt, "name",
                             jsi::String::createFromUtf8(
                                 rt, [(NSString *)d[@"name"] UTF8String]));
            dObj.setProperty(rt, "up", [(NSNumber *)d[@"up"] doubleValue]);
            dObj.setProperty(rt, "down", [(NSNumber *)d[@"down"] doubleValue]);
            dObj.setProperty(rt, "left", [(NSNumber *)d[@"left"] doubleValue]);
            dObj.setProperty(rt, "right",
                             [(NSNumber *)d[@"right"] doubleValue]);
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

// MARK: - getControllerState

jsi::Object RNGameController::getControllerState(jsi::Runtime &rt,
                                                 jsi::String controllerId) {
  std::string cid = controllerId.utf8(rt);
  auto *helper = [RNGameControllerHelper shared];
  ControllerEntry *entry = [helper findEntryById:cid];
  if (entry) {
    auto obj = jsi::Object(rt);
    int count = entry->analogCount;
    auto analog = jsi::Array(rt, count);
    for (int i = 0; i < count; i++) {
      analog.setValueAtIndex(
          rt, i,
          (double)entry->state.analog[i].load(std::memory_order_relaxed));
    }
    obj.setProperty(rt, "analog", std::move(analog));
    obj.setProperty(
        rt, "buttons",
        (double)entry->state.buttons.load(std::memory_order_relaxed));
    obj.setProperty(rt, "lastUpdated",
                    entry->state.lastUpdated.load(std::memory_order_relaxed));
    return obj;
  }
  auto obj = jsi::Object(rt);
  obj.setProperty(rt, "analog", jsi::Array(rt, 0));
  obj.setProperty(rt, "buttons", 0.0);
  obj.setProperty(rt, "lastUpdated", 0.0);
  return obj;
}

// MARK: - Callbacks

void RNGameController::registerControllerEventCallback(
    jsi::Runtime &rt, std::optional<jsi::Function> callback) {
  // TODO: implement via controller helper on main thread
}

void RNGameController::registerKeyboardEventCallback(
    jsi::Runtime &rt, std::optional<jsi::Function> callback) {
  auto cb = callback.has_value()
                ? std::make_shared<jsi::Function>(std::move(*callback))
                : nullptr;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (cb) {
      jsi::Function fn = std::move(*cb);
      [[RNGCKeyboardHelper shared] setCallback:std::move(fn)];
    } else {
      [[RNGCKeyboardHelper shared] setCallback:std::nullopt];
    }
  });
}

void RNGameController::registerMouseButtonEventCallback(
    jsi::Runtime &rt, std::optional<jsi::Function> callback) {
  // TODO: implement mouse button event capture
}

void RNGameController::registerMouseMoveEventCallback(
    jsi::Runtime &rt, std::optional<jsi::Function> callback) {
  // TODO: implement mouse move event capture
}

// MARK: - Shared Buffers

jsi::Value RNGameController::_startControllerCapture(jsi::Runtime &rt) {
  // TODO: implement shared buffer capture
  return createPromiseAsJSIValue(
      rt, [this](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        jsInvoker_->invokeAsync(
            [&rt, promise]() { promise->resolve(jsi::Array(rt, 0)); });
      });
}

jsi::Value RNGameController::stopControllerCapture(jsi::Runtime &rt) {
  // TODO: implement shared buffer stop
  return createPromiseAsJSIValue(
      rt, [this](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        jsInvoker_->invokeAsync(
            [promise]() { promise->resolve(jsi::Value::undefined()); });
      });
}

// MARK: - Mouse Delta

void RNGameController::toggleMouseMoveDeltaCollect(jsi::Runtime &rt,
                                                   bool enable) {
  // TODO: implement mouse delta collection
}

void RNGameController::getMouseMoveDeltaAndReset(jsi::Runtime &rt,
                                                 jsi::Object deltas) {
  // TODO: write accumulated deltas into buffer and reset
}

// MARK: - Toggles

void RNGameController::toggleControllerCurrentEvents(jsi::Runtime &rt,
                                                     bool enable) {
  // TODO: implement current controller change events
}

void RNGameController::toggleControllerButtonEvents(jsi::Runtime &rt,
                                                    bool enable) {
  buttonEventsEnabled_ = enable;
}

void RNGameController::toggleKeyboardEvents(jsi::Runtime &rt, bool enable) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [RNGCKeyboardHelper shared].eventsEnabled = enable;
  });
}

void RNGameController::toggleMouseButtonEvents(jsi::Runtime &rt, bool enable) {
  // TODO: implement mouse button EventEmitter toggle
}

void RNGameController::toggleMouseMoveEvents(jsi::Runtime &rt, bool enable) {
  // TODO: implement mouse move EventEmitter toggle
}

// MARK: - Actions

jsi::Value RNGameController::setLightColor(jsi::Runtime &rt,
                                           jsi::String controllerId, double r,
                                           double g, double b) {
  std::string cid = controllerId.utf8(rt);
  return createPromiseAsJSIValue(
      rt,
      [this, cid, r, g, b](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        dispatch_async(dispatch_get_main_queue(), ^{
          auto *helper = [RNGameControllerHelper shared];
          ControllerEntry *entry = [helper findEntryById:cid];
          if (entry && entry->controller.light) {
            entry->controller.light.color = [[GCColor alloc] initWithRed:r
                                                                   green:g
                                                                    blue:b];
            this->jsInvoker_->invokeAsync(
                [promise]() { promise->resolve(jsi::Value::undefined()); });
          } else {
            this->jsInvoker_->invokeAsync([promise]() {
              promise->reject("Controller not found or has no light");
            });
          }
        });
      });
}

jsi::Value RNGameController::setPlayerIndex(jsi::Runtime &rt,
                                            jsi::String controllerId,
                                            double index) {
  std::string cid = controllerId.utf8(rt);
  int idx = (int)index;
  return createPromiseAsJSIValue(
      rt, [this, cid, idx](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        dispatch_async(dispatch_get_main_queue(), ^{
          auto *helper = [RNGameControllerHelper shared];
          ControllerEntry *entry = [helper findEntryById:cid];
          if (entry) {
            entry->controller.playerIndex = idx == -1
                                                ? GCControllerPlayerIndexUnset
                                                : (GCControllerPlayerIndex)idx;
            this->jsInvoker_->invokeAsync(
                [promise]() { promise->resolve(jsi::Value::undefined()); });
          } else {
            this->jsInvoker_->invokeAsync(
                [promise]() { promise->reject("Controller not found"); });
          }
        });
      });
}

jsi::Value RNGameController::shouldMonitorBackgroundEvents(jsi::Runtime &rt,
                                                           bool enable) {
  // TODO: implement background event monitoring
  return createPromiseAsJSIValue(
      rt, [this](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        jsInvoker_->invokeAsync(
            [promise]() { promise->resolve(jsi::Value::undefined()); });
      });
}

} // namespace facebook::react
