#import "RNGCMouseHelper.h"
#import "RNGameController.h"
#import <GameController/GameController.h>

@implementation RNGCMouseHelper {
  id _connectObserver;
  id _disconnectObserver;
}

+ (instancetype)shared {
  static RNGCMouseHelper *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[RNGCMouseHelper alloc] init];
  });
  return instance;
}

- (void)start {
  _connectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCMouseDidConnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                if (self.module) {
                  self.module->emitOnMouseConnected();
                }
              }];

  _disconnectObserver = [[NSNotificationCenter defaultCenter]
      addObserverForName:GCMouseDidDisconnectNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
                if (self.module) {
                  self.module->emitOnMouseDisconnected();
                }
              }];
}

- (void)stop {
  if (_connectObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_connectObserver];
    _connectObserver = nil;
  }
  if (_disconnectObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_disconnectObserver];
    _disconnectObserver = nil;
  }
}

@end
