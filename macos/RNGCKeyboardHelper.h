#pragma once

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <jsi/jsi.h>
#include <optional>

namespace facebook::react {
class RNGameController;
}

@interface RNGCKeyboardHelper : NSObject

@property(nonatomic, assign) facebook::react::RNGameController *module;
@property(nonatomic, assign) bool eventsEnabled;

+ (instancetype)shared;
- (void)start;
- (void)stop;
- (void)setCallback:(std::shared_ptr<facebook::jsi::Function>)callback;
- (std::shared_ptr<facebook::jsi::Function>)clearCallback;

@end
