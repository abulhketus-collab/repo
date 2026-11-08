#import "AuraPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define AURA_APP_ID CFSTR("com.cocxace.aura")
#define AURA_PREFS_VERSION 2
#define AURA_RELOAD_NOTIFICATION CFSTR("com.cocxace.aura/reload")

static const char *kAuraLog = "Aura";
#define AuraLog(fmt, ...)     do { if ([AuraPrefs sharedPrefs].debugEnabled)         os_log(OS_LOG_DEFAULT, "[Aura] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

@implementation AuraPrefs {
    BOOL _debugEnabled;
    NSInteger _prefsVersion;
}

+ (instancetype)sharedPrefs {
    static AuraPrefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
        [s registerDefaults];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        CFDictionaryRef appPrefs = CFPreferencesCopyAppValue(AURA_APP_ID, AURA_APP_ID);
        if (appPrefs) {
            CFNumberRef ver = CFDictionaryGetValue(appPrefs, CFSTR("prefsVersion"));
            if (ver) CFNumberGetValue(ver, kCFNumberNSInteger, &_prefsVersion);
            CFBooleanRef dbg = CFDictionaryGetValue(appPrefs, CFSTR("auraDebug"));
            if (dbg) _debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(appPrefs);
        }
    }
    return self;
}

+ (void)registerDefaults {
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    [defs setObject:@(AURA_PREFS_VERSION) forKey:@"prefsVersion"];
    [defs setObject:@(YES) forKey:@"enabled"];
    [defs setObject:@(0) forKey:@"trigger"];
    [defs setObject:@(YES) forKey:@"showSliders"];
    [defs setObject:@(NO) forKey:@"disableTorch"];
    [defs setObject:@(NO) forKey:@"disableCamera"];
    [defs setObject:@(NO) forKey:@"disableVoiceMemos"];
    [defs setObject:@(NO) forKey:@"disableScreenshot"];
    [defs setObject:@(YES) forKey:@"haptics"];
    [defs setObject:@(NO) forKey:@"auraDebug"];
    CFPreferencesSetAppValues((CFDictionaryRef)defs, AURA_APP_ID);
    CFPreferencesAppSynchronize(AURA_APP_ID);
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, value ? kCFBooleanTrue : kCFBooleanFalse, AURA_APP_ID);
    CFPreferencesAppSynchronize(AURA_APP_ID);
    [self postReloadNotification];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, CFNumberCreate(kCFAllocatorDefault, kCFNumberNSInteger, &value), AURA_APP_ID);
    CFPreferencesAppSynchronize(AURA_APP_ID);
    [self postReloadNotification];
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, AURA_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, AURA_APP_ID);
    NSInteger result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberNSInteger, &result);
    if (val) CFRelease(val);
    return result;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         AURA_RELOAD_NOTIFICATION, NULL, NULL, true);
}

+ (BOOL)debugEnabled { return [self sharedPrefs]->_debugEnabled; }
+ (NSInteger)prefsVersion { return [self sharedPrefs]->_prefsVersion; }

@end