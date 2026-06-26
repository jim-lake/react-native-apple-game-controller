#pragma once

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <atomic>
#include <jsi/jsi.h>

namespace facebook::react {
class RNGameController;
}

@interface RNGCMouseHelper : NSObject

@property(nonatomic, assign) facebook::react::RNGameController *module;
@property(nonatomic, assign) bool buttonEventsEnabled;
@property(nonatomic, assign) bool moveEventsEnabled;
@property(nonatomic, assign) bool deltaCollectEnabled;

+ (instancetype)shared;
- (void)start;
- (void)stop;
- (void)setButtonCallback:(std::shared_ptr<facebook::jsi::Function>)callback;
- (std::shared_ptr<facebook::jsi::Function>)clearButtonCallback;
- (void)setMoveCallback:(std::shared_ptr<facebook::jsi::Function>)callback;
- (std::shared_ptr<facebook::jsi::Function>)clearMoveCallback;
- (void)getDeltaAndReset:(int32_t *)outX y:(int32_t *)outY;

@end
