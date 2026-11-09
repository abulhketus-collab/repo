#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// v1.2.3: system countdown timer (Clock app) mirrored in the island.
// Reads the mobiletimerd preference domain (safe, read-only) and exposes
// the remaining seconds; GlintStateManager drives the island from it.
@interface GlintTimerModule : NSObject

+ (void)install;      // starts the 1 Hz poll (main run loop)
+ (void)uninstall;    // stops the poll, clears island state
+ (NSInteger)remainingSeconds;  // -1 when no active timer

@end

NS_ASSUME_NONNULL_END
