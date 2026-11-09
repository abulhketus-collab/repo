// Volt — battery percent color for iOS 12 (com.cocxace.volt)
// v1.2.2: CFPreferences instead of plist re-reads, live reload via darwin,
// division-by-zero guard at 0% / 100%, hex parse via NSScanner.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#import "VoltPrefs.h"

#define VoltLog(fmt, ...) \
    do { if ([VoltPrefs sharedPrefs].debugEnabled) \
        os_log(OS_LOG_DEFAULT, "[Volt] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

#pragma mark - Preferences

static float VoltNumber(NSString *key, float fallback) {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, CFSTR("com.cocxace.volt"));
    float result = fallback;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)val, kCFNumberCGFloatType, &result);
    }
    if (val) CFRelease(val);
    return result;
}

static NSInteger VoltChoice(NSString *key, NSInteger fallback) {
    CFTypeRef val = CFPreferencesCopyAppValue((CFStringRef)key, CFSTR("com.cocxace.volt"));
    NSInteger result = fallback;
    if (val && CFGetTypeID(val) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)val, kCFNumberNSInteger, &result);
    }
    if (val) CFRelease(val);
    return result;
}

typedef NS_ENUM(NSUInteger, VoltZone) {
    VoltZoneHigh = 0,
    VoltZoneMid = 1,
    VoltZoneLow = 2,
};

static UIColor *VoltColorForChoice(NSInteger choice) {
    switch (choice) {
        case 1: return [UIColor colorWithRed:1.0 green:0.82 blue:0.1 alpha:1.0];    // Yellow
        case 2: return [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1.0];   // Red
        case 3: return [UIColor colorWithRed:0.16 green:0.72 blue:0.8 alpha:1.0];   // Teal
        case 4: return [UIColor colorWithRed:1.0 green:0.45 blue:0.1 alpha:1.0];    // Orange
        case 5: return [UIColor colorWithRed:0.68 green:0.35 blue:0.9 alpha:1.0];   // Purple
        case 6: return [UIColor colorWithRed:0.2 green:0.55 blue:1.0 alpha:1.0];    // Blue
        case 7: return [UIColor colorWithRed:1.0 green:0.35 blue:0.7 alpha:1.0];    // Pink
        case 8: return [UIColor whiteColor];                                       // White
        case 0: default: return [UIColor colorWithRed:0.2 green:0.85 blue:0.35 alpha:1.0]; // Green
    }
}

static UIColor *VoltColorFromHex(NSString *raw, UIColor *fallback) {
    if (![raw isKindOfClass:[NSString class]] || raw.length < 6) return fallback;
    NSString *hex = [raw stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length != 6) return fallback;
    unsigned int value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&value]) return fallback;
    return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                           green:((value >> 8) & 0xFF) / 255.0
                            blue:(value & 0xFF) / 255.0
                           alpha:1.0];
}

static UIColor *VoltZoneColor(VoltZone zone, UIColor *fallback) {
    NSString *hexKey = (zone == VoltZoneHigh) ? @"highColor" : (zone == VoltZoneMid) ? @"midColor" : @"lowColor";
    NSString *choiceKey = (zone == VoltZoneHigh) ? @"highColorChoice"
                          : (zone == VoltZoneMid) ? @"midColorChoice"
                                                  : @"lowColorChoice";
    CFTypeRef hexValue = CFPreferencesCopyAppValue((CFStringRef)hexKey, CFSTR("com.cocxace.volt"));
    if (hexValue && CFGetTypeID(hexValue) == CFStringGetTypeID()) {
        NSString *hex = (__bridge_transfer NSString *)hexValue;
        if (hex.length >= 6) {
            if (hexValue) CFRelease(hexValue);
            return VoltColorFromHex(hex, fallback);
        }
    }
    if (hexValue) CFRelease(hexValue);
    NSInteger choice = VoltChoice(choiceKey, (NSInteger)zone);
    return VoltColorForChoice(choice);
}

static float VoltPercent(void) {
    @try {
        UIDevice *device = [UIDevice currentDevice];
        [device setBatteryMonitoringEnabled:YES];
        float rawLevel = device.batteryLevel; // 0.0..1.0 or -1 when unknown
        if (rawLevel < 0.0) return -1.0;
        return rawLevel * 100.0;
    } @catch (NSException *e) {
        return -1.0;
    }
}

#pragma mark - Darwin reload

