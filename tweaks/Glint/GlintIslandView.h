#import <UIKit/UIKit.h>

// Glint — Dynamic Island for iOS 12 notchless devices.
// UI engine: a black pill window that expands like the real Dynamic Island.
// All methods must be called on the main thread (they dispatch there themselves).

@interface GlintIsland : NSObject

+ (instancetype)shared;

// Creates the island window. Safe to call multiple times; meant to run shortly
// after SpringBoard -applicationDidFinishLaunching: to avoid boot crashes.
- (void)setup;

- (BOOL)isSetup;

// Notification-style event: island bounces open for a few seconds, then collapses.
- (void)showEventForApp:(NSString *)appName
                 bundle:(NSString *)bundleID
                  glyph:(NSString *)glyph
                   icon:(UIImage *)icon
                  title:(NSString *)title
                message:(NSString *)message;

// Charging pill (real DI style: appears when the charger is plugged).
- (void)showChargingAtLevel:(NSInteger)levelPercent;

// Torch indicator.
- (void)showTorchOn:(BOOL)on;

// Now playing expand.
- (void)showNowPlayingTrack:(NSString *)track artist:(NSString *)artist;

// Boot "hello" (marks version online, proves pipeline works).
- (void)showBootGreeting;

// Small music note inside the collapsed pill while audio plays.
- (void)setNowPlayingActive:(BOOL)active;
- (BOOL)isNowPlayingActive;

// Fallback tap when there is nothing to open: subtle heartbeat pulse.
- (void)playIdleTapPulse;

@end
