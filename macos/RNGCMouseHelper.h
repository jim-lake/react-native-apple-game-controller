#pragma once

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

namespace facebook::react {
class RNGameController;
}

@interface RNGCMouseHelper : NSObject

@property(nonatomic, assign) facebook::react::RNGameController *module;

+ (instancetype)shared;
- (void)start;
- (void)stop;

@end
