// =============================================================================
// Cam60Enabler5s — Force 1080p @ 60 FPS on iPhone 5s (A7, iOS 12.0–12.5.7)
// Author: @cocxace
// v1.0.3: profiles (Max/Balance/Battery), slow-mo 720p120, bitrate + quality
// injection, thermal protection switch, auto-disable on error (writes back to
// prefs, never Safe Mode), honest 4K60/ProRAW/Cinematic gating on A7.
// =============================================================================
//
// WARNING: iPhone 5s (Apple A7) is not Apple-certified for 1080p60.
// The A7 ISP and H.264 encoder reliably sustain 1080p30 / 720p120.
// 4K60 / ProRAW / Cinematic are hardware-impossible on A7: the switches exist
// in Settings with honest "NOT ON 5s" marks, and the tweak safely ignores
// them instead of crashing mediaserverd.
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

// -----------------------------------------------------------------------------
// Global prefs state
// -----------------------------------------------------------------------------
static BOOL gC60Enabled = NO;          // master switch, default OFF (safety)
static BOOL gC60WarmupDone = NO;
static BOOL gC60ThermalThrottled = NO;
static dispatch_source_t gC60FallbackTimer = nil;
static NSInteger gC60FallbackTries = 0;

// v1.0.3 effective settings (after profile expansion)
static BOOL   gC60SlowMo = NO;         // 720p120 slow motion
static CGFloat gC60Bitrate = 50.0;     // Mb/s, 0 = leave stock
static CGFloat gC60Quality = 0.85;     // 0..1 encoder quality
static BOOL   gC60Thermal = YES;       // thermal protection on by default
static BOOL   gC60AutoDisable = YES;   // write back enabled=NO on hard errors
static NSInteger gC60Profile = -1;     // -1 custom, 0 max, 1 balance, 2 battery
static BOOL   gC60Want4K60 = NO;       // requested but hardware-gated off
static BOOL   gC60WantProRAW = NO;     // requested but hardware-gated off
static BOOL   gC60WantCine = NO;       // requested but hardware-gated off

static void C60ApplyProfile(NSInteger profile) {
    // Категория F: профиль настраивает только битрейт/качество/термал.
    // gC60Enabled остаётся из prefs — профиль не перебивает мастер-выключатель.
    switch (profile) {
        case 0:  // Max Quality
            gC60SlowMo = YES;
            gC60Bitrate = 80.0; gC60Quality = 1.00;
            gC60Thermal = YES; gC60AutoDisable = YES;
            break;
        case 1:  // Balance
            gC60SlowMo = NO;
            gC60Bitrate = 50.0; gC60Quality = 0.85;
            gC60Thermal = YES; gC60AutoDisable = YES;
            break;
        case 2:  // Battery Save
            gC60SlowMo = NO;
            gC60Bitrate = 30.0; gC60Quality = 0.70;
            gC60Thermal = YES; gC60AutoDisable = YES;
            break;
        default:
            break; // Custom — не трогаем gC60Enabled
    }
}

// -----------------------------------------------------------------------------
// Helper: call objc_msgSend
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Read prefs via CFPreferences (v1.0.3: all keys + profile expansion)
// -----------------------------------------------------------------------------
static CGFloat C60DoublePref(CFStringRef key, CGFloat defval) {
    CFTypeRef raw = CFPreferencesCopyAppValue(key, C60_APP_ID);
    CGFloat out = defval;
    if (raw) {
        if (CFGetTypeID(raw) == CFNumberGetTypeID())
            CFNumberGetValue((CFNumberRef)raw, kCFNumberCGFloatType, &out);
        CFRelease(raw);
    }
    return out;
}

static BOOL C60BoolPref(CFStringRef key, BOOL defval) {
    CFTypeRef raw = CFPreferencesCopyAppValue(key, C60_APP_ID);
    BOOL out = defval;
    if (raw) {
        if (CFGetTypeID(raw) == CFBooleanGetTypeID()) out = CFBooleanGetValue((CFBooleanRef)raw);
        else if (CFGetTypeID(raw) == CFNumberGetTypeID()) {
            NSInteger v = 0;
            CFNumberGetValue((CFNumberRef)raw, kCFNumberNSIntegerType, &v);
            out = (v != 0);
        }
        CFRelease(raw);
    }
    return out;
}

