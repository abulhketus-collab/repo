#import "AB12Prefs.h"
#import "AB12Common.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define AB12_PREFS_VERSION 2

#define AB12Log(fmt, ...) \
    do { if ([AB12Prefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[ActionButton12] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

@implementation AB12Prefs {
    BOOL _debugEnabled;
    NSInteger _prefsVersion;
}

+ (instancetype)sharedPrefs {
    static AB12Prefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
        [self registerDefaults];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        CFDictionaryRef appPrefs = CFPreferencesCopyAppValue(AB12_APP_ID, AB12_APP_ID);
        if (appPrefs) {
            CFNumberRef ver = CFDictionaryGetValue(appPrefs, CFSTR("prefsVersion"));
            if (ver) CFNumberGetValue(ver, kCFNumberNSIntegerType, &_prefsVersion);
            CFBooleanRef dbg = CFDictionaryGetValue(appPrefs, CFSTR("actionbutton12Debug"));
            if (dbg) _debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(appPrefs);
        }
    }
    return self;
}

+ (void)registerDefaults {
    NSDictionary *defs = @{
        @"prefsVersion": @(AB12_PREFS_VERSION),
        @"enabled": @(YES),
        @"trigger": @(0),
        @"showSliders": @(YES),
        @"disableTorch": @(NO),
        @"disableCamera": @(NO),
        @"disableVoiceMemos": @(NO),
        @"disableScreenshot": @(NO),
        @"disableWiFi": @(NO),
        @"disableBluetooth": @(NO),
        @"haptics": @(YES),
        @"actionbutton12Debug": @(NO)
    };
    for (NSString *key in defs) {
        if (CFPreferencesCopyAppValue((__bridge CFStringRef)key, AB12_APP_ID) == NULL) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                     (__bridge CFPropertyListRef)defs[key], AB12_APP_ID);
        }
    }
    CFPreferencesAppSynchronize(AB12_APP_ID);
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, value ? kCFBooleanTrue : kCFBooleanFalse, AB12_APP_ID);
    CFPreferencesAppSynchronize(AB12_APP_ID);
    [self postReloadNotification];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFNumberRef)@(value), AB12_APP_ID);
    CFPreferencesAppSynchronize(AB12_APP_ID);
    [self postReloadNotification];
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, AB12_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, AB12_APP_ID);
    NSInteger result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberNSIntegerType, &result);
    if (val) CFRelease(val);
    return result;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         AB12_RELOAD_NOTIFICATION, NULL, NULL, YES);
}

- (BOOL)debugEnabled { return _debugEnabled; }
- (NSInteger)prefsVersion { return _prefsVersion; }

+ (BOOL)debugEnabled { return [self sharedPrefs].debugEnabled; }
+ (NSInteger)prefsVersion { return [self sharedPrefs].prefsVersion; }

@end
