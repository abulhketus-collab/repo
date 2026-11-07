#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AuraHUDView.h"

static void (*orig_hardwareButtonLongPressed)(id, SEL, id);
static void custom_hardwareButtonLongPressed(id self, SEL _cmd, id btn) {
    [[AuraHUDView sharedInstance] presentHUD];
}

__attribute__((constructor)) static void initAura() {
    @autoreleasepool {
        Class sbClass = objc_getClass("SpringBoard");
        if (sbClass) {
            Method m = class_getInstanceMethod(sbClass, sel_registerName("_hardwareButtonLongPressed:"));
            if (m) {
                orig_hardwareButtonLongPressed = (void (*)(id, SEL, id))method_getImplementation(m);
                method_setImplementation(m, (IMP)custom_hardwareButtonLongPressed);
            }
        }
    }
}