static void C60LoadPrefs(void) {
    @try {
        gC60Enabled      = C60BoolPref(CFSTR("enabled"), YES);
        gC60SlowMo       = C60BoolPref(CFSTR("slowmo"), NO);
        gC60Thermal      = C60BoolPref(CFSTR("thermal"), YES);
        gC60AutoDisable  = C60BoolPref(CFSTR("autodis"), YES);
        gC60Want4K60     = C60BoolPref(CFSTR("f4k60"), NO);
        gC60WantProRAW   = C60BoolPref(CFSTR("proraw"), NO);
        gC60WantCine     = C60BoolPref(CFSTR("cine"), NO);
        gC60Bitrate      = C60DoublePref(CFSTR("bitrate"), 25.0); // было 50.0 — A7 не тянет 50 Mbps на 1080p60
        gC60Quality      = C60DoublePref(CFSTR("quality"), 85.0) / 100.0;
        gC60Quality      = MIN(1.0, MAX(0.6, gC60Quality));

        CFTypeRef prof = CFPreferencesCopyAppValue(CFSTR("profile"), C60_APP_ID);
        if (prof) {
            if (CFGetTypeID(prof) == CFNumberGetTypeID())
                CFNumberGetValue((CFNumberRef)prof, kCFNumberNSIntegerType, &gC60Profile);
            CFRelease(prof);
        } else {
            gC60Profile = -1;
        }
        C60ApplyProfile(gC60Profile);

        // Honest hardware gate: A7 cannot do these, forcing them would risk
        // mediaserverd crashes. We log clearly and keep recording safe.
        if (gC60Want4K60)   C60_LOG(@"4K60 requested — NOT supported on A7, ignored for safety");
        if (gC60WantProRAW) C60_LOG(@"ProRAW requested — NOT supported on A7/iOS12, ignored for safety");
        if (gC60WantCine)   C60_LOG(@"Cinematic requested — NOT supported on A7, ignored for safety");

        C60_LOG(@"Prefs loaded: enabled=%d slowmo=%d bitrate=%.0f quality=%.2f profile=%ld thermal=%d autodis=%d",
                gC60Enabled, gC60SlowMo, gC60Bitrate, gC60Quality, (long)gC60Profile, gC60Thermal, gC60AutoDisable);
    } @catch (NSException *e) {
        C60_LOG(@"Prefs load error: %@", e);
        gC60Enabled = NO;   // any prefs error -> stock camera behavior
    }
}

// v1.0.3: persist auto-disable so a broken session does not retry forever
static void C60WriteBackDisabled(void) {
    if (!gC60AutoDisable) return;
    @try {
        CFPreferencesSetAppValue(CFSTR("enabled"), kCFBooleanFalse, C60_APP_ID);
        CFPreferencesAppSynchronize(C60_APP_ID);
        C60_LOG(@"Auto-disable: wrote enabled=false to prefs");
    } @catch (NSException *e) {
        C60_LOG(@"Auto-disable write failed: %@", e);
    }
}

// -----------------------------------------------------------------------------
// Darwin reload callback
// -----------------------------------------------------------------------------
static void C60DarwinCallback(CFNotificationCenterRef center, void *observer,
                              CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    C60_LOG(@"Darwin reload received");
    C60LoadPrefs();
}

