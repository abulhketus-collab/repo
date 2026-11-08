#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GlintPrefs : NSObject

+ (instancetype)sharedPrefs;

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def;
+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def;
+ (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def;
+ (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)def;

+ (void)setBool:(BOOL)value forKey:(NSString *)key;
+ (void)setInteger:(NSInteger)value forKey:(NSString *)key;
+ (void)setFloat:(CGFloat)value forKey:(NSString *)key;
+ (void)setString:(NSString *)value forKey:(NSString *)key;

+ (void)registerDefaults;
+ (void)migratePrefsIfNeeded;

+ (void)postReloadNotification;
+ (void)installDarwinReloadObserver:(void (^)(void))block;

@property (nonatomic, assign, readonly) BOOL debugEnabled;
@property (nonatomic, assign, readonly) NSInteger prefsVersion;

@end

NS_ASSUME_NONNULL_END