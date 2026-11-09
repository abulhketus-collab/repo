// Glint — Dynamic Island for iOS 12 notchless devices (com.cocxace.glint)
// v1.2.1: fixed — real tap handling, app launch fallback, MSHookMessageEx hooks,
// boot timer fallback if applicationDidFinishLaunching: is not available.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "GlintIslandView.h"

extern void *dlsym(void *handle, const char *symbol);
extern id objc_msgSend(id self, SEL op, ...);

#ifdef __cplusplus
extern "C" {
#endif
void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);
#ifdef __cplusplus
}
#endif

#pragma mark - Local interfaces (runtime-guarded)

@interface SBApplication : NSObject
- (NSString *)displayName;
- (NSString *)bundleIdentifier;
- (id)icon;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithDisplayIdentifier:(NSString *)bundleIdentifier;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (NSString *)nowPlayingTitle;
- (NSString *)nowPlayingArtist;
- (SBApplication *)nowPlayingApplication;
@end

@interface BBBulletin : NSObject
@property (nonatomic, copy) NSString *sectionID;
@property (nonatomic, copy) NSString *bulletinID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *message;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID suspended:(BOOL)suspended;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID;
@end

#pragma mark - Preferences

typedef struct {
    BOOL enabled;
    NSInteger islandSize;
    BOOL showNotifications;
    BOOL showCharging;
    BOOL showMedia;
    BOOL showTorch;
    BOOL showGreeting;
} GlintPrefs;

static GlintPrefs gPrefs = { YES, 1, YES, YES, YES, YES, YES };

static void GlintLoadPrefsOnMain(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            GlintPrefs p = { YES, 1, YES, YES, YES, YES, YES };

            id raw = (__bridge id)CFPreferencesCopyAppValue(CFSTR("enabled"), CFSTR("com.cocxace.glint"));
            if (raw) {
                if ([raw isKindOfClass:[NSNumber class]]) p.enabled = [raw boolValue];
                if ([raw isKindOfClass:[NSString class]]) p.enabled = [(NSString *)raw boolValue];
                CFRelease((__bridge CFTypeRef)raw);
            }

            id size = (__bridge id)CFPreferencesCopyAppValue(CFSTR("islandSize"), CFSTR("com.cocxace.glint"));
            if ([size isKindOfClass:[NSNumber class]]) {
                p.islandSize = [size integerValue];
                if (p.islandSize < 0) p.islandSize = 0;
                if (p.islandSize > 2) p.islandSize = 2;
                CFRelease((__bridge CFTypeRef)size);
            }

            static NSString *keys[] = { @"showNotifications", @"showCharging", @"showMedia", @"showTorch", @"showGreeting" };
            BOOL *targets[] = { &p.showNotifications, &p.showCharging, &p.showMedia, &p.showTorch, &p.showGreeting };
            for (int i = 0; i < 5; i++) {
                id v = (__bridge id)CFPreferencesCopyAppValue((__bridge CFStringRef)keys[i], CFSTR("com.cocxace.glint"));
                if (v) {
                    if ([v isKindOfClass:[NSNumber class]]) *targets[i] = [v boolValue];
                    if ([v isKindOfClass:[NSString class]]) *targets[i] = [(NSString *)v boolValue];
                    CFRelease((__bridge CFTypeRef)v);
                }
            }

            gPrefs = p;

            GlintIsland *island = [GlintIsland shared];
            if (island.isSetup) {
                [island applySizePreset:gPrefs.islandSize];
                [island setIslandHidden:!gPrefs.enabled];
            }
        } @catch (NSException *e) {
            NSLog(@"[Glint] prefs load error: %@", e);
        }
    });
}

#pragma mark - Helpers

static NSTimeInterval GlintNow() {
    return [NSDate timeIntervalSinceReferenceDate];
}

