#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static id (*orig_contentsImage)(id, SEL);
static id custom_contentsImage(UIView *self, SEL _cmd) {
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float level = [UIDevice currentDevice].batteryLevel * 100.0;
    
    UIColor *targetColor;
    if (level > 40.0) {
        targetColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.35 alpha:1.0];
    } else if (level > 20.0) {
        targetColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.1 alpha:1.0];
    } else {
        targetColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1.0];
    }

    [UIView transitionWithView:self duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.tintColor = targetColor;
    } completion:nil];

    return orig_contentsImage ? orig_contentsImage(self, _cmd) : nil;
}

__attribute__((constructor)) static void initVolt() {
    @autoreleasepool {
        Class cls = objc_getClass("UIStatusBarBatteryPercentItemView");
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel_registerName("contentsImage"));
            if (m) {
                orig_contentsImage = (id (*)(id, SEL))method_getImplementation(m);
                method_setImplementation(m, (IMP)custom_contentsImage);
            }
        }
    }
}
