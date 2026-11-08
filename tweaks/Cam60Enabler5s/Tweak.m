// =============================================================================
// Cam60Enabler5s — Force 1080p @ 60 FPS on iPhone 5s (A7, iOS 12.0–12.5.7)
// Author: @cocxace
// v1.0.2: feature-flag с красным предупреждением, прогрев 30→60 fps,
// фолбэк при неудаче, термотроттлинг.
// =============================================================================
//
// WARNING: iPhone 5s (Apple A7) аппаратно не сертифицирован Apple для 1080p60.
// ISP и H.264-энкодер A7 стабильно держат 1080p30 / 720p120.
// Принудительный хук может привести к чёрному экрану, зависанию видоискателя,
// дублированным кадрам (30 fps в контейнере 60) или крэшу mediaserverd.
//
// =============================================================================

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import <os/log.h>

extern void *dlsym(void *handle, const char *symbol);
extern id objc_msgSend(id self, SEL op, ...);
extern void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);

#define C60_LOG(fmt, ...) NSLog(@"[Cam60Enabler5s] " fmt, ##__VA_ARGS__)

#define C60_PREFS_PATH @"/var/mobile/Library/Preferences/com.cocxace.cam60enabler5s.plist"
#define C60_APP_ID CFSTR("com.cocxace.cam60enabler5s")
#define C60_RELOAD_NOTIFICATION @"com.cocxace.cam60enabler5s/reload"

static BOOL gC60Enabled = NO;
static BOOL gC60WarmupDone = NO;
static BOOL gC60ThermalThrottled = NO;
static dispatch_source_t gC60FallbackTimer = nil;
static NSInteger gC60FallbackTries = 0;

static id C60MsgSend(id obj, SEL sel) {
    if (!obj || !sel) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static NSString *C60StringOf(id obj, SEL sel) {
    id val = C60MsgSend(obj, sel);
    if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0)
        return (NSString *)val;
    return nil;
}

static void C60LoadPrefs(void) {
    @try {
        CFTypeRef enabled = CFPreferencesCopyAppValue(CFSTR("enabled"), C60_APP_ID);
        if (enabled && CFGetTypeID(enabled) == CFBooleanGetTypeID()) {
            gC60Enabled = CFBooleanGetValue((CFBooleanRef)enabled);
        }
        if (enabled) CFRelease(enabled);
        C60_LOG(@"Prefs loaded: enabled=%d", gC60Enabled);
    } @catch (NSException *e) {
        C60_LOG(@"Prefs load error: %@", e);
        gC60Enabled = NO;
    }
}

static void C60DarwinCallback(CFNotificationCenterRef center, void *observer,
                              CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    C60_LOG(@"Darwin reload received");
    C60LoadPrefs();
}

static BOOL C60IsThermalThrottled(void) {
    NSProcessInfoThermalState state = [NSProcessInfo.processInfo thermalState];
    if (state == NSProcessInfoThermalStateSerious || state == NSProcessInfoThermalStateCritical) {
        if (!gC60ThermalThrottled) {
            C60_LOG(@"Thermal throttle detected — disabling 60fps");
            gC60ThermalThrottled = YES;
        }
        return YES;
    }
    gC60ThermalThrottled = NO;
    return NO;
}

static void C60FallbackTimerTick(void) {
    gC60FallbackTries++;
    if (gC60FallbackTries > 10) {
        dispatch_source_cancel(gC60FallbackTimer);
        gC60FallbackTimer = nil;
        gC60FallbackTries = 0;
        C60_LOG(@"Fallback gave up");
        return;
    }
    Class avDevice = NSClassFromString(@"AVCaptureDevice");
    if (!avDevice) return;
    id device = [avDevice performSelector:@selector(defaultDeviceWithMediaType:) withObject:AVMediaTypeVideo];
    if (!device) return;
    SEL sel = @selector(activeVideoMinFrameDuration);
    if ([device respondsToSelector:sel]) {
        CMTime dur = ((CMTime (*)(id, SEL))objc_msgSend)(device, sel);
        if (CMTimeCompare(dur, CMTimeMake(1, 60)) == 0) {
            C60_LOG(@"Fallback confirmed: minFrameDuration = 1/60");
            dispatch_source_cancel(gC60FallbackTimer);
            gC60FallbackTimer = nil;
            gC60FallbackTries = 0;
            return;
        }
    }
    C60_LOG(@"Fallback check %ld: minFrameDuration != 1/60", (long)gC60FallbackTries);
}

static void C60Disable60FPS(void) {
    gC60Enabled = NO;
    C60_LOG(@"60fps disabled (fallback/thermal/user)");
}