static id GlintCallIfResponds(id obj, NSString *selectorName) {
    if (!obj || selectorName.length == 0) return nil;
    SEL sel = NSSelectorFromString(selectorName);
    if (![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static NSString *GlintStringOf(id obj, NSString *selectorName) {
    id value = GlintCallIfResponds(obj, selectorName);
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return (NSString *)value;
    }
    return nil;
}

static id GlintAppForBundleID(NSString *bundleID) {
    if (!bundleID.length) return nil;
    @try {
        Class cls = NSClassFromString(@"SBApplicationController");
        if (!cls) return nil;
        id controller = GlintCallIfResponds(cls, @"sharedInstance");
        if (!controller) return nil;
        return ((id (*)(id, SEL, id))objc_msgSend)(
            controller,
            NSSelectorFromString(@"applicationWithDisplayIdentifier:"),
            bundleID);
    } @catch (NSException *e) {
        return nil;
    }
}

static NSString *GlintAppName(NSString *bundleID) {
    id app = GlintAppForBundleID(bundleID);
    NSString *name = GlintStringOf(app, @"displayName");
    if (name) return name;
    return bundleID.lastPathComponent ?: @"Application";
}

static UIImage *GlintAppIcon(NSString *bundleID) {
    @try {
        id app = GlintAppForBundleID(bundleID);
        if (!app) return nil;
        id iconObj = GlintCallIfResponds(app, @"icon");
        if ([iconObj isKindOfClass:[UIImage class]]) return (UIImage *)iconObj;
        SEL sel = NSSelectorFromString(@"generateIconImage:");
        if (iconObj && [iconObj respondsToSelector:sel]) {
            UIImage *img = ((UIImage *(*)(id, SEL, int))objc_msgSend)(iconObj, sel, 0);
            if ([img isKindOfClass:[UIImage class]] && img.size.width > 1) return img;
        }
    } @catch (NSException *e) {
        return nil;
    }
    return nil;
}

static NSString *GlintGlyphForBundleID(NSString *bundleID) {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"com.apple.mobilesms":   @"💬",
            @"com.apple.mobilemail":  @"📧",
            @"com.apple.facetime":    @"📹",
            @"com.apple.mobilephone": @"☎️",
            @"com.apple.mobiletimer": @"⏰",
            @"com.apple.mobilenotes": @"📝",
            @"com.apple.reminders":   @"✅",
            @"com.apple.mobilecal":   @"📅",
            @"net.whatsapp.whatsapp": @"🟢",
            @"com.burbn.instagram":   @"📸",
            @"com.facebook.Facebook": @"📘",
            @"org.telegram.Telegram": @"✈️",
        };
    });
    if (!bundleID.length) return @"📱";
    return map[[bundleID lowercaseString]] ?: @"📱";
}

#pragma mark - Notifications (BBServer)

static NSString *GlintBulletinBody(NSString *title, NSString *message) {
    if (title.length > 0 && message.length > 0 && ![message isEqualToString:title]) return message;
    return nil;
}

static NSTimeInterval gLastBulletinAt = 0;
static NSString *gLastBulletinKey = nil;

static void GlintHandleBulletin(id bulletin) {
    if (!bulletin) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gPrefs.enabled || !gPrefs.showNotifications) return;
            GlintIsland *island = [GlintIsland shared];
            if (!island.isSetup) return;

            NSString *sectionID = GlintStringOf(bulletin, @"sectionID") ?: @"";
            NSString *bulletinID = GlintStringOf(bulletin, @"bulletinID") ?: @"";
            NSString *title = GlintStringOf(bulletin, @"title");
            NSString *message = GlintStringOf(bulletin, @"message");

            if (sectionID.length == 0) return;
            if (!title.length && !message.length) return;

            NSString *key = [NSString stringWithFormat:@"%@|%@", sectionID, bulletinID];
            NSTimeInterval now = GlintNow();
            if ([key isEqualToString:gLastBulletinKey] && (now - gLastBulletinAt) < 4.0) return;
            gLastBulletinKey = [key copy];
            gLastBulletinAt = now;

            UIImage *icon = GlintAppIcon(sectionID);
            NSString *appName = GlintAppName(sectionID);

            [island showEventForApp:appName
                             bundle:sectionID
                              glyph:GlintGlyphForBundleID(sectionID)
                               icon:icon
                              title:(title.length ? title : message)
                            message:GlintBulletinBody(title, message)];
        } @catch (NSException *e) {
            NSLog(@"[Glint] bulletin error: %@", e);
        }
    });
}

