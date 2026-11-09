#import "LuminaPrefs.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreFoundation/CoreFoundation.h>

#define LUMINA_APP_ID CFSTR("com.cocxace.lumina")
#define LUMINA_RELOAD_NOTIFICATION CFSTR("com.cocxace.lumina/reload")

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
    CFPreferencesSetAppValue(CFSTR("enabled"), kCFBooleanTrue, LUMINA_APP_ID);
    CFPreferencesSetAppValue(CFSTR("showDate"), kCFBooleanTrue, LUMINA_APP_ID);
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

+ (BOOL)debugEnabled { return [self sharedPrefs]->_debugEnabled; }

@end