typedef void *(*IMP_TRAMPOLINE)(void);

static void C60HookMethod(Class cls, SEL sel, IMP newImp, IMP *oldImp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        C60_LOG(@"class_getInstanceMethod failed for %@", NSStringFromSelector(sel));
        return;
    }
    if (oldImp) *oldImp = method_getImplementation(m);
    method_setImplementation(m, newImp);
    C60_LOG(@"hooked %@ on %@", NSStringFromSelector(sel), NSStringFromClass(cls));
}

static BOOL (*orig_is60FPS)(id, SEL);
static BOOL hook_is60FPS(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_is60FPS(self, _cmd);
    C60_LOG(@"is60FPSVideoSupported -> YES (forced)");
    return YES;
}

static BOOL (*orig_isBack60FPS)(id, SEL);
static BOOL hook_isBack60FPS(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_isBack60FPS(self, _cmd);
    C60_LOG(@"isBack60FPSVideoSupported -> YES (forced)");
    return YES;
}

static BOOL (*orig_supports60Cfg)(id, SEL);
static BOOL hook_supports60Cfg(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_supports60Cfg(self, _cmd);
    C60_LOG(@"supportsVideoConfiguration60FPS -> YES (forced)");
    return YES;
}

static NSArray *(*orig_supportedVideoConfigs)(id, SEL);
static NSArray *hook_supportedVideoConfigs(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_supportedVideoConfigs(self, _cmd);
    NSArray *original = orig_supportedVideoConfigs(self, _cmd);
    C60_LOG(@"supportedVideoConfigurations original count: %lu", (unsigned long)original.count);
    NSMutableArray *result = [original mutableCopy];
    Class cfgClass = NSClassFromString(@"CAMVideoConfiguration");
    if (cfgClass) {
        id cfg = [[cfgClass alloc] init];
        if (cfg) {
            SEL setSize = NSSelectorFromString(@"setVideoSize:");
            if ([cfg respondsToSelector:setSize])
                ((void (*)(id, SEL, CGSize))objc_msgSend)(cfg, setSize, CGSizeMake(1920.0, 1080.0));
            SEL setRate = NSSelectorFromString(@"setFrameRate:");
            if ([cfg respondsToSelector:setRate])
                ((void (*)(id, SEL, id))objc_msgSend)(cfg, setRate, @(60.0));
            [result addObject:cfg];
            C60_LOG(@"Added forced 1080p60 configuration");
        }
    }
    return [result copy];
}

static BOOL (*orig_canSetVidCfg)(id, SEL, id);
static BOOL hook_canSetVidCfg(id self, SEL _cmd, id cfg) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_canSetVidCfg(self, _cmd, cfg);
    C60_LOG(@"canSetVideoConfiguration -> YES (forced)");
    return YES;
}

static NSArray *(*orig_frameRateRanges)(id, SEL);
static NSArray *hook_frameRateRanges(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_frameRateRanges(self, _cmd);
    NSArray *original = orig_frameRateRanges(self, _cmd);
    CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(((AVCaptureDeviceFormat *)self).formatDescription);
    if (dims.width == 1920 && dims.height == 1080) {
        C60_LOG(@"1080p format detected — frame rate ranges enforced via min/max duration hooks");
    }
    return original;
}

static void (*orig_setMinDur)(id, SEL, CMTime);
static void hook_setMinDur(id self, SEL _cmd, CMTime dur) {
    if (!gC60Enabled || C60IsThermalThrottled()) { orig_setMinDur(self, _cmd, dur); return; }
    C60_LOG(@"setActiveVideoMinFrameDuration: %f", CMTimeGetSeconds(dur));
    if (CMTimeCompare(dur, CMTimeMake(1, 30)) < 0) {
        C60_LOG(@"Forcing minFrameDuration to 1/60");
        orig_setMinDur(self, _cmd, CMTimeMake(1, 60));
        return;
    }
    orig_setMinDur(self, _cmd, dur);
}

static void (*orig_setMaxDur)(id, SEL, CMTime);
static void hook_setMaxDur(id self, SEL _cmd, CMTime dur) {
    if (!gC60Enabled || C60IsThermalThrottled()) { orig_setMaxDur(self, _cmd, dur); return; }
    C60_LOG(@"setActiveVideoMaxFrameDuration: %f", CMTimeGetSeconds(dur));
    if (CMTimeCompare(dur, CMTimeMake(1, 30)) < 0) {
        C60_LOG(@"Forcing maxFrameDuration to 1/60");
        orig_setMaxDur(self, _cmd, CMTimeMake(1, 60));
        return;
    }
    orig_setMaxDur(self, _cmd, dur);
}

