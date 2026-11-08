// Volt — battery percent color for iOS 12 (com.cocxace.volt)
// v1.1.0: configurable thresholds & colors via prefs, cached battery level.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Preferences

typedef NS_ENUM(NSUInteger, VoltZone) {
    VoltZoneHigh = 0,
    VoltZoneMid = 1,
    VoltZoneLow = 2,
};

static NSDictionary *VoltPrefs(void) {
    static NSDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.volt.plist"] ?: @{};
    });
    return cache;
}

#pragma mark - Number helpers

static float VoltNumber(NSString *key, float fallback) {
    id value = VoltPrefs()[key];
    if ([value isKindOfClass:[NSNumber class]]) return [value floatValue];
    if ([value isKindOfClass:[NSString class]]) return [(NSString *)value floatValue];
    return fallback;
}

// Accepts "RRGGBB" / "#RRGGBB".
static UIColor *VoltColor(NSString *key, UIColor *fallback) {
    NSString *hex = VoltPrefs()[key];
    if (![hex isKindOfClass:[NSString class]] || hex.length < 6) return fallback;
    hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length != 6) return fallback;
    unsigned int raw = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    [scanner scanHexInt:&raw];
    return [UIColor colorWithRed:((raw >> 16) & 0xFF) / 255.0
                           green:((raw >> 8) & 0xFF) / 255.0
                            blue:(raw & 0xFF) / 255.0
                           alpha:1.0];
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
                finalColor = VoltColor(@"highColor", [UIColor colorWithRed:0.2 green:0.85 blue:0.35 alpha:1.0]);
            } else if (level > lowAt) {
                finalColor = VoltColor(@"midColor", [UIColor colorWithRed:1.0 green:0.82 blue:0.1 alpha:1.0]);
            } else {
                finalColor = VoltColor(@"lowColor", [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1.0]);
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
        NSLog(@"[CocxaceTweak] Volt 1.1.0 loaded");
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
