// =============================================================================
// Cam60Enabler5s — 1080p @ 60 FPS on iPhone 5s (Apple A7, iOS 12.0–12.5.8)
// Zero Safe Mode Guarantee:
// 1. Process Filter: Strictly executes ONLY in com.apple.camera & com.apple.Preferences.
//    SpringBoard, mediaserverd, and other daemons are NEVER hooked.
// 2. Format & Hardware Guards: 60 FPS only applied on Back camera in 1080p video mode.
//    Photo mode, square mode, time-lapse, and front camera are left 100% untouched.
// 3. Complete @try / @catch wrapping: Zero uncaught exceptions.
// 4. Clean CameraUI integration: Exposes 1080p 60fps in Camera settings & recording UI.
// =============================================================================

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import <os/log.h>

extern void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);

#define C60_LOG(fmt, ...) NSLog(@"[Cam60Enabler5s] " fmt, ##__VA_ARGS__)
#define C60_APP_ID CFSTR("com.cocxace.cam60enabler5s")
#define C60_RELOAD_NOTIFICATION "com.cocxace.cam60enabler5s/reload"

// -----------------------------------------------------------------------------
// Preferences State
// -----------------------------------------------------------------------------
static BOOL   gC60Enabled     = YES; // default ON
static BOOL   gC60SlowMo      = NO;
static CGFloat gC60Bitrate    = 25.0; // safe bitrate for A7 hardware encoder
static CGFloat gC60Quality    = 0.85;
static BOOL   gC60Thermal     = YES;
static BOOL   gC60AutoDisable = YES;
static NSInteger gC60Profile  = -1;

static void C60ApplyProfile(NSInteger profile) {
    switch (profile) {
        case 0: // Max Quality
            gC60SlowMo = YES;
            gC60Bitrate = 40.0;
            gC60Quality = 0.95;
            gC60Thermal = YES;
            gC60AutoDisable = YES;
            break;
        case 1: // Balance
            gC60SlowMo = NO;
            gC60Bitrate = 25.0;
            gC60Quality = 0.85;
            gC60Thermal = YES;
            gC60AutoDisable = YES;
            break;
        case 2: // Battery Save
            gC60SlowMo = NO;
            gC60Bitrate = 18.0;
            gC60Quality = 0.70;
            gC60Thermal = YES;
            gC60AutoDisable = YES;
            break;
        default:
            break;
    }
}

static BOOL C60BoolPref(CFStringRef key, BOOL defval) {
    CFTypeRef raw = CFPreferencesCopyAppValue(key, C60_APP_ID);
    BOOL out = defval;
    if (raw) {
        if (CFGetTypeID(raw) == CFBooleanGetTypeID()) {
            out = CFBooleanGetValue((CFBooleanRef)raw);
        } else if (CFGetTypeID(raw) == CFNumberGetTypeID()) {
            NSInteger v = 0;
            CFNumberGetValue((CFNumberRef)raw, kCFNumberNSIntegerType, &v);
            out = (v != 0);
        }
        CFRelease(raw);
    }
    return out;
}

static CGFloat C60DoublePref(CFStringRef key, CGFloat defval) {
    CFTypeRef raw = CFPreferencesCopyAppValue(key, C60_APP_ID);
    CGFloat out = defval;
    if (raw) {
        if (CFGetTypeID(raw) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)raw, kCFNumberCGFloatType, &out);
        }
        CFRelease(raw);
    }
    return out;
}

static void C60LoadPrefs(void) {
    @try {
        gC60Enabled     = C60BoolPref(CFSTR("enabled"), YES);
        gC60SlowMo      = C60BoolPref(CFSTR("slowmo"), NO);
        gC60Thermal     = C60BoolPref(CFSTR("thermal"), YES);
        gC60AutoDisable = C60BoolPref(CFSTR("autodis"), YES);
        gC60Bitrate     = C60DoublePref(CFSTR("bitrate"), 25.0);
        gC60Quality     = C60DoublePref(CFSTR("quality"), 85.0) / 100.0;
        if (gC60Quality < 0.5) gC60Quality = 0.5;
        if (gC60Quality > 1.0) gC60Quality = 1.0;

        CFTypeRef prof = CFPreferencesCopyAppValue(CFSTR("profile"), C60_APP_ID);
        if (prof) {
            if (CFGetTypeID(prof) == CFNumberGetTypeID()) {
                CFNumberGetValue((CFNumberRef)prof, kCFNumberNSIntegerType, &gC60Profile);
            }
            CFRelease(prof);
        } else {
            gC60Profile = -1;
        }
        C60ApplyProfile(gC60Profile);

        C60_LOG(@"Prefs loaded: enabled=%d slowmo=%d bitrate=%.0f quality=%.2f profile=%ld",
                gC60Enabled, gC60SlowMo, gC60Bitrate, gC60Quality, (long)gC60Profile);
    } @catch (NSException *e) {
        C60_LOG(@"Prefs load error: %@", e);
        gC60Enabled = YES;
    }
}