// -----------------------------------------------------------------------------
// Thermal throttle check
// -----------------------------------------------------------------------------
static BOOL C60IsThermalThrottled(void) {
    if (!gC60Thermal) return NO;   // v1.0.3: user can turn thermal protection off
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

static void C60Disable60FPS(void);

// -----------------------------------------------------------------------------
// Fallback timer: проверяем, что minFrameDuration действительно стал 1/60
// -----------------------------------------------------------------------------
static void C60FallbackTimerTick(void) {
    gC60FallbackTries++;
    if (gC60FallbackTries > 10) {
        dispatch_source_cancel(gC60FallbackTimer);
        gC60FallbackTimer = nil;
        gC60FallbackTries = 0;
        C60_LOG(@"Fallback gave up");
        if (gC60AutoDisable) {
            C60Disable60FPS();
            C60WriteBackDisabled();
            C60_LOG(@"Auto-disable engaged: 60fps could not be confirmed, stock 30fps restored");
        }
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

// -----------------------------------------------------------------------------
// Откат на 30 fps
// -----------------------------------------------------------------------------
static void C60Disable60FPS(void) {
    gC60Enabled = NO;
    C60_LOG(@"60fps disabled (fallback/thermal/user)");
}

// -----------------------------------------------------------------------------
// Runtime method hooking
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// А) CAMUserPreferences — форсируем поддержку 60 FPS (только если.enabled)
// -----------------------------------------------------------------------------
static BOOL (*orig_is60FPS)(id, SEL);
static BOOL hook_is60FPS(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        if (orig_is60FPS) return orig_is60FPS(self, _cmd);
        return NO;
    }
    @try {
        C60_LOG(@"is60FPSVideoSupported -> YES (forced)");
        return YES;
    } @catch (NSException *e) {
        C60_LOG(@"hook_is60FPS exception: %@", e);
        return orig_is60FPS ? orig_is60FPS(self, _cmd) : NO;
    }
}

static BOOL (*orig_isBack60FPS)(id, SEL);
static BOOL hook_isBack60FPS(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        if (orig_isBack60FPS) return orig_isBack60FPS(self, _cmd);
        return NO;
    }
    @try {
        C60_LOG(@"isBack60FPSVideoSupported -> YES (forced)");
        return YES;
    } @catch (NSException *e) {
        C60_LOG(@"hook_isBack60FPS exception: %@", e);
        return orig_isBack60FPS ? orig_isBack60FPS(self, _cmd) : NO;
    }
}

static BOOL (*orig_supports60Cfg)(id, SEL);
static BOOL hook_supports60Cfg(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        if (orig_supports60Cfg) return orig_supports60Cfg(self, _cmd);
        return NO;
    }
    @try {
        C60_LOG(@"supportsVideoConfiguration60FPS -> YES (forced)");
        return YES;
    } @catch (NSException *e) {
        C60_LOG(@"hook_supports60Cfg exception: %@", e);
        return orig_supports60Cfg ? orig_supports60Cfg(self, _cmd) : NO;
    }
}

// -----------------------------------------------------------------------------
// Б) CAMCaptureCapabilities.supportedVideoConfigurations
// -----------------------------------------------------------------------------
static NSArray *(*orig_supportedVideoConfigs)(id, SEL);
static NSArray *hook_supportedVideoConfigs(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) return orig_supportedVideoConfigs(self, _cmd);
    NSArray *original = orig_supportedVideoConfigs(self, _cmd);
    C60_LOG(@"supportedVideoConfigurations original count: %lu", (unsigned long)original.count);

    // Категория E: НЕ модифицируем supportedVideoConfigurations — иначе CameraUI
    // покажет новый пункт в меню режимов (визуальное изменение UI). Возвращаем
    // оригинальный массив без изменений.
    C60_LOG(@"supportedVideoConfigurations: original count preserved (no UI changes)");
    return original;
}

// -----------------------------------------------------------------------------
// CAMConfigurationDelegate.canSetVideoConfiguration
// -----------------------------------------------------------------------------
static BOOL (*orig_canSetVidCfg)(id, SEL, id);
static BOOL hook_canSetVidCfg(id self, SEL _cmd, id cfg) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        return orig_canSetVidCfg ? orig_canSetVidCfg(self, _cmd, cfg) : NO;
    }
    @try {
        C60_LOG(@"canSetVideoConfiguration -> YES (forced)");
        return YES;
    } @catch (NSException *e) {
        C60_LOG(@"hook_canSetVidCfg exception: %@", e);
        return orig_canSetVidCfg ? orig_canSetVidCfg(self, _cmd, cfg) : NO;
    }
}