// v1.2.3: preset expansion + reset handling (works from any pref bundle build)
#define VOLT_APP CFSTR("com.cocxace.volt")

static void VoltWriteDict(NSDictionary *defs) {
    for (NSString *k in defs) {
        CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], VOLT_APP);
    }
    CFPreferencesAppSynchronize(VOLT_APP);
}

static void VoltApplyPreset(void) {
    @try {
        NSInteger preset = -1;
        CFTypeRef pr = CFPreferencesCopyAppValue(CFSTR("preset"), VOLT_APP);
        if (pr) {
            if (CFGetTypeID(pr) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)pr, kCFNumberNSIntegerType, &preset);
            CFRelease(pr);
        }
        if (preset == 0) {          // Classic
            VoltWriteDict(@{ @"highThreshold": @(40.0), @"lowThreshold": @(20.0),
                             @"highColorChoice": @(0), @"midColorChoice": @(1), @"lowColorChoice": @(2) });
        } else if (preset == 1) {   // Night Stealth
            VoltWriteDict(@{ @"highThreshold": @(40.0), @"lowThreshold": @(20.0),
                             @"highColorChoice": @(8), @"midColorChoice": @(6), @"lowColorChoice": @(2) });
        }
    } @catch (NSException *e) {}
}

static void VoltResetDefaults(void) {
    @try {
        VoltWriteDict(@{ @"highThreshold": @(40.0), @"lowThreshold": @(20.0),
                         @"highColorChoice": @(0), @"midColorChoice": @(1), @"lowColorChoice": @(2),
                         @"preset": @(-1), @"voltDebug": @(NO) });
        CFPreferencesSetAppValue(CFSTR("resetDefaults"), kCFBooleanFalse, VOLT_APP);
        CFPreferencesAppSynchronize(VOLT_APP);
        NSLog(@"[CocxaceTweak] Volt defaults restored");
    } @catch (NSException *e) {}
}

static void VoltDarwinCallback(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
        VoltApplyPreset();
        CFTypeRef rst = CFPreferencesCopyAppValue(CFSTR("resetDefaults"), VOLT_APP);
        BOOL doReset = NO;
        if (rst) {
            if (CFGetTypeID(rst) == CFBooleanGetTypeID()) doReset = CFBooleanGetValue((CFBooleanRef)rst);
            CFRelease(rst);
        }
        if (doReset) VoltResetDefaults();
    } @catch (NSException *e) {}
}

#pragma mark - Hook

static void (*orig_setCol)(id self, SEL _cmd, UIColor *color);
static void hook_setCol(id self, SEL _cmd, UIColor *color) {
    @try {
        float level = VoltPercent();
        if (level >= 0.0) {
            float highAt = VoltNumber(@"highThreshold", 40.0);
            float lowAt = VoltNumber(@"lowThreshold", 20.0);
            if (lowAt > highAt) lowAt = highAt;

            UIColor *finalColor;
            if (level > highAt) {
                finalColor = VoltZoneColor(VoltZoneHigh, [UIColor colorWithRed:0.2 green:0.85 blue:0.35 alpha:1.0]);
            } else if (level > lowAt) {
                finalColor = VoltZoneColor(VoltZoneMid, [UIColor colorWithRed:1.0 green:0.82 blue:0.1 alpha:1.0]);
            } else {
                finalColor = VoltZoneColor(VoltZoneLow, [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1.0]);
            }
            if (finalColor) color = finalColor;
        }
    } @catch (NSException *e) {
        NSLog(@"[Tweak Error] Volt battery: %@", e);
    }
    if (orig_setCol) orig_setCol(self, _cmd, color);
}

__attribute__((constructor)) static void initVolt() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Volt 1.2.3 loaded");

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        VoltDarwinCallback,
                                        CFSTR("com.cocxace.volt/reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        Class cls = objc_getClass("UIStatusBarBatteryPercentItemView");
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel_registerName("setTextColor:"));
            if (m) {
                orig_setCol = (void (*)(id, SEL, UIColor *))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_setCol);
                NSLog(@"[CocxaceTweak] Volt color hook installed");
            } else {
                NSLog(@"[Tweak Error] Volt: setTextColor: not found on this firmware");
            }
        } else {
            NSLog(@"[Tweak Error] Volt: UIStatusBarBatteryPercentItemView not found");
        }
    }
}

// Деструктор при выгрузке tweak (%c / respring)
__attribute__((destructor)) static void cleanupVolt(void) {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Volt destructor — cleaning up");
    }
}