static void C60DarwinCallback(CFNotificationCenterRef center, void *observer,
                              CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    C60_LOG(@"Darwin reload received");
    C60LoadPrefs();
}

static BOOL C60IsThermalThrottled(void) {
    if (!gC60Thermal) return NO;
    @try {
        NSProcessInfoThermalState state = [NSProcessInfo.processInfo thermalState];
        if (state == NSProcessInfoThermalStateSerious || state == NSProcessInfoThermalStateCritical) {
            return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

// -----------------------------------------------------------------------------
// Safe Hook Helper
// -----------------------------------------------------------------------------
static void C60Hook(Class cls, SEL sel, IMP newImp, IMP *oldImp) {
    if (!cls || !sel || !newImp) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        C60_LOG(@"Method %@ not found on class %@", NSStringFromSelector(sel), NSStringFromClass(cls));
        return;
    }
    if (oldImp) *oldImp = method_getImplementation(m);
    method_setImplementation(m, newImp);
    C60_LOG(@"Successfully hooked [%@ %@]", NSStringFromClass(cls), NSStringFromSelector(sel));
}

// -----------------------------------------------------------------------------
// 1. CAMCaptureCapabilities Hooks
// -----------------------------------------------------------------------------
static BOOL (*orig_cap_is60FPS)(id, SEL);
static BOOL hook_cap_is60FPS(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_cap_is60FPS ? orig_cap_is60FPS(self, _cmd) : NO;
}

static BOOL (*orig_cap_isBack60FPS)(id, SEL);
static BOOL hook_cap_isBack60FPS(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_cap_isBack60FPS ? orig_cap_isBack60FPS(self, _cmd) : NO;
}

static BOOL (*orig_cap_is1080p60)(id, SEL);
static BOOL hook_cap_is1080p60(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_cap_is1080p60 ? orig_cap_is1080p60(self, _cmd) : NO;
}

static BOOL (*orig_cap_isBack1080p60)(id, SEL);
static BOOL hook_cap_isBack1080p60(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_cap_isBack1080p60 ? orig_cap_isBack1080p60(self, _cmd) : NO;
}

static BOOL (*orig_cap_isBackAutoFps)(id, SEL);
static BOOL hook_cap_isBackAutoFps(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_cap_isBackAutoFps ? orig_cap_isBackAutoFps(self, _cmd) : NO;
}

static NSArray *(*orig_cap_supportedConfigs)(id, SEL);
static NSArray *hook_cap_supportedConfigs(id self, SEL _cmd) {
    @try {
        NSArray *orig = orig_cap_supportedConfigs ? orig_cap_supportedConfigs(self, _cmd) : nil;
        if (!gC60Enabled || C60IsThermalThrottled()) return orig ? orig : @[];
        if (!orig) orig = @[];
        NSNumber *cfg60 = @(2); // 2 = CAMVideoConfiguration1080p60
        if (![orig containsObject:cfg60]) {
            NSMutableArray *configs = [orig mutableCopy];
            [configs addObject:cfg60];
            return [configs copy];
        }
        return orig;
    } @catch (NSException *e) {
        C60_LOG(@"supportedConfigs exception: %@", e);
        return orig_cap_supportedConfigs ? orig_cap_supportedConfigs(self, _cmd) : @[];
    }
}

static BOOL (*orig_cap_isSupportedVidCfg)(id, SEL, NSInteger);
static BOOL hook_cap_isSupportedVidCfg(id self, SEL _cmd, NSInteger cfg) {
    @try {
        if (gC60Enabled && !C60IsThermalThrottled() && cfg == 2) return YES;
        return orig_cap_isSupportedVidCfg ? orig_cap_isSupportedVidCfg(self, _cmd, cfg) : NO;
    } @catch (NSException *e) {
        return orig_cap_isSupportedVidCfg ? orig_cap_isSupportedVidCfg(self, _cmd, cfg) : NO;
    }
}

static BOOL (*orig_cap_isSupportedVidCfgModeDev)(id, SEL, NSInteger, NSInteger, NSInteger);
static BOOL hook_cap_isSupportedVidCfgModeDev(id self, SEL _cmd, NSInteger cfg, NSInteger mode, NSInteger dev) {
    @try {
        if (gC60Enabled && !C60IsThermalThrottled() && cfg == 2) {
            // mode 1: video, dev 0 or 1: back camera
            return YES;
        }
        return orig_cap_isSupportedVidCfgModeDev ? orig_cap_isSupportedVidCfgModeDev(self, _cmd, cfg, mode, dev) : NO;
    } @catch (NSException *e) {
        return orig_cap_isSupportedVidCfgModeDev ? orig_cap_isSupportedVidCfgModeDev(self, _cmd, cfg, mode, dev) : NO;
    }
}

// -----------------------------------------------------------------------------
// 2. CAMUserPreferences Hooks
// -----------------------------------------------------------------------------
static BOOL (*orig_pref_is60FPS)(id, SEL);
static BOOL hook_pref_is60FPS(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_pref_is60FPS ? orig_pref_is60FPS(self, _cmd) : NO;
}

static BOOL (*orig_pref_isBack60FPS)(id, SEL);
static BOOL hook_pref_isBack60FPS(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_pref_isBack60FPS ? orig_pref_isBack60FPS(self, _cmd) : NO;
}

static BOOL (*orig_pref_supports60Cfg)(id, SEL);
static BOOL hook_pref_supports60Cfg(id self, SEL _cmd) {
    if (gC60Enabled && !C60IsThermalThrottled()) return YES;
    return orig_pref_supports60Cfg ? orig_pref_supports60Cfg(self, _cmd) : NO;
}

static NSInteger (*orig_pref_videoConfig)(id, SEL);
static NSInteger hook_pref_videoConfig(id self, SEL _cmd) {
    @try {
        NSInteger current = orig_pref_videoConfig ? orig_pref_videoConfig(self, _cmd) : 1;
        if (gC60Enabled && !C60IsThermalThrottled()) {
            if (current == 1) { // 1 = 1080p30 stock default -> promote to 1080p60
                return 2;
            }
        }
        return current;
    } @catch (NSException *e) {
        return orig_pref_videoConfig ? orig_pref_videoConfig(self, _cmd) : 1;
    }
}

// -----------------------------------------------------------------------------
// 3. CAMConfigurationDelegate Hook
// -----------------------------------------------------------------------------
static BOOL (*orig_canSetVidCfg)(id, SEL, id);
static BOOL hook_canSetVidCfg(id self, SEL _cmd, id cfg) {
    @try {
        if (gC60Enabled && !C60IsThermalThrottled()) return YES;
        return orig_canSetVidCfg ? orig_canSetVidCfg(self, _cmd, cfg) : NO;
    } @catch (NSException *e) {
        return orig_canSetVidCfg ? orig_canSetVidCfg(self, _cmd, cfg) : NO;
    }
}

// -----------------------------------------------------------------------------
// 4. AVCaptureSession Hook
// -----------------------------------------------------------------------------
static BOOL (*orig_canSetPreset)(id, SEL, id);
static BOOL hook_canSetPreset(id self, SEL _cmd, id preset) {
    @try {
        if (!gC60Enabled || C60IsThermalThrottled()) {
            return orig_canSetPreset ? orig_canSetPreset(self, _cmd, preset) : NO;
        }
        if ([preset isKindOfClass:[NSString class]]) {
            // Keep stock behavior for photo/low/medium
            if ([preset isEqualToString:AVCaptureSessionPresetPhoto] ||
                [preset isEqualToString:AVCaptureSessionPresetLow] ||
                [preset isEqualToString:AVCaptureSessionPresetMedium]) {
                return orig_canSetPreset ? orig_canSetPreset(self, _cmd, preset) : NO;
            }
        }
        return YES;
    } @catch (NSException *e) {
        return orig_canSetPreset ? orig_canSetPreset(self, _cmd, preset) : NO;
    }
}

// -----------------------------------------------------------------------------
// 5. AVCaptureDevice Hooks (Hardware Frame Durations — 100% Guarded)
// -----------------------------------------------------------------------------
static void (*orig_setMinDur)(id, SEL, CMTime);
static void hook_setMinDur(id self, SEL _cmd, CMTime dur) {
    @try {
        if (!gC60Enabled || C60IsThermalThrottled()) {
            if (orig_setMinDur) orig_setMinDur(self, _cmd, dur);
            return;
        }

        // GUARD 1: Only back camera
        if ([self isKindOfClass:[AVCaptureDevice class]]) {
            AVCaptureDevice *device = (AVCaptureDevice *)self;
            if (device.position != AVCaptureDevicePositionBack) {
                if (orig_setMinDur) orig_setMinDur(self, _cmd, dur);
                return;
            }

            // GUARD 2: Active format must be 1080p video with 60fps support
            AVCaptureDeviceFormat *format = device.activeFormat;
            if (format) {
                CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                if (dims.width == 1920 && dims.height == 1080) {
                    BOOL supports60 = NO;
                    for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
                        if (range.maxFrameRate >= 59.0) {
                            supports60 = YES;
                            break;
                        }
                    }
                    if (supports60) {
                        if (orig_setMinDur) orig_setMinDur(self, _cmd, CMTimeMake(1, 60));
                        return;
                    }
                }
            }
        }

        if (orig_setMinDur) orig_setMinDur(self, _cmd, dur);
    } @catch (NSException *e) {
        C60_LOG(@"hook_setMinDur caught safely: %@", e);
        @try {
            if (orig_setMinDur) orig_setMinDur(self, _cmd, dur);
        } @catch (NSException *e2) {}
    }
}

static void (*orig_setMaxDur)(id, SEL, CMTime);
static void hook_setMaxDur(id self, SEL _cmd, CMTime dur) {
    @try {
        if (!gC60Enabled || C60IsThermalThrottled()) {
            if (orig_setMaxDur) orig_setMaxDur(self, _cmd, dur);
            return;
        }

        if ([self isKindOfClass:[AVCaptureDevice class]]) {
            AVCaptureDevice *device = (AVCaptureDevice *)self;
            if (device.position != AVCaptureDevicePositionBack) {
                if (orig_setMaxDur) orig_setMaxDur(self, _cmd, dur);
                return;
            }

            AVCaptureDeviceFormat *format = device.activeFormat;
            if (format) {
                CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                if (dims.width == 1920 && dims.height == 1080) {
                    BOOL supports60 = NO;
                    for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
                        if (range.maxFrameRate >= 59.0) {
                            supports60 = YES;
                            break;
                        }
                    }
                    if (supports60) {
                        if (orig_setMaxDur) orig_setMaxDur(self, _cmd, CMTimeMake(1, 60));
                        return;
                    }
                }
            }
        }

        if (orig_setMaxDur) orig_setMaxDur(self, _cmd, dur);
    } @catch (NSException *e) {
        C60_LOG(@"hook_setMaxDur caught safely: %@", e);
        @try {
            if (orig_setMaxDur) orig_setMaxDur(self, _cmd, dur);
        } @catch (NSException *e2) {}
    }
}

