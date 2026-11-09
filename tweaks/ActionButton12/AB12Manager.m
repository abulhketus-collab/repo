#import "AB12Manager.h"
#import "AB12HUDView.h"
#import "AB12Prefs.h"
#import <notify.h>
#import <os/log.h>

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID suspended:(BOOL)suspended;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (BOOL)isPasscodeLockVisible;
@end

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
@end

@interface BluetoothManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)enabled;
- (void)setEnabled:(BOOL)enabled;
@end

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[AB12Manager sharedManager] loadPreferences];
}

// v1.2.3: preset expansion + reset handling
static void AB12HandleResetAndPreset(void) {
    @try {
        CFStringRef app = CFSTR("com.cocxace.actionbutton12");
        NSInteger preset = -1;
        CFTypeRef pr = CFPreferencesCopyAppValue(CFSTR("preset"), app);
        if (pr) {
            if (CFGetTypeID(pr) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)pr, kCFNumberNSIntegerType, &preset);
            CFRelease(pr);
        }
        if (preset == 0) {       // All Tools
            NSDictionary *defs = @{ @"enabled": @(YES), @"trigger": @(2),
                                    @"disableTorch": @(NO), @"disableCamera": @(NO),
                                    @"disableVoiceMemos": @(NO), @"disableScreenshot": @(NO),
                                    @"disableWiFi": @(NO), @"disableBluetooth": @(NO),
                                    @"haptics": @(YES) };
            for (NSString *k in defs) CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], app);
            CFPreferencesAppSynchronize(app);
        } else if (preset == 1) { // Quick Tools
            NSDictionary *defs = @{ @"enabled": @(YES), @"trigger": @(2),
                                    @"disableVoiceMemos": @(YES), @"haptics": @(YES) };
            for (NSString *k in defs) CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], app);
            CFPreferencesAppSynchronize(app);
        }

        CFTypeRef rst = CFPreferencesCopyAppValue(CFSTR("resetDefaults"), app);
        BOOL doReset = NO;
        if (rst) {
            if (CFGetTypeID(rst) == CFBooleanGetTypeID()) doReset = CFBooleanGetValue((CFBooleanRef)rst);
            CFRelease(rst);
        }
        if (doReset) {
            NSDictionary *defs = @{ @"enabled": @(YES), @"trigger": @(0), @"showSliders": @(YES),
                                    @"disableTorch": @(NO), @"disableCamera": @(NO),
                                    @"disableVoiceMemos": @(NO), @"disableScreenshot": @(NO),
                                    @"disableWiFi": @(NO), @"disableBluetooth": @(NO),
                                    @"haptics": @(YES), @"preset": @(-1),
                                    @"actionbutton12Debug": @(NO) };
            for (NSString *k in defs) CFPreferencesSetAppValue((CFStringRef)k, (__bridge CFTypeRef)defs[k], app);
            CFPreferencesSetAppValue(CFSTR("resetDefaults"), kCFBooleanFalse, app);
            CFPreferencesAppSynchronize(app);
            NSLog(@"[CocxaceTweak] AB12 defaults restored");
        }
    } @catch (NSException *e) {}
}

@implementation AB12Manager

+ (instancetype)sharedManager {
    static AB12Manager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AB12Manager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadPreferences];
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            PreferencesChangedCallback,
            CFSTR(PREF_CHANGED_NOTIFICATION),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }
    return self;
}

- (void)loadPreferences {
    AB12HandleResetAndPreset();
    self.enabled = [AB12Prefs boolForKey:@"enabled" defaultValue:YES];
    self.trigger = [AB12Prefs integerForKey:@"trigger" defaultValue:AB12TriggerPower];
    self.showSliders = [AB12Prefs boolForKey:@"showSliders" defaultValue:YES];
    self.action1 = (AB12Action)[AB12Prefs integerForKey:@"action1" defaultValue:AB12ActionFlashlight];
    self.action2 = (AB12Action)[AB12Prefs integerForKey:@"action2" defaultValue:AB12ActionCamera];
    self.action3 = (AB12Action)[AB12Prefs integerForKey:@"action3" defaultValue:AB12ActionVoiceMemos];
    self.action4 = (AB12Action)[AB12Prefs integerForKey:@"action4" defaultValue:AB12ActionScreenshot];
    AB12Log(@"Prefs loaded: trigger=%ld enabled=%d", (long)self.trigger, self.enabled);
}

- (void)ensureWindowSetup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            AB12HUDWindow *window = [AB12HUDWindow sharedWindow];
            AB12ViewController *vc = (AB12ViewController *)window.rootViewController;
            __weak typeof(self) weakSelf = self;
            vc.actionBlock = ^(AB12Action action) {
                [weakSelf handleActionSelection:action];
            };
            vc.dismissBlock = ^{
                [weakSelf hideHUD];
            };
        } @catch (NSException *e) {
            NSLog(@"[ActionButton12] Error setting up HUD window: %@", e);
        }
    });
}

- (NSArray<NSNumber *> *)currentActions {
    return @[
        @(self.action1),
        @(self.action2),
        @(self.action3),
        @(self.action4)
    ];
}

- (BOOL)shouldSuppressHUD {
    Class lsmCls = NSClassFromString(@"SBLockScreenManager");
    if (lsmCls) {
        id lsm = [lsmCls performSelector:@selector(sharedInstance)];
        if (lsm && [lsm respondsToSelector:@selector(isUILocked)] && [lsm isUILocked]) return YES;
        if (lsm && [lsm respondsToSelector:@selector(isPasscodeLockVisible)] && [lsm isPasscodeLockVisible]) return YES;
    }
    return NO;
}