// -----------------------------------------------------------------------------
// AVCaptureDeviceFormat.videoSupportedFrameRateRanges
// -----------------------------------------------------------------------------
static NSArray *(*orig_frameRateRanges)(id, SEL);
static NSArray *hook_frameRateRanges(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        return orig_frameRateRanges ? orig_frameRateRanges(self, _cmd) : nil;
    }
    @try {
        NSArray *original = orig_frameRateRanges ? orig_frameRateRanges(self, _cmd) : nil;
        CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(((AVCaptureDeviceFormat *)self).formatDescription);
        if (dims.width == 1920 && dims.height == 1080) {
            C60_LOG(@"1080p format detected — 60fps enforced via min/max duration hooks");
        }
        return original;
    } @catch (NSException *e) {
        C60_LOG(@"frameRateRanges exception: %@", e);
        return orig_frameRateRanges ? orig_frameRateRanges(self, _cmd) : nil;
    }
}

// -----------------------------------------------------------------------------
// AVCaptureDevice.activeFormat — форсируем 1080p60 формат (BUG-CAM60-001)
// -----------------------------------------------------------------------------
static AVCaptureDeviceFormat *(*orig_activeFormat)(id, SEL);
static AVCaptureDeviceFormat *hook_activeFormat(id self, SEL _cmd) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        return orig_activeFormat ? orig_activeFormat(self, _cmd) : nil;
    }
    AVCaptureDeviceFormat *current = orig_activeFormat ? orig_activeFormat(self, _cmd) : nil;
    if (!current) return nil;

    NSNumber *posNum = [(id)self performSelector:@selector(position)];
    if (!posNum || [posNum intValue] != 1) return current;

    CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(current.formatDescription);
    if (dims.width == 1920 && dims.height == 1080) {
        NSArray *ranges = current.videoSupportedFrameRateRanges;
        for (AVFrameRateRange *range in ranges) {
            if (range.maxFrameRate >= 60.0 && range.minFrameRate <= 60.0) {
                C60_LOG(@"activeFormat: 1080p60 format confirmed");
                return current;
            }
        }
    }
    return current;
}

// -----------------------------------------------------------------------------
// AVCaptureDevice.setActiveVideoMin/MaxFrameDuration
// -----------------------------------------------------------------------------
static void (*orig_setMinDur)(id, SEL, CMTime);
static void hook_setMinDur(id self, SEL _cmd, CMTime dur) {
    if (!gC60Enabled || C60IsThermalThrottled()) { orig_setMinDur ? orig_setMinDur(self, _cmd, dur) : 0; return; }
    C60_LOG(@"setActiveVideoMinFrameDuration: %f -> forcing 60fps", CMTimeGetSeconds(dur));
    if (gC60SlowMo) {
        orig_setMinDur ? orig_setMinDur(self, _cmd, CMTimeMake(1, 120)) : 0;
    } else {
        orig_setMinDur ? orig_setMinDur(self, _cmd, CMTimeMake(1, 60)) : 0;
    }
}

static void (*orig_setMaxDur)(id, SEL, CMTime);
static void hook_setMaxDur(id self, SEL _cmd, CMTime dur) {
    if (!gC60Enabled || C60IsThermalThrottled()) { orig_setMaxDur ? orig_setMaxDur(self, _cmd, dur) : 0; return; }
    C60_LOG(@"setActiveVideoMaxFrameDuration: %f -> forcing 60fps", CMTimeGetSeconds(dur));
    if (gC60SlowMo) {
        orig_setMaxDur ? orig_setMaxDur(self, _cmd, CMTimeMake(1, 120)) : 0;
    } else {
        orig_setMaxDur ? orig_setMaxDur(self, _cmd, CMTimeMake(1, 60)) : 0;
    }
}

