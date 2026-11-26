#import "GlintPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#define GLINT_APP_ID CFSTR("com.cocxace.glint")
#define GLINT_PREFS_VERSION 3
#define GLINT_RELOAD_NOTIFICATION CFSTR("com.cocxace.glint/reload")

#define GlintLog(fmt, ...) \
    do { if ([GlintPrefs debugEnabled]) \
        NSLog(@"[GlintPrefs] %@: " fmt, @(__PRETTY_FUNCTION__), ##__VA_ARGS__); } while (0)

static void (^gGlintReloadBlock)(void) = nil;

static void GlintReloadCallback(CFNotificationCenterRef center, void *observer,
                                CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    void (^block)(void) = (__bridge void (^)(void))observer;
    if (block) block();
}

@implementation GlintPrefs {
    BOOL _debugEnabled;
    NSInteger _prefsVersion;
}

+ (instancetype)sharedPrefs {
    static GlintPrefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
        [self registerDefaults];
        [self migratePrefsIfNeeded];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        CFDictionaryRef appPrefs = CFPreferencesCopyAppValue(GLINT_APP_ID, GLINT_APP_ID);
        if (appPrefs) {
            CFNumberRef ver = CFDictionaryGetValue(appPrefs, CFSTR("prefsVersion"));
            if (ver) CFNumberGetValue(ver, kCFNumberNSIntegerType, &_prefsVersion);
            CFBooleanRef dbg = CFDictionaryGetValue(appPrefs, CFSTR("glintDebug"));
            if (dbg) _debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(appPrefs);
        }
    }
    return self;
}

+ (void)registerDefaults {
    NSDictionary *defs = @{
        @"prefsVersion": @(GLINT_PREFS_VERSION),
        @"enableGlint": @(YES),
        @"glintShowNotifications": @(YES),
        @"glintShowCharging": @(YES),
        @"glintShowMusic": @(YES),
        @"glintShowTorch": @(YES),
        @"glintShowTimer": @(YES),
        @"glintShowArtwork": @(YES),
        @"glintBeatPulse": @(YES),
        @"glintGlowEnabled": @(YES),
        @"glintGlowStrength": @(55.f),
        @"glintGlowRadius": @(14.f),
        @"glintGlowSpeed": @(5.f),
        @"glintGlowHue": @(190.f),
        @"glintGlowHue2": @(258.f),
        @"glintGlowRainbow": @(NO),
        @"glintGlowBlink": @(NO),
        @"glintPosition": @"top",
        @"glintCornerRadius": @(16.f),
        @"glintExpandedHeight": @(140.f),
        @"glintSpringStiffness": @(200.f),
        @"glintSpringDamping": @(18.f),
        @"glintAutoCollapseDelay": @(4.f),
        @"glintHapticOnTap": @(YES),
        @"glintDebug": @(NO)
    };
    for (NSString *key in defs) {
        if (CFPreferencesCopyAppValue((__bridge CFStringRef)key, GLINT_APP_ID) == NULL) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                     (__bridge CFPropertyListRef)defs[key], GLINT_APP_ID);
        }
    }
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
    CFPreferencesSetAppValue((__bridge CFStringRef)key, value ? kCFBooleanTrue : kCFBooleanFalse, GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFNumberRef)@(value), GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (void)setFloat:(CGFloat)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFNumberRef)@(value), GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (void)setString:(NSString *)value forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)value, GLINT_APP_ID);
    CFPreferencesAppSynchronize(GLINT_APP_ID);
    [self postReloadNotification];
}

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, GLINT_APP_ID);
    BOOL result = def;
    if (val && CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
    if (val) CFRelease(val);
    return result;
}

+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, GLINT_APP_ID);
    NSInteger result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberNSIntegerType, &result);
    if (val) CFRelease(val);
    return result;
}

+ (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, GLINT_APP_ID);
    CGFloat result = def;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)val, kCFNumberCGFloatType, &result);
    if (val) CFRelease(val);
    return result;
}

+ (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, GLINT_APP_ID);
    NSString *result = def;
    if (val && CFGetTypeID(val) == CFStringGetTypeID()) result = (__bridge NSString *)val;
    if (val) CFRelease(val);
    return result ? result : def;
}

+ (void)postReloadNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         GLINT_RELOAD_NOTIFICATION, NULL, NULL, YES);
}

+ (void)installDarwinReloadObserver:(void (^)(void))block {
    gGlintReloadBlock = block ? [block copy] : nil;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    (__bridge void *)gGlintReloadBlock,
                                    GlintReloadCallback,
                                    GLINT_RELOAD_NOTIFICATION,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (BOOL)debugEnabled { return _debugEnabled; }
- (NSInteger)prefsVersion { return _prefsVersion; }

+ (BOOL)debugEnabled { return [self sharedPrefs].debugEnabled; }
+ (NSInteger)prefsVersion { return [self sharedPrefs].prefsVersion; }

@end
