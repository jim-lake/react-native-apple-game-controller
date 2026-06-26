#pragma once

#include "RNGameControllerSpecJSI.h"
#include <ReactCommon/TurboModuleUtils.h>
#include <mutex>

namespace facebook::react {

// Concrete type alias for the ButtonEvent struct
using ButtonEventStruct = NativeGameControllerButtonEvent<double, double>;

// Bridging specialization so emitOnGamepadButton works
template <> struct Bridging<ButtonEventStruct> {
  static ButtonEventStruct
  fromJs(jsi::Runtime &rt, const jsi::Object &value,
         const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerButtonEventBridging<ButtonEventStruct>::fromJs(
        rt, value, jsInvoker);
  }

  static jsi::Object toJs(jsi::Runtime &rt, const ButtonEventStruct &value,
                          const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerButtonEventBridging<ButtonEventStruct>::toJs(
        rt, value, jsInvoker);
  }
};

class RNGameController : public NativeGameControllerCxxSpec<RNGameController> {
public:
  RNGameController(std::shared_ptr<CallInvoker> jsInvoker);
  ~RNGameController();

  using NativeGameControllerCxxSpec<RNGameController>::emitOnConnected;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnDisconnected;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnGamepadButton;

  jsi::Value getControllers(jsi::Runtime &rt);
  jsi::Object getControllerState(jsi::Runtime &rt, double controllerId);
  void registerEventCallback(jsi::Runtime &rt,
                             std::optional<jsi::Function> callback);
  void toggleButtonEvents(jsi::Runtime &rt, bool enabled);
  jsi::Value setLightColor(jsi::Runtime &rt, double controllerId, double r,
                           double g, double b);
  jsi::Value setPlayerIndex(jsi::Runtime &rt, double controllerId,
                            double index);

  // Called from ObjC helper on main thread
  void handleConnect(int controllerId);
  void handleDisconnect(int controllerId);
  void handleButtonChange(int controllerId, uint32_t buttons);

  std::shared_ptr<CallInvoker> jsInvoker_;
  bool buttonEventsEnabled_{false};
  std::shared_ptr<jsi::Function> eventCallback_;
  std::mutex callbackMutex_;
};

} // namespace facebook::react