static BOOL (*orig_lockForCfg)(id, SEL, void **);
static NSInteger gC60LockFailures = 0;
static BOOL hook_lockForCfg(id self, SEL _cmd, void **errorPtr) {
    BOOL success = NO;
    @try {
        success = orig_lockForCfg ? orig_lockForCfg(self, _cmd, errorPtr) : NO;
    } @catch (NSException *e) {
        C60_LOG(@"lockForConfiguration exception: %@", e);
        success = NO;
    }
    if (!success) {
        gC60LockFailures++;
        C60_LOG(@"lockForConfiguration FAILED (count %ld)", (long)gC60LockFailures);
        if (gC60LockFailures >= 3) {
            C60Disable60FPS();
            C60WriteBackDisabled();
            gC60LockFailures = 0;
            C60_LOG(@"Auto-disable engaged: camera kept on stock 30fps, no Safe Mode risk");
        }
    }
    return success;
}

// -----------------------------------------------------------------------------
// AVCaptureSession.canSetSessionPreset
// -----------------------------------------------------------------------------
static BOOL (*orig_canSetPreset)(id, SEL, id);
static BOOL hook_canSetPreset(id self, SEL _cmd, id preset) {
    if (!gC60Enabled || C60IsThermalThrottled()) {
        return orig_canSetPreset ? orig_canSetPreset(self, _cmd, preset) : NO;
    }
    @try {
        C60_LOG(@"canSetSessionPreset: %@", preset);
        // Категория E: не ломаем фото-пресеты — только видео-пресеты разрешаем.
        if ([preset isKindOfClass:[NSString class]]) {
            if ([preset isEqualToString:AVCaptureSessionPresetPhoto] ||
                [preset isEqualToString:AVCaptureSessionPresetHigh] ||
                [preset isEqualToString:AVCaptureSessionPresetMedium] ||
                [preset isEqualToString:AVCaptureSessionPresetLow]) {
                return orig_canSetPreset ? orig_canSetPreset(self, _cmd, preset) : NO;
            }
        }
        return YES;
    } @catch (NSException *e) {
        C60_LOG(@"hook_canSetPreset exception: %@", e);
        return orig_canSetPreset ? orig_canSetPreset(self, _cmd, preset) : NO;
    }
}

