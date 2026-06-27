#pragma once

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <atomic>
#include <jsi/jsi.h>

namespace facebook::react {
class RNGameController;
}

// Global mouse delta accumulators and polling function
extern std::atomic<int32_t> g_mouseDeltaX;
extern std::atomic<int32_t> g_mouseDeltaY;
inline void getMouseMoveDeltaAndReset(int32_t deltas[2]) {
  deltas[0] = g_mouseDeltaX.exchange(0, std::memory_order_relaxed);
  deltas[1] = g_mouseDeltaY.exchange(0, std::memory_order_relaxed);
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

@end
