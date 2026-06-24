#include "RNGameController.h"

namespace facebook::react {

RNGameController::RNGameController(std::shared_ptr<CallInvoker> jsInvoker)
    : NativeGameControllerCxxSpec(std::move(jsInvoker)) {}

RNGameController::~RNGameController() {}

jsi::Value RNGameController::getControllers(jsi::Runtime &rt) {
  return createPromiseAsJSIValue(
      rt, [](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        promise->resolve(jsi::Array(rt, 0));
      });
}

jsi::Object RNGameController::getControllerState(jsi::Runtime &rt,
                                                  double controllerId) {
  auto obj = jsi::Object(rt);
  auto analog = jsi::Array(rt, 6);
  for (int i = 0; i < 6; i++) {
    analog.setValueAtIndex(rt, i, 0.0);
  }
  obj.setProperty(rt, "analog", std::move(analog));
  obj.setProperty(rt, "buttons", 0.0);
  return obj;
}

void RNGameController::registerEventCallback(
    jsi::Runtime &rt, std::optional<jsi::Function> callback) {
  // stub
}

void RNGameController::toggleButtonEvents(jsi::Runtime &rt, bool enabled) {
  // stub
}

jsi::Value RNGameController::setLightColor(jsi::Runtime &rt,
                                           double controllerId, double r,
                                           double g, double b) {
  return createPromiseAsJSIValue(
      rt, [](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        promise->resolve(jsi::Value::undefined());
      });
}

jsi::Value RNGameController::setPlayerIndex(jsi::Runtime &rt,
                                            double controllerId, double index) {
  return createPromiseAsJSIValue(
      rt, [](jsi::Runtime &rt, std::shared_ptr<Promise> promise) {
        promise->resolve(jsi::Value::undefined());
      });
}

} // namespace facebook::react
