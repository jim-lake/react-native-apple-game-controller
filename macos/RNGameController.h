#pragma once

#include "RNGameControllerSpecJSI.h"
#include <ReactCommon/TurboModuleUtils.h>
#include <string>

namespace facebook::react {

// Type aliases for codegen structs
using ControllerButtonEventStruct =
    NativeGameControllerControllerButtonEvent<std::string, double, double>;
using KeyboardEventStruct = NativeGameControllerKeyboardEvent<double, bool>;
using MouseButtonEventStruct =
    NativeGameControllerMouseButtonEvent<double, bool>;
using MouseMoveEventStruct = NativeGameControllerMouseMoveEvent<double, double>;

// Bridging for ControllerButtonEvent
template <> struct Bridging<ControllerButtonEventStruct> {
  static ControllerButtonEventStruct
  fromJs(jsi::Runtime &rt, const jsi::Object &value,
         const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerControllerButtonEventBridging<
        ControllerButtonEventStruct>::fromJs(rt, value, jsInvoker);
  }
  static jsi::Object toJs(jsi::Runtime &rt,
                          const ControllerButtonEventStruct &value,
                          const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerControllerButtonEventBridging<
        ControllerButtonEventStruct>::toJs(rt, value, jsInvoker);
  }
};

// Bridging for KeyboardEvent
template <> struct Bridging<KeyboardEventStruct> {
  static KeyboardEventStruct
  fromJs(jsi::Runtime &rt, const jsi::Object &value,
         const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerKeyboardEventBridging<
        KeyboardEventStruct>::fromJs(rt, value, jsInvoker);
  }
  static jsi::Object toJs(jsi::Runtime &rt, const KeyboardEventStruct &value,
                          const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerKeyboardEventBridging<KeyboardEventStruct>::toJs(
        rt, value, jsInvoker);
  }
};

// Bridging for MouseButtonEvent
template <> struct Bridging<MouseButtonEventStruct> {
  static MouseButtonEventStruct
  fromJs(jsi::Runtime &rt, const jsi::Object &value,
         const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerMouseButtonEventBridging<
        MouseButtonEventStruct>::fromJs(rt, value, jsInvoker);
  }
  static jsi::Object toJs(jsi::Runtime &rt, const MouseButtonEventStruct &value,
                          const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerMouseButtonEventBridging<
        MouseButtonEventStruct>::toJs(rt, value, jsInvoker);
  }
};

// Bridging for MouseMoveEvent
template <> struct Bridging<MouseMoveEventStruct> {
  static MouseMoveEventStruct
  fromJs(jsi::Runtime &rt, const jsi::Object &value,
         const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerMouseMoveEventBridging<
        MouseMoveEventStruct>::fromJs(rt, value, jsInvoker);
  }
  static jsi::Object toJs(jsi::Runtime &rt, const MouseMoveEventStruct &value,
                          const std::shared_ptr<CallInvoker> &jsInvoker) {
    return NativeGameControllerMouseMoveEventBridging<
        MouseMoveEventStruct>::toJs(rt, value, jsInvoker);
  }
};

class RNGameController : public NativeGameControllerCxxSpec<RNGameController> {
public:
  RNGameController(std::shared_ptr<CallInvoker> jsInvoker);
  ~RNGameController();

  // Promote emit methods to public
  using NativeGameControllerCxxSpec<
      RNGameController>::emitOnControllerConnected;
  using NativeGameControllerCxxSpec<
      RNGameController>::emitOnControllerDisconnected;
  using NativeGameControllerCxxSpec<
      RNGameController>::emitOnControllerCurrentChange;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnControllerButton;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnKeyboardConnected;
  using NativeGameControllerCxxSpec<
      RNGameController>::emitOnKeyboardDisconnected;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnMouseConnected;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnMouseDisconnected;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnKeyboardEvent;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnMouseButton;
  using NativeGameControllerCxxSpec<RNGameController>::emitOnMouseMoveEvent;

  // Spec methods
  jsi::Value getControllers(jsi::Runtime &rt);
  jsi::Object getControllerState(jsi::Runtime &rt, jsi::String controllerId);
  jsi::Value hasKeyboard(jsi::Runtime &rt);
  jsi::Value hasMouse(jsi::Runtime &rt);
  void registerControllerEventCallback(jsi::Runtime &rt,
                                       std::optional<jsi::Function> callback);
  void registerKeyboardEventCallback(jsi::Runtime &rt,
                                     std::optional<jsi::Function> callback);
  void registerMouseButtonEventCallback(jsi::Runtime &rt,
                                        std::optional<jsi::Function> callback);
  void registerMouseMoveEventCallback(jsi::Runtime &rt,
                                      std::optional<jsi::Function> callback);
  jsi::Value _startControllerCapture(jsi::Runtime &rt);
  jsi::Value stopControllerCapture(jsi::Runtime &rt);
  void toggleMouseMoveDeltaCollect(jsi::Runtime &rt, bool enable);
  void getMouseMoveDeltaAndReset(jsi::Runtime &rt, jsi::Object deltas);
  void toggleControllerCurrentEvents(jsi::Runtime &rt, bool enable);
  void toggleControllerButtonEvents(jsi::Runtime &rt, bool enable);
  void toggleKeyboardEvents(jsi::Runtime &rt, bool enable);
  void toggleMouseButtonEvents(jsi::Runtime &rt, bool enable);
  void toggleMouseMoveEvents(jsi::Runtime &rt, bool enable);
  jsi::Value setLightColor(jsi::Runtime &rt, jsi::String controllerId, double r,
                           double g, double b);
  jsi::Value setPlayerIndex(jsi::Runtime &rt, jsi::String controllerId,
                            double index);
  jsi::Value shouldMonitorBackgroundEvents(jsi::Runtime &rt, bool enable);

  std::shared_ptr<CallInvoker> jsInvoker_;
  bool buttonEventsEnabled_{false};
};

} // namespace facebook::react
