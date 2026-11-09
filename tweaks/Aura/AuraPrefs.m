#import "AuraPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define AURA_APP_ID CFSTR("com.cocxace.aura")
#define AURA_PREFS_VERSION 2
#define AURA_RELOAD_NOTIFICATION CFSTR("com.cocxace.aura/reload")

static const char *kAuraLog = "Aura";

#define AuraLog(fmt, ...) \
    do { if ([AuraPrefs sharedPrefs].debugEnabled) \
        os_log(OS_LOG_DEFAULT, "[Aura] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

// v1.2.3: preset expansion + reset handling on the Darwin reload notification
static void AuraDarwinCallback(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
        NSInteger preset = -1;
        CFTypeRef pr = CFPreferencesCopyAppValue(CFSTR("preset"), AURA_APP_ID);
        if (pr) {
            if (CFGetTypeID(pr) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)pr, kCFNumberNSIntegerType, &preset);
            CFRelease(pr);
        }
        if (preset == 0) {       // All Tools
            NSDictionary *defs = @{ @"enabled": @(YES), @"trigger": @(2),
                                    @"disableTorch": @(NO), @"disableCamera": @(NO),
                                    @"disableVoiceMemos": @(NO), @"disableScreenshot": @(NO),
                                    @"haptics": @(YES) };
            for (NSString *k in defs) CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], AURA_APP_ID);
            CFPreferencesAppSynchronize(AURA_APP_ID);
        } else if (preset == 1) { // Quick Tools
            NSDictionary *defs = @{ @"enabled": @(YES), @"trigger": @(2),
                                    @"disableVoiceMemos": @(YES), @"haptics": @(YES) };
            for (NSString *k in defs) CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], AURA_APP_ID);
            CFPreferencesAppSynchronize(AURA_APP_ID);
        }

        CFTypeRef rst = CFPreferencesCopyAppValue(CFSTR("resetDefaults"), AURA_APP_ID);
        BOOL doReset = NO;
        if (rst) {
            if (CFGetTypeID(rst) == CFBooleanGetTypeID()) doReset = CFBooleanGetValue((CFBooleanRef)rst);
            CFRelease(rst);
        }
        if (doReset) {
            NSDictionary *defs = @{ @"prefsVersion": @(AURA_PREFS_VERSION), @"enabled": @(YES),
                                    @"trigger": @(0), @"showSliders": @(YES),
                                    @"disableTorch": @(NO), @"disableCamera": @(NO),
                                    @"disableVoiceMemos": @(NO), @"disableScreenshot": @(NO),
                                    @"haptics": @(YES), @"preset": @(-1), @"auraDebug": @(NO) };
            for (NSString *k in defs) CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], AURA_APP_ID);
            CFPreferencesSetAppValue(CFSTR("resetDefaults"), kCFBooleanFalse, AURA_APP_ID);
            CFPreferencesAppSynchronize(AURA_APP_ID);
            os_log(OS_LOG_DEFAULT, "[Aura] defaults restored");
        }
    } @catch (NSException *e) { }
}

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
        // v1.2.3: listen for pref changes to apply presets / reset
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        AuraDarwinCallback,
                                        AURA_RELOAD_NOTIFICATION,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
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
