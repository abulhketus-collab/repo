#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GlintPowerObserver : NSObject

+ (void)install;
+ (void)uninstall;
+ (BOOL)isCharging;
+ (CGFloat)currentCapacity;

@end

NS_ASSUME_NONNULL_END