#pragma once

#include "RNGameControllerSpecJSI.h"
#include <ReactCommon/TurboModuleUtils.h>

namespace facebook::react {

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
};

} // namespace facebook::react