static void (*orig_publishBulletin)(id self, SEL _cmd, id bulletin, unsigned long long destinations);
static void hook_publishBulletin(id self, SEL _cmd, id bulletin, unsigned long long destinations) {
    if (orig_publishBulletin) orig_publishBulletin(self, _cmd, bulletin, destinations);
    GlintHandleBulletin(bulletin);
}

static void GlintHookBBServer(void) {
    Class cls = objc_getClass("BBServer");
    if (!cls) {
        NSLog(@"[Glint] BBServer not available on this firmware");
        return;
    }
    SEL sel = sel_registerName("publishBulletin:destinations:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        NSLog(@"[Glint] publishBulletin:destinations: not available");
        return;
    }
    MSHookMessageEx(cls, sel, (IMP)&hook_publishBulletin, (IMP *)&orig_publishBulletin);
    NSLog(@"[Glint] BBServer hooked");
}

#pragma mark - Media pump

static NSString *gLastTrack = nil;

static void GlintMediaTick(void) {
    @try {
        GlintIsland *island = [GlintIsland shared];
        if (!island.isSetup || !gPrefs.enabled || !gPrefs.showMedia) return;

        Class cls = NSClassFromString(@"SBMediaController");
        if (!cls) return;
        id media = GlintCallIfResponds(cls, @"sharedInstance");
        if (!media) return;

        NSString *track = GlintStringOf(media, @"nowPlayingTitle");
        NSString *artist = GlintStringOf(media, @"nowPlayingArtist");

        BOOL active = (track.length > 0);
        if (active != island.isNowPlayingActive) {
            [island setNowPlayingActive:active];
        }

        if (!active) {
            gLastTrack = nil;
            return;
        }

        if (gLastTrack == nil || ![gLastTrack isEqualToString:track]) {
            gLastTrack = [track copy];

            id app = GlintCallIfResponds(media, @"nowPlayingApplication");
            NSString *bid = GlintStringOf(app, @"bundleIdentifier");
            UIImage *icon = bid.length ? GlintAppIcon(bid) : nil;
            NSString *appName = bid.length ? GlintStringOf(app, @"displayName") : nil;

            [island showNowPlayingTrack:track artist:artist];

            if (appName.length || bid.length) {
                [island showEventForApp:(appName.length ? appName : @"Now Playing")
                                 bundle:bid.length ? bid : @"com.apple.mobilemusic"
                                  glyph:@"🎧"
                                   icon:icon
                                  title:track
                                message:(artist.length ? [@"♪ " stringByAppendingString:artist] : nil)];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] media error: %@", e);
    }
}

#pragma mark - Timer deep search

static void TimerDeepSearch(id node, NSDate **endDate, CGFloat *secondsLeft, BOOL *paused) {
    if (!node) return;
    @try {
        if ([node isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)node;
            for (NSString *key in dict) {
                NSString *lk = key.lowercaseString;
                id val = dict[key];
                if ([val isKindOfClass:[NSNumber class]] &&
                    ([lk containsString:@"secondsremaining"] || [lk containsString:@"timeleft"] || [lk containsString:@"remainingtime"])) {
                    CGFloat v = [(NSNumber *)val doubleValue];
                    if (v > 0 && v < 86400.0 && *secondsLeft < 0) *secondsLeft = v;
                }
                if ([val isKindOfClass:[NSDate class]] &&
                    ([lk containsString:@"enddate"] || [lk containsString:@"firedate"] || [lk containsString:@"targetdate"] || [lk containsString:@"countdowndate"])) {
                    NSTimeInterval delta = [(NSDate *)val timeIntervalSinceNow];
                    if (delta > 0 && delta < 86400.0 && !*endDate) *endDate = val;
                }
                if ([val isKindOfClass:[NSNumber class]] &&
                    ([lk isEqualToString:@"paused"] || [lk isEqualToString:@"ispaused"])) {
                    if ([(NSNumber *)val boolValue]) *paused = YES;
                }
                TimerDeepSearch(val, endDate, secondsLeft, paused);
            }
        } else if ([node isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)node) {
                TimerDeepSearch(item, endDate, secondsLeft, paused);
            }
        }
    } @catch (NSException *e) {}
}

