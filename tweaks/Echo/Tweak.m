#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_carrier)(id self, SEL _cmd);
static void hook_carrier(id self, SEL _cmd) {
    if (orig_carrier) orig_carrier(self, _cmd);
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.echo.plist"];
        BOOL enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
        NSString *txt = prefs[@"carrierText"] ? prefs[@"carrierText"] : @"cocxace ⚡";
        if (enabled && txt.length > 0) {
            if ([self respondsToSelector:@selector(setValue:forKey:)]) {
                [self setValue:txt forKey:@"_overrideServiceString"];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[Tweak Error] Echo carrier: %@", e);
    }
}

__attribute__((constructor)) static void initEcho() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Echo Loaded successfully");
        Class cls = objc_getClass("SBStatusBarStateAggregator");
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel_registerName("_updateCarrierItems"));
            if (m) {
                orig_carrier = (void (*)(id, SEL))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_carrier);
            }
        }
    }
}
