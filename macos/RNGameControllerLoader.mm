#include "RNGameController.h"
#import <Foundation/Foundation.h>
#include <ReactCommon/CxxTurboModuleUtils.h>

@interface RNGameControllerLoader : NSObject
@end

@implementation RNGameControllerLoader

+ (void)load {
  facebook::react::registerCxxModuleToGlobalModuleMap(
      "GameControllerModule",
      [](std::shared_ptr<facebook::react::CallInvoker> jsInvoker) {
        return std::make_shared<facebook::react::RNGameController>(
            std::move(jsInvoker));
      });
}

@end
