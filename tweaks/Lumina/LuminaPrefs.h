#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface LuminaPrefs : NSObject

+ (instancetype)sharedPrefs;
+ (void)registerDefaults;

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def;
+ (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def;

+ (void)postReloadNotification;

@property (nonatomic, assign, readonly) BOOL debugEnabled;

@end

NS_ASSUME_NONNULL_END