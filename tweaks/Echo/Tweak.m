// Echo — custom carrier text for iOS 12 (com.cocxace.echo)
// v1.1.0: CFPreferences instead of plist re-reads, live reload via darwin.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark - Preferences

static NSString *EchoCarrierText(void) {
    @try {
        CFStringRef key = CFSTR("carrierText");
        CFStringRef app = CFSTR("com.cocxace.echo");
        CFTypeRef raw = CFPreferencesCopyAppValue(key, app);
        if (raw == NULL) {
            // Placed in case of an absent preference.
            CFPreferencesSetAppValue(CFSTR("enabled"), kCFBooleanTrue, app);
            CFPreferencesSetAppValue(key, (__bridge CFStringRef) @"cocxace ⚡", app);
            CFPreferencesAppSynchronize(app);
            raw = CFPreferencesCopyAppValue(key, app);
            if (raw == NULL) return @"cocxace ⚡";
        }
        NSString *text = (__bridge_transfer NSString *)raw;
        if (text.length == 0) return @"cocxace ⚡";
        return text;
    } @catch (NSException *e) {
        NSLog(@"[Tweak Error] Echo prefs: %@", e);
        return @"cocxace ⚡";
    }
}

#pragma mark - Enabled gate

// Loose boolean read: kCFBooleanTrue/False and NSNumber/NSString "1" are supported.
static BOOL EchoEnabledLoose(void) {
    @try {
        id raw = (__bridge id)CFPreferencesCopyAppValue(CFSTR("enabled"), CFSTR("com.cocxace.echo"));
        if (!raw) return YES;
        if ([raw isKindOfClass:[NSNumber class]]) return [raw boolValue];
        if ([raw isKindOfClass:[NSString class]]) return [(NSString *)raw boolValue];
        return YES;
    } @catch (NSException *e) {
        return YES;
    }
}

#pragma mark - Hook

static void (*orig_carrier)(id self, SEL _cmd);
static void hook_carrier(id self, SEL _cmd) {
    if (orig_carrier) orig_carrier(self, _cmd);
    @try {
        if (!EchoEnabledLoose()) return;
        NSString *txt = EchoCarrierText();
        if (txt.length > 0 && [self respondsToSelector:@selector(setValue:forKey:)]) {
            [self setValue:txt forKey:@"_overrideServiceString"];
        }
    } @catch (NSException *e) {
        NSLog(@"[Tweak Error] Echo carrier: %@", e);
    }
}

// Live reload when the user saves preferences.
static void EchoDarwinCallback(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // v1.2.3: reset handling (plist-only, works in any pref bundle build)
    @try {
        CFTypeRef rst = CFPreferencesCopyAppValue(CFSTR("resetDefaults"), CFSTR("com.cocxace.echo"));
        BOOL doReset = NO;
        if (rst) {
            if (CFGetTypeID(rst) == CFBooleanGetTypeID()) doReset = CFBooleanGetValue((CFBooleanRef)rst);
            CFRelease(rst);
        }
        if (doReset) {
            CFPreferencesSetAppValue(CFSTR("enabled"), kCFBooleanTrue, CFSTR("com.cocxace.echo"));
            CFPreferencesSetAppValue(CFSTR("carrierText"), (__bridge CFStringRef)@"cocxace ⚡", CFSTR("com.cocxace.echo"));
            CFPreferencesSetAppValue(CFSTR("resetDefaults"), kCFBooleanFalse, CFSTR("com.cocxace.echo"));
            CFPreferencesAppSynchronize(CFSTR("com.cocxace.echo"));
            NSLog(@"[CocxaceTweak] Echo defaults restored");
        }
    } @catch (NSException *e) {}
    // CFPreferences caches are invalidated; the next updateCarrierItems call is placed again.
    CFPreferencesAppSynchronize(CFSTR("com.cocxace.echo"));
}

__attribute__((constructor)) static void initEcho() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Echo 1.2.3 loaded");
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        EchoDarwinCallback,
                                        CFSTR("com.cocxace.echo/reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        Class cls = objc_getClass("SBStatusBarStateAggregator");
        if (cls) {
            Method m = class_getInstanceMethod(cls, sel_registerName("_updateCarrierItems"));
            if (m) {
                orig_carrier = (void (*)(id, SEL))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_carrier);
                NSLog(@"[CocxaceTweak] Echo carrier hook installed");
            } else {
                NSLog(@"[Tweak Error] Echo: _updateCarrierItems not found on this firmware");
            }
        } else {
            NSLog(@"[Tweak Error] Echo: SBStatusBarStateAggregator not found");
        }
    }
}

// Деструктор при выгрузке tweak (%c / respring)
__attribute__((destructor)) static void cleanupEcho(void) {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Echo destructor — cleaning up");
    }
}