static NSInteger GlintGetTimerRemaining(void) {
    @try {
        NSArray *candidateKeys = @[@"timerState", @"timer", @"timers", @"countdown", @"countdownTimer", @"state"];
        for (NSString *ck in candidateKeys) {
            CFTypeRef raw = CFPreferencesCopyAppValue((CFStringRef)ck, CFSTR("com.apple.mobiletimerd"));
            if (!raw) continue;
            NSDictionary *dict = nil;
            if (CFGetTypeID(raw) == CFDictionaryGetTypeID()) {
                dict = [(__bridge NSDictionary *)raw copy];
            } else if (CFGetTypeID(raw) == CFArrayGetTypeID()) {
                dict = @{@"wrapped": (__bridge NSArray *)raw};
            }
            CFRelease(raw);
            if (dict) {
                NSDate *endDate = nil;
                CGFloat secondsLeft = -1.0;
                BOOL paused = NO;
                TimerDeepSearch(dict, &endDate, &secondsLeft, &paused);
                if (endDate && !paused) {
                    CGFloat delta = (CGFloat)[endDate timeIntervalSinceNow];
                    if (delta > 0 && delta < 86400.0) return (NSInteger)delta;
                }
                if (secondsLeft > 0 && !paused) return (NSInteger)secondsLeft;
            }
        }
    } @catch (NSException *e) {}
    return -1;
}

static BOOL gTimerWasActive = NO;

static void GlintTimerTick(void) {
    @try {
        GlintIsland *island = [GlintIsland shared];
        if (!island.isSetup || !gPrefs.enabled) return;

        NSInteger remaining = GlintGetTimerRemaining();
        if (remaining > 0) {
            gTimerWasActive = YES;
            [island showTimerCountdown:remaining];
        } else {
            if (gTimerWasActive && remaining == 0) {
                gTimerWasActive = NO;
                [island showTimerDone];
            } else if (gTimerWasActive && remaining < 0) {
                gTimerWasActive = NO;
                [island clearTimerCountdown];
            }
        }
    } @catch (NSException *e) {}
}

@interface GlintPump : NSObject
- (void)start;
- (void)tick:(NSTimer *)timer;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger tickCount;
@end

@implementation GlintPump
+ (instancetype)sharedPump {
    static GlintPump *p = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ p = [[GlintPump alloc] init]; });
    return p;
}
- (void)start {
    if (self.timer) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) return;
        self.tickCount = 0;
        self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    });
}
- (void)tick:(NSTimer *)timer {
    self.tickCount++;
    GlintTimerTick();
    if (self.tickCount % 2 == 0) {
        GlintMediaTick();
    }
}
@end

#pragma mark - Torch

static BOOL gLastTorchOn = NO;

@interface GlintTorchWatcher : NSObject
- (void)start;
@end

@implementation GlintTorchWatcher {
    AVCaptureDevice *_device;
    BOOL _started;
}
- (void)start {
    if (_started) return;
    _started = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            if (!_device || !_device.hasTorch) {
                _device = nil;
                return;
            }
            [_device addObserver:self forKeyPath:@"torchMode"
                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                       context:NULL];
            gLastTorchOn = (_device.torchMode == AVCaptureTorchModeOn);
        } @catch (NSException *e) {
            _device = nil;
        }
    });
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (![keyPath isEqualToString:@"torchMode"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gPrefs.enabled || !gPrefs.showTorch) return;
            BOOL on = (self->_device && self->_device.torchMode == AVCaptureTorchModeOn);
            if (on == gLastTorchOn) return;
            gLastTorchOn = on;
            [[GlintIsland shared] showTorchOn:on];
        } @catch (NSException *e) {}
    });
}
@end

