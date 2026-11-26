#import <Foundation/Foundation.h>
#import "GlintState.h"

extern NSString *const GlintStateDidChangeNotification;

@interface GlintStateManager : NSObject

+ (instancetype)sharedManager;
- (void)setupIfEnabled;
- (void)tearDown;
- (void)addState:(GlintState *)state;
- (void)removeStateWithKey:(NSString *)key;
- (void)removeStatesOfType:(GlintStateType)type;
- (void)removeAllStates;
- (GlintState *)topState;
- (NSArray<GlintState *> *)allStates;
- (void)addNotificationBulletin:(id)bulletin;
- (void)removeNotificationWithSectionID:(NSString *)sectionID;
- (void)updateMusicState;
- (void)updatePowerState;
- (void)updateTorchState;
- (void)updateTimerState;
- (void)timerDidFinish;
- (BOOL)openBundleID:(NSString *)bundleID;

@end
