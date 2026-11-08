#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VoltPrefs : NSObject

+ (instancetype)sharedPrefs;
+ (void)registerDefaults;
+ (BOOL)debugEnabled;

@end

NS_ASSUME_NONNULL_END