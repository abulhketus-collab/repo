// Volt — battery percent color for iOS 12 (com.cocxace.volt)
// v1.2.0: palette pickers per battery zone from the Settings pane
// (com.cocxace.volt: highColorChoice / midColorChoice / lowColorChoice)
// plus legacy hex keys, live reload via darwin notification.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark - Preferences

static NSDictionary *VoltPrefs = nil;

static void VoltReloadPrefs(void) {
    NSDictionary *fresh =
        [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.volt.plist"];
    VoltPrefs = fresh ?: @{};
}

static float VoltNumber(NSString *key, float fallback) {
    id value = VoltPrefs[key];
    if ([value isKindOfClass:[NSNumber class]]) return [value floatValue];
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value floatValue];
    return fallback;
}

static NSInteger VoltChoice(NSString *key, NSInteger fallback) {
    id value = VoltPrefs[key];
    if ([value isKindOfClass:[NSNumber class]]) return [value integerValue];
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value integerValue];
    return fallback;
}

typedef NS_ENUM(NSUInteger, VoltZone) {
    VoltZoneHigh = 0,
    VoltZoneMid = 1,
    VoltZoneLow = 2,
};

// Palette choices (Settings → Volt): each index maps to a color.
// The legacy hex prefs (highColor / midColor / lowColor) still win when present.
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

// Accepts "RRGGBB" / "#RRGGBB" (legacy custom color support).
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
    id hexValue = VoltPrefs[hexKey];
    if ([hexValue isKindOfClass:[NSString class]] && [(NSString *)hexValue length] >= 6) {
        return VoltColorFromHex(hexValue, fallback);
    }
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

#pragma mark - Darwing reload

static void VoltDarwinCallback(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
        VoltReloadPrefs();
    } @catch (NSException *e) {}
}

#pragma mark - Hook

static void (*orig_setCol)(id self, SEL _cmd, UIColor *color);
static void hook_setCol(id self, SEL _cmd, UIColor *color) {
    @try {
        if (!VoltPrefs) VoltReloadPrefs();
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
        NSLog(@"[CocxaceTweak] Volt 1.2.0 loaded");
        VoltReloadPrefs();

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
