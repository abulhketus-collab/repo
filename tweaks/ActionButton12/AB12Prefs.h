#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AB12Prefs : NSObject

+ (instancetype)sharedPrefs;

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def;
+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def;

+ (void)setBool:(BOOL)value forKey:(NSString *)key;
+ (void)setInteger:(NSInteger)value forKey:(NSString *)key;

+ (void)registerDefaults;
+ (void)postReloadNotification;

@property (nonatomic, assign, readonly) BOOL debugEnabled;
@property (nonatomic, assign, readonly) NSInteger prefsVersion;

@end

NS_ASSUME_NONNULL_END
