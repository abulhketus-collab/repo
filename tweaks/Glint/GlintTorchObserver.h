#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GlintTorchObserver : NSObject

+ (void)install;
+ (void)uninstall;
+ (BOOL)hasTorch;
+ (BOOL)isTorchOn;
+ (void)setTorchOn:(BOOL)on;

@end

NS_ASSUME_NONNULL_END