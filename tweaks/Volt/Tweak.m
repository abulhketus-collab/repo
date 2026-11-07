#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_setTextColor)(id self, SEL _cmd, UIColor *color);
static void custom_setTextColor(id self, SEL _cmd, UIColor *color) {
    UIColor *finalColor = color;
    @try {
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        float level = [UIDevice currentDevice].batteryLevel * 100.0;
        if (level > 40.0) {
            finalColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.35 alpha:1.0];
        } else if (level > 20.0) {
            finalColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.1 alpha:1.0];
        } else {
            finalColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1.0];
        }
    } @catch (NSException *e) {}
    if (orig_setTextColor) {
        orig_setTextColor(self, _cmd, finalColor);
    }
}

__attribute__((constructor)) static void initVolt() {
    @autoreleasepool {
        Class cls = objc_getClass("UIStatusBarBatteryPercentItemView");
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel_registerName("setTextColor:"));
            if (m) {
                orig_setTextColor = (void (*)(id, SEL, UIColor *))method_getImplementation(m);
                method_setImplementation(m, (IMP)custom_setTextColor);
            }
        }
    }
}
