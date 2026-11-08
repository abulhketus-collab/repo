#import "AB12Prefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define AB12_PREFS_VERSION 2

static const char *kAB12Log = "ActionButton12";

#define AB12Log(fmt, ...) \
    do { if ([AB12Prefs sharedPrefs].debugEnabled) \
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
        [s registerDefaults];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        CFDictionaryRef appPrefs = CFPreferencesCopyAppValue(AB12_APP_ID, AB12_APP_ID);
        if (appPrefs) {
            CFNumberRef ver = CFDictionaryGetValue(appPrefs, CFSTR("prefsVersion"));
            if (ver) CFNumberGetValue(ver, kCFNumberNSInteger, &_prefsVersion);
            CFBooleanRef dbg = CFDictionaryGetValue(appPrefs, CFSTR("actionbutton12Debug"));
            if (dbg) _debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(appPrefs);
        }
    }
    return self;
}

+ (void)registerDefaults {
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    [defs setObject:@(AB12_PREFS_VERSION) forKey:@"prefsVersion"];
    [defs setObject:@(YES) forKey:@"enabled"];
    [defs setObject:@(0) forKey:@"trigger"];
    [defs setObject:@(YES) forKey:@"showSliders"];
    [defs setObject:@(NO) forKey:@"disableTorch"];
    [defs setObject:@(NO) forKey:@"disableCamera"];
    [defs setObject:@(NO) forKey:@"disableVoiceMemos"];
    [defs setObject:@(NO) forKey:@"disableScreenshot"];
    [defs setObject:@(NO) forKey:@"disableWiFi"];
    [defs setObject:@(NO) forKey:@"disableBluetooth"];
    [defs setObject:@(YES) forKey:@"haptics"];
    [defs setObject:@(NO) forKey:@"actionbutton12Debug"];
    CFPreferencesSetAppValues((CFDictionaryRef)defs, AB12_APP_ID);
    CFPreferencesAppSynchronize(AB12_APP_ID);
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, value ? kCFBooleanTrue : kCFBooleanFalse, AB12_APP_ID);
    CFPreferencesAppSynchronize(AB12_APP_ID);
    [self postReloadNotification];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, CFNumberCreate(kCFAllocatorDefault, kCFNumberNSInteger, &value), AB12_APP_ID);
    CFPreferencesAppSynchronize(AB12_APP_ID);
    [self postReloadNotification];
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, AB12_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, AB12_APP_ID);
    NSInteger result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberNSInteger, &result);
    if (val) CFRelease(val);
    return result;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         AB12_RELOAD_NOTIFICATION, NULL, NULL, true);
}

+ (BOOL)debugEnabled { return [self sharedPrefs]->_debugEnabled; }
+ (NSInteger)prefsVersion { return [self sharedPrefs]->_prefsVersion; }

@end
