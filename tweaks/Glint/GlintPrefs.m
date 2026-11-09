#import "GlintPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define GLINT_APP_ID CFSTR("com.cocxace.glint")
#define GLINT_PREFS_VERSION 3
#define GLINT_RELOAD_NOTIFICATION CFSTR("com.cocxace.glint/reload")

static const char *kGlintLog = "Glint";

#define GlintLog(fmt, ...) \
    do { if ([GlintPrefs sharedPrefs].debugEnabled) \
        os_log(OS_LOG_DEFAULT, "[Glint] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

@implementation GlintPrefs {
    BOOL _debugEnabled;
    NSInteger _prefsVersion;
}

+ (instancetype)sharedPrefs {
    static GlintPrefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
        [s registerDefaults];
        [s migratePrefsIfNeeded];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        CFDictionaryRef appPrefs = CFPreferencesCopyAppValue(GLINT_APP_ID, GLINT_APP_ID);
        if (appPrefs) {
            CFNumberRef ver = CFDictionaryGetValue(appPrefs, CFSTR("prefsVersion"));
            if (ver) CFNumberGetValue(ver, kCFNumberNSInteger, &_prefsVersion);
            CFBooleanRef dbg = CFDictionaryGetValue(appPrefs, CFSTR("glintDebug"));
            if (dbg) _debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(appPrefs);
        }
    }
    return self;
}

+ (void)registerDefaults {
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    [defs setObject:@(GLINT_PREFS_VERSION) forKey:@"prefsVersion"];
    [defs setObject:@(YES) forKey:@"enableGlint"];
    [defs setObject:@(YES) forKey:@"glintShowNotifications"];
    [defs setObject:@(YES) forKey:@"glintShowCharging"];
    [defs setObject:@(YES) forKey:@"glintShowMusic"];
    [defs setObject:@(YES) forKey:@"glintShowTorch"];
    // v1.2.3: timer, artwork, beat pulse, glow engine
    [defs setObject:@(YES) forKey:@"glintShowTimer"];
    [defs setObject:@(YES) forKey:@"glintShowArtwork"];
    [defs setObject:@(YES) forKey:@"glintBeatPulse"];
    [defs setObject:@(YES) forKey:@"glintGlowEnabled"];
    [defs setObject:@(55.f) forKey:@"glintGlowStrength"];
    [defs setObject:@(14.f) forKey:@"glintGlowRadius"];
    [defs setObject:@(5.f)  forKey:@"glintGlowSpeed"];
    [defs setObject:@(190.f) forKey:@"glintGlowHue"];
    [defs setObject:@(258.f) forKey:@"glintGlowHue2"];
    [defs setObject:@(NO) forKey:@"glintGlowRainbow"];
    [defs setObject:@(NO) forKey:@"glintGlowBlink"];
    [defs setObject:@"top" forKey:@"glintPosition"];
    [defs setObject:@(16.f) forKey:@"glintCornerRadius"];
    [defs setObject:@(140.f) forKey:@"glintExpandedHeight"];
    [defs setObject:@(200.f) forKey:@"glintSpringStiffness"];
    [defs setObject:@(18.f) forKey:@"glintSpringDamping"];
    [defs setObject:@(4.f) forKey:@"glintAutoCollapseDelay"];
    [defs setObject:@(YES) forKey:@"glintHapticOnTap"];
    [defs setObject:@(NO) forKey:@"glintDebug"];
    CFPreferencesSetAppValues((CFDictionaryRef)defs, GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
}

+ (void)migratePrefsIfNeeded {
    GlintPrefs *p = [self sharedPrefs];
    if (p->_prefsVersion < GLINT_PREFS_VERSION) {
        GlintLog(@"migrating prefs from %ld to %ld", (long)p->_prefsVersion, (long)GLINT_PREFS_VERSION);
        [self setInteger:GLINT_PREFS_VERSION forKey:@"prefsVersion"];
    }
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, value ? kCFBooleanTrue : kCFBooleanFalse, GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, CFNumberCreate(kCFAllocatorDefault, kCFNumberNSInteger, &value), GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (void)setFloat:(CGFloat)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &value), GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (void)setString:(NSString *)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((CFStringRef)key, (__bridge CFStringRef)value, GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, GLINT_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, GLINT_APP_ID);
    NSInteger result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberNSInteger, &result);
    if (val) CFRelease(val);
    return result;
}

+ (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, GLINT_APP_ID);
    CGFloat result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberCGFloatType, &result);
    if (val) CFRelease(val);
    return result;
}

+ (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)def {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, GLINT_APP_ID);
    NSString *result = def;
    if (val && CFGetTypeID(val) == CFStringGetTypeID()) result = (__bridge NSString *)val;
    if (val) CFRelease(val);
    return result ? result : def;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         GLINT_RELOAD_NOTIFICATION, NULL, NULL, true);
}

+ (void)installDarwinReloadObserver:(void (^)(void))block {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    (__bridge void *)block,
                                    GLINT_RELOAD_NOTIFICATION,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

+ (BOOL)debugEnabled { return [self sharedPrefs]->_debugEnabled; }
+ (NSInteger)prefsVersion { return [self sharedPrefs]->_prefsVersion; }

@end