- (void)toggleHUD {
    if (!self.enabled) return;
    if ([self shouldSuppressHUD]) return;

    static NSTimeInterval lastToggleTime = 0;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastToggleTime < 0.35) return;
    lastToggleTime = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self ensureWindowSetup];
            AB12HUDWindow *window = [AB12HUDWindow sharedWindow];
            if (window.isShowing) {
                [self hideHUD];
            } else {
                [self showHUD];
            }
        } @catch (NSException *e) {
            NSLog(@"[ActionButton12] Error in toggleHUD: %@", e);
        }
    });
}

- (void)destroy {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [[AB12HUDWindow sharedWindow] hideWithCompletion:nil];
            static __block AB12HUDWindow *s = nil;
            s = nil;
        } @catch (NSException *e) {
            NSLog(@"[ActionButton12] destroy error: %@", e);
        }
    });
}

- (void)showHUD {
    if (!self.enabled) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self ensureWindowSetup];
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            [[AB12HUDWindow sharedWindow] showWithActions:[self currentActions] showSliders:self.showSliders];
        } @catch (NSException *e) {
            NSLog(@"[ActionButton12] Error in showHUD: %@", e);
        }
    });
}

- (void)hideHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [[AB12HUDWindow sharedWindow] hideWithCompletion:nil];
        } @catch (NSException *e) {
            NSLog(@"[ActionButton12] Error in hideHUD: %@", e);
        }
    });
}

- (void)handleActionSelection:(AB12Action)action {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    __weak typeof(self) weakSelf = self;
    [[AB12HUDWindow sharedWindow] hideWithCompletion:^{
        [weakSelf executeAction:action];
    }];
}

- (void)executeAction:(AB12Action)action {
    switch (action) {
        case AB12ActionFlashlight:   if ([AB12Prefs boolForKey:@"disableTorch" defaultValue:NO]) return; break;
        case AB12ActionCamera:       if ([AB12Prefs boolForKey:@"disableCamera" defaultValue:NO]) return; break;
        case AB12ActionVoiceMemos:   if ([AB12Prefs boolForKey:@"disableVoiceMemos" defaultValue:NO]) return; break;
        case AB12ActionScreenshot:   if ([AB12Prefs boolForKey:@"disableScreenshot" defaultValue:NO]) return; break;
        case AB12ActionWiFi:         if ([AB12Prefs boolForKey:@"disableWiFi" defaultValue:NO]) return; break;
        case AB12ActionBluetooth:    if ([AB12Prefs boolForKey:@"disableBluetooth" defaultValue:NO]) return; break;
        default: break;
    }
    switch (action) {
        case AB12ActionFlashlight: {
            [self toggleFlashlight];
            break;
        }
        case AB12ActionCamera: {
            [self launchAppWithBundleID:@"com.apple.camera"];
            break;
        }
        case AB12ActionVoiceMemos: {
            [self launchAppWithBundleID:@"com.apple.VoiceMemos"];
            break;
        }
        case AB12ActionScreenshot: {
            notify_post("com.apple.springboard.takeScreenshot");
            break;
        }
        case AB12ActionWiFi: {
            [self toggleWiFi];
            break;
        }
        case AB12ActionBluetooth: {
            [self toggleBluetooth];
            break;
        }
    }
}

- (void)toggleFlashlight {
    Class captureClass = NSClassFromString(@"AVCaptureDevice");
    if (!captureClass) return;
    AVCaptureDevice *device = [captureClass defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) return;
    BOOL hasTorch = NO;
    if ([device respondsToSelector:@selector(hasTorch)]) hasTorch = [device hasTorch];
    else if ([device respondsToSelector:@selector(isTorchAvailable)]) hasTorch = [device isTorchAvailable];
    if (!hasTorch) return;
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if (device.torchMode == AVCaptureTorchModeOn) {
            [device setTorchMode:AVCaptureTorchModeOff];
        } else {
            [device setTorchMode:AVCaptureTorchModeOn];
        }
        [device unlockForConfiguration];
    }
    if (error) NSLog(@"[ActionButton12] torch error: %@", error);
}

- (void)launchAppWithBundleID:(NSString *)bundleID {
    Class uiControllerClass = NSClassFromString(@"SBUIController");
    if (uiControllerClass) {
        id uiController = [uiControllerClass performSelector:@selector(sharedInstance)];
        if (uiController && [uiController respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
            [uiController launchApplicationWithIdentifier:bundleID suspended:NO];
            return;
        } else if (uiController && [uiController respondsToSelector:@selector(launchApplicationWithIdentifier:)]) {
            [uiController launchApplicationWithIdentifier:bundleID];
            return;
        }
    }
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        if (workspace && [workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            [workspace openApplicationWithBundleID:bundleID];
        }
    }
}

- (void)toggleWiFi {
    Class wifiClass = NSClassFromString(@"SBWiFiManager");
    if (wifiClass) {
        id wifiMgr = [wifiClass performSelector:@selector(sharedInstance)];
        if (wifiMgr && [wifiMgr respondsToSelector:@selector(wiFiEnabled)] && [wifiMgr respondsToSelector:@selector(setWiFiEnabled:)]) {
            BOOL current = [wifiMgr wiFiEnabled];
            [wifiMgr setWiFiEnabled:!current];
        }
    }
}

- (void)toggleBluetooth {
    Class btClass = NSClassFromString(@"BluetoothManager");
    if (btClass) {
        id btMgr = [btClass performSelector:@selector(sharedInstance)];
        if (btMgr && [btMgr respondsToSelector:@selector(enabled)] && [btMgr respondsToSelector:@selector(setEnabled:)]) {
            BOOL current = [btMgr enabled];
            [btMgr setEnabled:!current];
        }
    }
}

@end