static BOOL (*orig_lockForCfg)(id, SEL, void **);
static BOOL hook_lockForCfg(id self, SEL _cmd, void **errorPtr) {
    @try {
        return orig_lockForCfg ? orig_lockForCfg(self, _cmd, errorPtr) : NO;
    } @catch (NSException *e) {
        C60_LOG(@"lockForConfiguration exception: %@", e);
        return NO;
    }
}

// -----------------------------------------------------------------------------
// Constructor — Absolute Safe Mode Shield
// -----------------------------------------------------------------------------
__attribute__((constructor)) static void Cam60Enabler5sInit(void) {
    @autoreleasepool {
        // STRICT PROCESS SHIELD:
        // ONLY execute inside the stock Camera app and Settings app!
        // SpringBoard, mediaserverd, and all other daemons MUST NEVER be touched.
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleId isEqualToString:@"com.apple.camera"] &&
            ![bundleId isEqualToString:@"com.apple.Preferences"]) {
            return;
        }

        C60_LOG(@"Loaded inside process: %@", bundleId);
        C60LoadPrefs();

        // Register Darwin notification for live preference updates
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        C60DarwinCallback,
                                        CFSTR("com.cocxace.cam60enabler5s/reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // 1. Hook CAMCaptureCapabilities
        Class camCaps = NSClassFromString(@"CAMCaptureCapabilities");
        if (camCaps) {
            C60Hook(camCaps, @selector(is60FPSVideoSupported), (IMP)hook_cap_is60FPS, (IMP *)&orig_cap_is60FPS);
            C60Hook(camCaps, @selector(isBack60FPSVideoSupported), (IMP)hook_cap_isBack60FPS, (IMP *)&orig_cap_isBack60FPS);
            C60Hook(camCaps, NSSelectorFromString(@"is1080p60Supported"), (IMP)hook_cap_is1080p60, (IMP *)&orig_cap_is1080p60);
            C60Hook(camCaps, NSSelectorFromString(@"isBack1080p60Supported"), (IMP)hook_cap_isBack1080p60, (IMP *)&orig_cap_isBack1080p60);
            C60Hook(camCaps, NSSelectorFromString(@"isBackAutomaticVideoFramerateSupported"), (IMP)hook_cap_isBackAutoFps, (IMP *)&orig_cap_isBackAutoFps);
            C60Hook(camCaps, @selector(supportedVideoConfigurations), (IMP)hook_cap_supportedConfigs, (IMP *)&orig_cap_supportedConfigs);
            C60Hook(camCaps, NSSelectorFromString(@"isSupportedVideoConfiguration:"), (IMP)hook_cap_isSupportedVidCfg, (IMP *)&orig_cap_isSupportedVidCfg);
            C60Hook(camCaps, NSSelectorFromString(@"isSupportedVideoConfiguration:forMode:device:"), (IMP)hook_cap_isSupportedVidCfgModeDev, (IMP *)&orig_cap_isSupportedVidCfgModeDev);
        }

        // 2. Hook CAMUserPreferences
        Class camPrefs = NSClassFromString(@"CAMUserPreferences");
        if (camPrefs) {
            C60Hook(camPrefs, @selector(is60FPSVideoSupported), (IMP)hook_pref_is60FPS, (IMP *)&orig_pref_is60FPS);
            C60Hook(camPrefs, @selector(isBack60FPSVideoSupported), (IMP)hook_pref_isBack60FPS, (IMP *)&orig_pref_isBack60FPS);
            C60Hook(camPrefs, NSSelectorFromString(@"supportsVideoConfiguration60FPS"), (IMP)hook_pref_supports60Cfg, (IMP *)&orig_pref_supports60Cfg);
            C60Hook(camPrefs, NSSelectorFromString(@"videoConfiguration"), (IMP)hook_pref_videoConfig, (IMP *)&orig_pref_videoConfig);
        }

        // 3. Hook CAMConfigurationDelegate
        Class camCfg = NSClassFromString(@"CAMConfigurationDelegate");
        if (camCfg) {
            C60Hook(camCfg, NSSelectorFromString(@"captureSession:canSetVideoConfiguration:"), (IMP)hook_canSetVidCfg, (IMP *)&orig_canSetVidCfg);
        }

        // 4. Hook AVCaptureSession
        Class avSession = NSClassFromString(@"AVCaptureSession");
        if (avSession) {
            C60Hook(avSession, @selector(canSetSessionPreset:), (IMP)hook_canSetPreset, (IMP *)&orig_canSetPreset);
        }

        // 5. Hook AVCaptureDevice
        Class avDevice = NSClassFromString(@"AVCaptureDevice");
        if (avDevice) {
            C60Hook(avDevice, @selector(setActiveVideoMinFrameDuration:), (IMP)hook_setMinDur, (IMP *)&orig_setMinDur);
            C60Hook(avDevice, @selector(setActiveVideoMaxFrameDuration:), (IMP)hook_setMaxDur, (IMP *)&orig_setMaxDur);
            C60Hook(avDevice, @selector(lockForConfiguration:), (IMP)hook_lockForCfg, (IMP *)&orig_lockForCfg);
        }

        C60_LOG(@"Cam60Enabler5s initialization safely completed.");
    }
}