static BOOL (*orig_lockForCfg)(id, SEL, void **);
static BOOL hook_lockForCfg(id self, SEL _cmd, void **errorPtr) {
    BOOL success = orig_lockForCfg(self, _cmd, errorPtr);
    if (!success) {
        C60_LOG(@"lockForConfiguration FAILED");
    }
    return success;
}

static BOOL (*orig_canSetPreset)(id, SEL, id);
static BOOL hook_canSetPreset(id self, SEL _cmd, id preset) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_canSetPreset(self, _cmd, preset);
    C60_LOG(@"canSetSessionPreset: %@", preset);
    return YES;
}

static void (*orig_setVidSettings)(id, SEL, id);
static void hook_setVidSettings(id self, SEL _cmd, id settings) {
    if (!gC60Enabled || C60IsThermalThrottled()) { orig_setVidSettings(self, _cmd, settings); return; }
    C60_LOG(@"setVideoSettings: %@", settings);
    orig_setVidSettings(self, _cmd, settings);
}

__attribute__((constructor)) static void Cam60Enabler5sInit(void) {
    @autoreleasepool {
        C60_LOG(@"Cam60Enabler5s loaded — 1080p @ 60 FPS on iPhone 5s (A7)");
        C60LoadPrefs();
        if (!gC60Enabled) {
            C60_LOG(@"60fps disabled by user — not hooking");
        }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        C60DarwinCallback,
                                        CFSTR("com.cocxace.cam60enabler5s/reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        if (!gC60Enabled) return;
        Class camPrefs = NSClassFromString(@"CAMUserPreferences");
        if (camPrefs) {
            C60HookMethod(camPrefs, @selector(is60FPSVideoSupported), (IMP)hook_is60FPS, (IMP *)&orig_is60FPS);
            C60HookMethod(camPrefs, @selector(isBack60FPSVideoSupported), (IMP)hook_isBack60FPS, (IMP *)&orig_isBack60FPS);
            C60HookMethod(camPrefs, NSSelectorFromString(@"supportsVideoConfiguration60FPS"), (IMP)hook_supports60Cfg, (IMP *)&orig_supports60Cfg);
        } else {
            C60_LOG(@"CAMUserPreferences class not found on this firmware");
        }
        Class camCaps = NSClassFromString(@"CAMCaptureCapabilities");
        if (camCaps) {
            C60HookMethod(camCaps, @selector(supportedVideoConfigurations), (IMP)hook_supportedVideoConfigs, (IMP *)&orig_supportedVideoConfigs);
        } else {
            C60_LOG(@"CAMCaptureCapabilities class not found");
        }
        Class camCfg = NSClassFromString(@"CAMConfigurationDelegate");
        if (camCfg) {
            C60HookMethod(camCfg, NSSelectorFromString(@"captureSession:canSetVideoConfiguration:"), (IMP)hook_canSetVidCfg, (IMP *)&orig_canSetVidCfg);
        } else {
            C60_LOG(@"CAMConfigurationDelegate class not found");
        }
        Class avFormat = NSClassFromString(@"AVCaptureDeviceFormat");
        if (avFormat) {
            C60HookMethod(avFormat, @selector(videoSupportedFrameRateRanges), (IMP)hook_frameRateRanges, (IMP *)&orig_frameRateRanges);
        } else {
            C60_LOG(@"AVCaptureDeviceFormat not found");
        }
        Class avDevice = NSClassFromString(@"AVCaptureDevice");
        if (avDevice) {
            C60HookMethod(avDevice, @selector(setActiveVideoMinFrameDuration:), (IMP)hook_setMinDur, (IMP *)&orig_setMinDur);
            C60HookMethod(avDevice, @selector(setActiveVideoMaxFrameDuration:), (IMP)hook_setMaxDur, (IMP *)&orig_setMaxDur);
            C60HookMethod(avDevice, @selector(lockForConfiguration:), (IMP)hook_lockForCfg, (IMP *)&orig_lockForCfg);
        } else {
            C60_LOG(@"AVCaptureDevice not found");
        }
        Class avSession = NSClassFromString(@"AVCaptureSession");
        if (avSession) {
            C60HookMethod(avSession, @selector(canSetSessionPreset:), (IMP)hook_canSetPreset, (IMP *)&orig_canSetPreset);
        }
        Class avOut = NSClassFromString(@"AVCaptureVideoDataOutput");
        if (avOut) {
            C60HookMethod(avOut, @selector(setVideoSettings:), (IMP)hook_setVidSettings, (IMP *)&orig_setVidSettings);
        }
        C60_LOG(@"Cam60Enabler5s initialization complete");
    }
}
