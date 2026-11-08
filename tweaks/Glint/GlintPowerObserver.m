#import "GlintPowerObserver.h"
#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <os/log.h>

static CFRunLoopSourceRef _glintPowerRLS = NULL;

static void _glintPowerCallback(void *context) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] updatePowerState];
    });
}

@implementation GlintPowerObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowCharging" defaultValue:YES]) return;
    _glintPowerRLS = IOPSNotificationCreateRunLoopSource(CFRunLoopGetMain(), NULL, NULL, NULL);
    if (_glintPowerRLS) {
        CFRunLoopAddSource(CFRunLoopGetMain(), _glintPowerRLS, kCFRunLoopCommonModes);
    }
    [[GlintStateManager sharedManager] updatePowerState];
}

+ (void)uninstall {
    if (_glintPowerRLS) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _glintPowerRLS, kCFRunLoopCommonModes);
        CFRelease(_glintPowerRLS);
        _glintPowerRLS = NULL;
    }
}

+ (BOOL)isCharging {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return NO;
    CFArrayRef list = IOPSCopyPowerSourcesList(info);
    BOOL charging = NO;
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
        CFStringRef name = CFArrayGetValueAtIndex(list, i);
        CFDictionaryRef desc = IOPSGetPowerSourceDescription(info, name);
        if (desc) {
            CFBooleanRef isChg = CFDictionaryGetValue(desc, CFSTR(kIOPSIsChargingKey));
            if (isChg == kCFBooleanTrue) charging = YES;
        }
    }
    CFRelease(list);
    CFRelease(info);
    return charging;
}

+ (CGFloat)currentCapacity {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (!info) return -1.f;
    CFArrayRef list = IOPSCopyPowerSourcesList(info);
    CGFloat cap = -1.f;
    for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
        CFStringRef name = CFArrayGetValueAtIndex(list, i);
        CFDictionaryRef desc = IOPSGetPowerSourceDescription(info, name);
        if (desc) {
            CFNumberRef c = CFDictionaryGetValue(desc, CFSTR(kIOPSCurrentCapacityKey));
            if (c) CFNumberGetValue(c, kCFNumberCGFloatType, &cap);
        }
    }
    CFRelease(list);
    CFRelease(info);
    return cap;
}

@end
