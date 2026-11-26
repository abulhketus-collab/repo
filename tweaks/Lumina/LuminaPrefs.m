#import "LuminaPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define LUMINA_APP_ID CFSTR("com.cocxace.lumina")
#define LUMINA_RELOAD_NOTIFICATION CFSTR("com.cocxace.lumina/reload")

#define LuminaLog(fmt, ...) \
    do { if ([LuminaPrefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[Lumina] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

@implementation LuminaPrefs {
    BOOL _debugEnabled;
}

+ (instancetype)sharedPrefs {
    static LuminaPrefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
        CFBooleanRef dbg = CFPreferencesCopyAppValue(CFSTR("luminaDebug"), LUMINA_APP_ID);
        if (dbg) {
            s->_debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(dbg);
        }
    });
    return s;
}

+ (void)registerDefaults {
    NSDictionary *defs = @{
        @"enabled": @(YES),
        @"opacity": @(0.90),
        @"showDate": @(YES),
        @"luminaDebug": @(NO)
    };
    for (NSString *key in defs) {
        if (CFPreferencesCopyAppValue((__bridge CFStringRef)key, LUMINA_APP_ID) == NULL) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                     (__bridge CFPropertyListRef)defs[key], LUMINA_APP_ID);
        }
    }
    CFPreferencesAppSynchronize(LUMINA_APP_ID);
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, LUMINA_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, LUMINA_APP_ID);
    CGFloat result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberCGFloatType, &result);
    if (val) CFRelease(val);
    return result;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         LUMINA_RELOAD_NOTIFICATION, NULL, NULL, YES);
}

- (BOOL)debugEnabled { return _debugEnabled; }

+ (BOOL)debugEnabled { return [self sharedPrefs].debugEnabled; }

@end
