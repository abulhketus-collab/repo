#import "LuminaPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define LUMINA_APP_ID CFSTR("com.cocxace.lumina")
#define LUMINA_RELOAD_NOTIFICATION CFSTR("com.cocxace.lumina/reload")

static const char *kLuminaLog = "Lumina";
#define LuminaLog(fmt, ...)     do { if ([LuminaPrefs sharedPrefs].debugEnabled)         os_log(OS_LOG_DEFAULT, "[Lumina] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

@implementation LuminaPrefs {
    BOOL _debugEnabled;
}

+ (instancetype)sharedPrefs {
    static LuminaPrefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

+ (void)registerDefaults {
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    [defs setObject:@(YES) forKey:@"enabled"];
    [defs setObject:@(0.90) forKey:@"opacity"];
    [defs setObject:@(YES) forKey:@"showDate"];
    [defs setObject:@(NO) forKey:@"luminaDebug"];
    CFPreferencesSetAppValues((CFDictionaryRef)defs, LUMINA_APP_ID);
    CFPreferencesAppSynchronize(LUMINA_APP_ID);
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, LUMINA_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, LUMINA_APP_ID);
    CGFloat result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberCGFloatType, &result);
    if (val) CFRelease(val);
    return result;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         LUMINA_RELOAD_NOTIFICATION, NULL, NULL, true);
}

+ (BOOL)debugEnabled { return _debugEnabled; }

@end