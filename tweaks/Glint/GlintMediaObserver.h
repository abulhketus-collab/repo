#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GlintMediaObserver : NSObject

+ (void)install;
+ (void)uninstall;
+ (NSDictionary *)currentNowPlayingInfo;

@end

NS_ASSUME_NONNULL_END