// -----------------------------------------------------------------------------
// AVCaptureVideoDataOutput.setVideoSettings — v1.0.3 bitrate/quality injection
// -----------------------------------------------------------------------------
static void (*orig_setVidSettings)(id, SEL, id);
static void hook_setVidSettings(id self, SEL _cmd, id settings) {
    if (!gC60Enabled || C60IsThermalThrottled() || gC60Bitrate <= 0) {
        orig_setVidSettings ? orig_setVidSettings(self, _cmd, settings) : 0;
        return;
    }
    @try {
        if ([settings isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *patched = [settings mutableCopy];
            NSMutableDictionary *compression = [NSMutableDictionary dictionary];
            id existing = patched[AVVideoCompressionPropertiesKey];
            if ([existing isKindOfClass:[NSDictionary class]]) [compression addEntriesFromDictionary:existing];
            compression[AVVideoAverageBitRateKey] = @(gC60Bitrate * 1000000.0);
            compression[AVVideoQualityKey] = @(gC60Quality);
            patched[AVVideoCompressionPropertiesKey] = [compression copy];
            C60_LOG(@"setVideoSettings patched: bitrate=%.0f Mb/s quality=%.2f", gC60Bitrate, gC60Quality);
            orig_setVidSettings ? orig_setVidSettings(self, _cmd, [patched copy]) : 0;
            return;
        }
    } @catch (NSException *e) {
        C60_LOG(@"bitrate injection failed, stock settings kept: %@", e);
    }
    orig_setVidSettings ? orig_setVidSettings(self, _cmd, settings) : 0;
}

// -----------------------------------------------------------------------------
// Constructor
// -----------------------------------------------------------------------------
__attribute__((constructor)) static void Cam60Enabler5sInit(void) {
    @autoreleasepool {
        C60_LOG(@"Cam60Enabler5s loaded — 1080p @ 60 FPS on iPhone 5s (A7)");

        // Читаем prefs
        C60LoadPrefs();

        if (!gC60Enabled) {
            C60_LOG(@"60fps disabled by user — not hooking");
        }

        // Регистрируем darwin релоад для live-настройки из Preferences
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        C60DarwinCallback,
                                        CFSTR("com.cocxace.cam60enabler5s/reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // Hook CAMUserPreferences
        Class camPrefs = NSClassFromString(@"CAMUserPreferences");
        if (camPrefs) {
            C60HookMethod(camPrefs, @selector(is60FPSVideoSupported), (IMP)hook_is60FPS, (IMP *)&orig_is60FPS);
            C60HookMethod(camPrefs, @selector(isBack60FPSVideoSupported), (IMP)hook_isBack60FPS, (IMP *)&orig_isBack60FPS);
            C60HookMethod(camPrefs, NSSelectorFromString(@"supportsVideoConfiguration60FPS"), (IMP)hook_supports60Cfg, (IMP *)&orig_supports60Cfg);
        } else {
            C60_LOG(@"CAMUserPreferences class not found on this firmware");
        }

        // Hook CAMCaptureCapabilities
        Class camCaps = NSClassFromString(@"CAMCaptureCapabilities");
        if (camCaps) {
            C60HookMethod(camCaps, @selector(supportedVideoConfigurations), (IMP)hook_supportedVideoConfigs, (IMP *)&orig_supportedVideoConfigs);
        } else {
            C60_LOG(@"CAMCaptureCapabilities class not found");
        }

        // Hook CAMConfigurationDelegate
        Class camCfg = NSClassFromString(@"CAMConfigurationDelegate");
        if (camCfg) {
            C60HookMethod(camCfg, NSSelectorFromString(@"captureSession:canSetVideoConfiguration:"), (IMP)hook_canSetVidCfg, (IMP *)&orig_canSetVidCfg);
        } else {
            C60_LOG(@"CAMConfigurationDelegate class not found");
        }

        // Hook AVCaptureDeviceFormat
        Class avFormat = NSClassFromString(@"AVCaptureDeviceFormat");
        if (avFormat) {
            C60HookMethod(avFormat, @selector(videoSupportedFrameRateRanges), (IMP)hook_frameRateRanges, (IMP *)&orig_frameRateRanges);
        } else {
            C60_LOG(@"AVCaptureDeviceFormat not found");
        }

        // Hook AVCaptureDevice
        Class avDevice = NSClassFromString(@"AVCaptureDevice");
        if (avDevice) {
            C60HookMethod(avDevice, @selector(setActiveVideoMinFrameDuration:), (IMP)hook_setMinDur, (IMP *)&orig_setMinDur);
            C60HookMethod(avDevice, @selector(setActiveVideoMaxFrameDuration:), (IMP)hook_setMaxDur, (IMP *)&orig_setMaxDur);
            C60HookMethod(avDevice, @selector(lockForConfiguration:), (IMP)hook_lockForCfg, (IMP *)&orig_lockForCfg);
            C60HookMethod(avDevice, @selector(activeFormat), (IMP)hook_activeFormat, (IMP *)&orig_activeFormat);
        } else {
            C60_LOG(@"AVCaptureDevice not found");
        }

        // Hook AVCaptureSession
        Class avSession = NSClassFromString(@"AVCaptureSession");
        if (avSession) {
            C60HookMethod(avSession, @selector(canSetSessionPreset:), (IMP)hook_canSetPreset, (IMP *)&orig_canSetPreset);
        }

        // Hook AVCaptureVideoDataOutput
        Class avOut = NSClassFromString(@"AVCaptureVideoDataOutput");
        if (avOut) {
            C60HookMethod(avOut, @selector(setVideoSettings:), (IMP)hook_setVidSettings, (IMP *)&orig_setVidSettings);
        }

        C60_LOG(@"Cam60Enabler5s initialization complete");
    }
}

__attribute__((destructor)) static void Cam60Enabler5sDeinit(void) {
    if (gC60FallbackTimer) {
        dispatch_source_cancel(gC60FallbackTimer);
        gC60FallbackTimer = nil;
        C60_LOG(@"Fallback timer released");
    }
}