#pragma mark - Charging

typedef CFTypeRef (*IOPSCopyPowerSourcesInfoFn)(void);
typedef CFArrayRef (*IOPSCopyPowerSourcesListFn)(CFTypeRef);
typedef CFDictionaryRef (*IOPSGetPowerSourceDescriptionFn)(CFTypeRef, CFTypeRef);

static BOOL gChargingNow = NO;
static BOOL gFirstChargeTickDone = NO;

static NSDictionary *GlintIOPSDictionary(CFTypeRef blob, CFTypeRef source) {
    IOPSGetPowerSourceDescriptionFn getDesc = (IOPSGetPowerSourceDescriptionFn)dlsym(NULL, "IOPSGetPowerSourceDescription");
    if (!getDesc) return nil;
    CFDictionaryRef dict = getDesc(blob, source);
    return dict ? (__bridge_transfer NSDictionary *)dict : nil;
}

static BOOL GlintReadBattery(NSInteger *lvl, BOOL *chg, BOOL *plug) {
    @try {
        IOPSCopyPowerSourcesInfoFn copyInfo = (IOPSCopyPowerSourcesInfoFn)dlsym(NULL, "IOPSCopyPowerSourcesInfo");
        IOPSCopyPowerSourcesListFn copyList = (IOPSCopyPowerSourcesListFn)dlsym(NULL, "IOPSCopyPowerSourcesList");
        if (!copyInfo || !copyList) return NO;
        CFTypeRef blob = copyInfo();
        if (!blob) return NO;
        @try {
            CFArrayRef list = copyList(blob);
            if (!list) return NO;
            for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
                NSDictionary *dict = GlintIOPSDictionary(blob, CFArrayGetValueAtIndex(list, i));
                if (!dict) continue;
                NSString *state = dict[@"Power Source State"];
                NSNumber *isCharging = dict[@"Is Charging"];
                NSNumber *capacity = dict[@"Current Capacity"];
                if ([state isKindOfClass:[NSString class]] && [(NSString *)state containsString:@"AC"] && capacity) {
                    NSInteger cap = [capacity isKindOfClass:[NSNumber class]] ? capacity.integerValue : 50;
                    NSInteger max = ([dict[@"Max Capacity"] isKindOfClass:[NSNumber class]] && [dict[@"Max Capacity"] integerValue] > 0)
                                        ? [dict[@"Max Capacity"] integerValue] : 100;
                    NSInteger pct = max > 0 ? (cap * 100) / max : cap;
                    if (pct > 100) pct = 100;
                    if (lvl) *lvl = pct;
                    if (chg) *chg = isCharging.boolValue;
                    if (plug) *plug = YES;
                    return YES;
                }
            }
        } @finally { CFRelease(blob); }
    } @catch (NSException *e) {}
    if (plug) *plug = NO;
    return NO;
}

static void GlintChargeTick(BOOL showPill) {
    @try {
        GlintIsland *island = [GlintIsland shared];
        NSInteger lvl = 0; BOOL chg = NO, plug = NO;
        GlintReadBattery(&lvl, &chg, &plug);
        BOOL first = !gFirstChargeTickDone;
        gFirstChargeTickDone = YES;
        if (!island.isSetup || !gPrefs.enabled || !gPrefs.showCharging) { gChargingNow = chg; return; }

        if (plug) {
            [island setChargingSlotLevel:lvl orNil:NO];
        } else {
            [island setChargingSlotLevel:0 orNil:YES];
        }

        if (chg) {
            if (showPill && (!gChargingNow || first)) {
                [island showChargingAtLevel:lvl];
            }
        } else if (gChargingNow && plug && showPill) {
            [island showChargingAtLevel:100];
        }
        gChargingNow = chg;
    } @catch (NSException *e) {}
}

