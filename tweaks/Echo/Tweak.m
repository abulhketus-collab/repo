#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_updateCarrierItems)(id, SEL);
static void custom_updateCarrierItems(id self, SEL _cmd) {
    if (orig_updateCarrierItems) orig_updateCarrierItems(self, _cmd);
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.echo.plist"];
    NSString *customText = prefs[@"carrierText"] ? prefs[@"carrierText"] : @"cocxace ⚡";
    @try {
        [self setValue:customText forKey:@"_overrideServiceString"];
    } @catch (NSException *e) {}
}

__attribute__((constructor)) static void initEcho() {
    @autoreleasepool {
        Class cls = objc_getClass("SBStatusBarStateAggregator");
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel_registerName("_updateCarrierItems"));
            if (m) {
                orig_updateCarrierItems = (void (*)(id, SEL))method_getImplementation(m);
                method_setImplementation(m, (IMP)custom_updateCarrierItems);
            }
        }
    }
}
