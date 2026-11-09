#import "AB12Manager.h"
#import <objc/message.h>
#import "AB12HUDView.h"
#import <notify.h>

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID suspended:(BOOL)suspended;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
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
        
        // Listen for preference changes
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            PreferencesChangedCallback,
            CFSTR(PREF_CHANGED_NOTIFICATION),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        // NOTE: DO NOT initialize UIWindow here! UIWindow must be 100% lazy to prevent boot crashes.
    }
    return self;
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

- (void)loadPreferences {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (prefs) {
        self.enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
        self.trigger = prefs[@"trigger"] ? [prefs[@"trigger"] integerValue] : AB12TriggerPower;
        self.showSliders = prefs[@"showSliders"] ? [prefs[@"showSliders"] boolValue] : YES;
        self.action1 = prefs[@"action1"] ? [prefs[@"action1"] integerValue] : AB12ActionFlashlight;
        self.action2 = prefs[@"action2"] ? [prefs[@"action2"] integerValue] : AB12ActionCamera;
        self.action3 = prefs[@"action3"] ? [prefs[@"action3"] integerValue] : AB12ActionVoiceMemos;
        self.action4 = prefs[@"action4"] ? [prefs[@"action4"] integerValue] : AB12ActionScreenshot;
    } else {
        self.enabled = YES;
        self.trigger = AB12TriggerPower;
        self.showSliders = YES;
        self.action1 = AB12ActionFlashlight;
        self.action2 = AB12ActionCamera;
        self.action3 = AB12ActionVoiceMemos;
        self.action4 = AB12ActionScreenshot;
    }
}

- (NSArray<NSNumber *> *)currentActions {
    return @[
        @(self.action1),
        @(self.action2),
        @(self.action3),
        @(self.action4)
    ];
}

- (void)toggleHUD {
    if (!self.enabled) return;

    Class lsmCls = NSClassFromString(@"SBLockScreenManager");
    if (lsmCls) {
        id lsm = [lsmCls performSelector:@selector(sharedInstance)];
        if (lsm && [lsm respondsToSelector:@selector(isUILocked)]) {
            BOOL locked = ((BOOL (*)(id, SEL))objc_msgSend)(lsm, @selector(isUILocked));
            if (locked) return;
        }
        if (lsm && [lsm respondsToSelector:@selector(isPasscodeLockVisible)]) {
            BOOL pass = ((BOOL (*)(id, SEL))objc_msgSend)(lsm, @selector(isPasscodeLockVisible));
            if (pass) return;
        }
    }

    // Debounce: two hooked paths can fire for one double-press gesture.
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
            AudioServicesPlaySystemSound(1519);
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
    AudioServicesPlaySystemSound(1519);
    __weak typeof(self) weakSelf = self;
    [[AB12HUDWindow sharedWindow] hideWithCompletion:^{
        [weakSelf executeAction:action];
    }];
}

- (void)executeAction:(AB12Action)action {
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
    if ([device hasTorch] && [device isTorchAvailable]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            if (device.torchMode == AVCaptureTorchModeOn) {
                [device setTorchMode:AVCaptureTorchModeOff];
            } else {
                [device setTorchMode:AVCaptureTorchModeOn];
            }
            [device unlockForConfiguration];
        }
    }
}

- (void)launchAppWithBundleID:(NSString *)bundleID {
    Class uiControllerClass = NSClassFromString(@"SBUIController");
    if (uiControllerClass) {
        id uiController = [uiControllerClass sharedInstance];
        if ([uiController respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
            [uiController launchApplicationWithIdentifier:bundleID suspended:NO];
            return;
        } else if ([uiController respondsToSelector:@selector(launchApplicationWithIdentifier:)]) {
            [uiController launchApplicationWithIdentifier:bundleID];
            return;
        }
    }
    
    // Fallback via LSApplicationWorkspace
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = [workspaceClass defaultWorkspace];
        if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            [workspace openApplicationWithBundleID:bundleID];
        }
    }
}

- (void)toggleWiFi {
    Class wifiClass = NSClassFromString(@"SBWiFiManager");
    if (wifiClass) {
        id wifiMgr = [wifiClass sharedInstance];
        if ([wifiMgr respondsToSelector:@selector(wiFiEnabled)] &&
            [wifiMgr respondsToSelector:@selector(setWiFiEnabled:)]) {
            BOOL current = [wifiMgr wiFiEnabled];
            [wifiMgr setWiFiEnabled:!current];
        }
    }
}

- (void)toggleBluetooth {
    Class btClass = NSClassFromString(@"BluetoothManager");
    if (btClass) {
        id btMgr = [btClass sharedInstance];
        if ([btMgr respondsToSelector:@selector(enabled)] &&
            [btMgr respondsToSelector:@selector(setEnabled:)]) {
            BOOL current = [btMgr enabled];
            [btMgr setEnabled:!current];
        }
    }
}

@end