static void GlintRegisterChargeWatch(void) {
    static BOOL reg = NO;
    if (reg) return;
    reg = YES;
    int token = 0;
    notify_register_dispatch("com.apple.iokit.powerSource", &token, dispatch_get_main_queue(),
                             ^(int note) { GlintChargeTick(YES); });
}

#pragma mark - Boot

static GlintTorchWatcher *gTorchWatcher = nil;
static BOOL gBootDone = NO;

static void GlintBootOnMain(void) {
    if (gBootDone) return;
    gBootDone = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            GlintIsland *island = [GlintIsland shared];
            [island setup];
            [island applySizePreset:gPrefs.islandSize];

            if (!gPrefs.enabled) {
                [island setIslandHidden:YES];
            } else if (gPrefs.showGreeting) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    [[GlintIsland shared] showBootGreeting];
                });
            }

            [[GlintPump sharedPump] start];

            if (!gTorchWatcher) {
                gTorchWatcher = [[GlintTorchWatcher alloc] init];
                [gTorchWatcher start];
            }

            GlintChargeTick(NO);
            GlintRegisterChargeWatch();
        } @catch (NSException *e) {
            NSLog(@"[Glint] boot error: %@", e);
        }
    });
}

static void GlintDarwinCallback(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
    CFPreferencesAppSynchronize(CFSTR("com.cocxace.glint"));
    GlintLoadPrefsOnMain();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintIsland shared] applyGlowPrefs];
    });
}

static void GlintInstallPrefsObserver(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    GlintDarwinCallback, CFSTR("com.cocxace.glint/reload"),
                                    NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

static void (*orig_appDidFinishLaunching)(id self, SEL _cmd, id app);
static void hook_appDidFinishLaunching(id self, SEL _cmd, id app) {
    if (orig_appDidFinishLaunching) orig_appDidFinishLaunching(self, _cmd, app);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ GlintBootOnMain(); });
}

// Fallback timer: if applicationDidFinishLaunching: hook never fired, still boot the island.
static dispatch_source_t gBootFallbackTimer = nil;
static void GlintBootFallbackTimerTick(void) {
    if (gBootDone) { dispatch_source_cancel(gBootFallbackTimer); gBootFallbackTimer = nil; return; }
    static NSInteger tries = 0;
    tries++;
    if (tries > 20) { dispatch_source_cancel(gBootFallbackTimer); gBootFallbackTimer = nil; NSLog(@"[Glint] boot fallback gave up"); return; }
    Class sb = objc_getClass("SpringBoard");
    if (sb) { GlintBootOnMain(); dispatch_source_cancel(gBootFallbackTimer); gBootFallbackTimer = nil; }
}

__attribute__((constructor)) static void initGlint(void) {
    @autoreleasepool {
        NSLog(@"[Glint] loaded — Dynamic Island core for iOS 12");

        GlintInstallPrefsObserver();
        CFPreferencesAppSynchronize(CFSTR("com.cocxace.glint"));
        GlintLoadPrefsOnMain();

        Class sb = objc_getClass("SpringBoard");
        if (sb) {
            Method m = class_getInstanceMethod(sb, sel_registerName("applicationDidFinishLaunching:"));
            if (m) {
                orig_appDidFinishLaunching = (void (*)(id, SEL, id))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_appDidFinishLaunching);
                NSLog(@"[Glint] SpringBoard launch hook installed");
            } else {
                NSLog(@"[Glint] applicationDidFinishLaunching: not found — using boot timer fallback");
                gBootFallbackTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
                dispatch_source_set_timer(gBootFallbackTimer, dispatch_walltime(NULL, 1.0 * NSEC_PER_SEC), 1.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
                dispatch_source_set_event_handler(gBootFallbackTimer, ^{ GlintBootFallbackTimerTick(); });
                dispatch_resume(gBootFallbackTimer);
            }
        }

        GlintHookBBServer();
    }
}
