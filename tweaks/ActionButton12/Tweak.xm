#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "AB12Common.h"
#import "AB12Manager.h"
#import "AB12Prefs.h"

#import <os/log.h>

#define AB12Log(fmt, ...) \
    do { if ([AB12Prefs sharedPrefs].debugEnabled) \
        os_log(OS_LOG_DEFAULT, "[ActionButton12.xm] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while(0)

// Forward declarations for SpringBoard classes
@interface SpringBoard : UIApplication
- (void)_hardwareButtonLongPressed:(id)btn;
- (void)_hardwareButtonPressed:(id)btn;
@end

@interface SBHomeHardwareButtonActions : NSObject
- (void)performDoublePressActions;
@end

@interface SBHomeHardwareButton : NSObject
- (void)doublePress:(id)sender;
@end

// Double tap tracker for Home button (fallback if performDoublePressActions missing)
static NSTimeInterval gLastHomePressTime = 0;

%group ActionButton12Group

%hook SpringBoard

- (void)_hardwareButtonLongPressed:(id)btn {
    AB12Manager *mgr = [AB12Manager sharedManager];
    if (mgr.enabled && (mgr.trigger == AB12TriggerPower || mgr.trigger == AB12TriggerBoth)) {
        [mgr toggleHUD];
        return;
    }
    %orig;
}

- (void)_hardwareButtonPressed:(id)btn {
    AB12Manager *mgr = [AB12Manager sharedManager];
    if (mgr.enabled && (mgr.trigger == AB12TriggerHome || mgr.trigger == AB12TriggerBoth)) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - gLastHomePressTime < 0.4) {
            gLastHomePressTime = 0;
            [mgr toggleHUD];
            return;
        } else {
            gLastHomePressTime = now;
        }
    }
    %orig;
}

%end

%hook SBHomeHardwareButtonActions

- (void)performDoublePressActions {
    AB12Manager *mgr = [AB12Manager sharedManager];
    if (mgr.enabled && (mgr.trigger == AB12TriggerHome || mgr.trigger == AB12TriggerBoth)) {
        [mgr toggleHUD];
        return;
    }
    %orig;
}

%end

%hook SBHomeHardwareButton

- (void)doublePress:(id)sender {
    AB12Manager *mgr = [AB12Manager sharedManager];
    if (mgr.enabled && (mgr.trigger == AB12TriggerHome || mgr.trigger == AB12TriggerBoth)) {
        [mgr toggleHUD];
        return;
    }
    %orig;
}

%end

%end  // %group ActionButton12Group

// Р”РµСЃС‚СЂСѓРєС‚РѕСЂ: С‡РёСЃС‚РёРј РѕРєРЅРѕ РїСЂРё РІС‹РіСЂСѓР·РєРµ tweak (%c / respring)
__attribute__((destructor)) static void cleanupActionButton12(void) {
    @autoreleasepool {
        AB12Log(@"destructor вЂ” cleaning up HUD window");
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                [[AB12Manager sharedManager] destroy];
            } @catch (NSException *e) {}
        });
    }
}
