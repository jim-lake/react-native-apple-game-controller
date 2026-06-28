#pragma once

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <atomic>
#include <jsi/jsi.h>
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
  std::atomic<uint32_t> lastCallbackButtons{0};
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
@property(nonatomic, assign) bool buttonEventsEnabled;

+ (instancetype)shared;
- (void)start;
- (void)stop;
- (void)toggleCurrentEvents:(bool)enable;
- (ControllerEntry *)findEntryById:(const std::string &)controllerId;
- (const std::unordered_map<std::string, ControllerEntry *> &)entries;
- (void)setEventCallback:(std::shared_ptr<facebook::jsi::Function>)callback;
- (std::shared_ptr<facebook::jsi::Function>)clearEventCallback;

@end
