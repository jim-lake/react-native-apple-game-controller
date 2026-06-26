#pragma once

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <atomic>
#include <string>
#include <unordered_map>

namespace facebook::react {
class RNGameController;
}

// MARK: - Controller State

static constexpr int kMaxAnalog = 6;

struct ControllerState {
  std::atomic<float> analog[kMaxAnalog];
  std::atomic<uint32_t> buttons{0};
  std::atomic<double> lastUpdated{0};
};

// MARK: - Controller Entry

struct ControllerEntry {
  std::string controllerId; // UUID string
  __strong GCController *controller;
  ControllerState state;
  int analogCount;
  NSArray<NSDictionary *> *buttonInfos;
  NSArray<NSDictionary *> *axisInfos;
  NSArray<NSDictionary *> *dpadInfos;
};

// MARK: - Singleton Helper

@interface RNGameControllerHelper : NSObject

@property(nonatomic, assign) facebook::react::RNGameController *module;

+ (instancetype)shared;

- (ControllerEntry *)findEntryById:(const std::string &)controllerId;
- (ControllerEntry *)findEntryByController:(GCController *)controller;
- (NSArray<NSValue *> *)entries;

@end

void setupNotifications(void);
