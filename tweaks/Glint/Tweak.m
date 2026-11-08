// Glint — Dynamic Island for iOS 12 notchless devices (com.cocxace.glint)
// v1.2.0: behaves like the real island (researched on Apple HIG):
//   • idle pill always visible, tap → related app, long-press → details card
//   • notifications auto-expand + glyph stays in the compact left slot
//   • charging banner + persistent ⚡ slot; now playing waveform bars
//   • size presets + feature switches from Settings (live reload)
// Everything runs on the main thread and is exception-guarded.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "GlintIslandView.h"

// dlsym and objc_msgSend come from libSystem, but iOS SDK has no public dlfcn.h/objc header.
extern void *dlsym(void *handle, const char *symbol);
extern id objc_msgSend(id self, SEL op, ...);

#pragma mark - Local interfaces (runtime-guarded before every call)

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

#pragma mark - Preferences (CFPreferences + darwin live reload)

typedef struct {
    BOOL enabled;
    NSInteger islandSize;       // 0 small / 1 normal / 2 large
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
            GlintPrefs p;
            p.enabled = YES; p.islandSize = 1;
            p.showNotifications = YES; p.showCharging = YES;
            p.showMedia = YES; p.showTorch = YES; p.showGreeting = YES;

            id raw = (__bridge id)CFPreferencesCopyAppValue(CFSTR("enabled"), CFSTR("com.cocxace.glint"));
            if (raw) {
                if ([raw isKindOfClass:[NSNumber class]]) p.enabled = [raw boolValue];
                if ([raw isKindOfClass:[NSString class]]) p.enabled = [(NSString *)raw boolValue];
            }

            id size = (__bridge id)CFPreferencesCopyAppValue(CFSTR("islandSize"), CFSTR("com.cocxace.glint"));
            if ([size isKindOfClass:[NSNumber class]]) p.islandSize = [size integerValue];
            if (p.islandSize < 0) p.islandSize = 0;
            if (p.islandSize > 2) p.islandSize = 2;

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
            if (raw) CFRelease((__bridge CFTypeRef)raw);
            if (size) CFRelease((__bridge CFTypeRef)size);

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

// Calls a property getter of a runtime object only if the class really implements it.
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
        NSLog(@"[Glint] app lookup error: %@", e);
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

        // SBApplication.icon returns SBApplicationIcon: rasterize through generateIconImage:0.
        SEL sel = NSSelectorFromString(@"generateIconImage:");
        if (iconObj && [iconObj respondsToSelector:sel]) {
            UIImage *img = ((UIImage *(*)(id, SEL, int))objc_msgSend)(iconObj, sel, 0);
            if ([img isKindOfClass:[UIImage class]] && img.size.width > 1) return img;
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] icon lookup error: %@", e);
    }
    return nil;
}

static NSString *GlintGlyphForBundleID(NSString *bundleID) {
    static NSDictionary<NSString *, NSString *> *map = nil;
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

#pragma mark - Notifications (BBServer publish hook)

// Picks the body line: only when it is real extra text (not a repeat of the title).
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
            BOOL chargingBulletin =
                [sectionID containsString:@"battery"] ||
                [sectionID containsString:@"power"];
            if (chargingBulletin && gPrefs.showCharging) return;   // charging has its own slot

            NSString *bulletinID = GlintStringOf(bulletin, @"bulletinID") ?: @"";
            NSString *title = GlintStringOf(bulletin, @"title");
            NSString *message = GlintStringOf(bulletin, @"message");

            if (sectionID.length == 0) return;               // junk without a source
            if (!title.length && !message.length) return;    // bulletins with nothing to show

            // Suppress duplicates (same message resent within a few seconds).
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
    if (orig_publishBulletin) {
        orig_publishBulletin(self, _cmd, bulletin, destinations);
    }
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
    orig_publishBulletin =
        (void (*)(id, SEL, id, unsigned long long))method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_publishBulletin);
    NSLog(@"[Glint] BBServer hooked — notifications now expand the island");
}

#pragma mark - Media (now playing) pump

static NSString *gLastTrack = nil;

static void GlintMediaTick(void) {
    @try {
        GlintIsland *island = [GlintIsland shared];
        if (!island.isSetup || !gPrefs.enabled) return;

        Class cls = NSClassFromString(@"SBMediaController");
        if (!cls) return;
        id media = GlintCallIfResponds(cls, @"sharedInstance");
        if (!media) return;

        NSString *track = GlintStringOf(media, @"nowPlayingTitle");
        NSString *artist = GlintStringOf(media, @"nowPlayingArtist");

        BOOL active = (track.length > 0);
        if (active != island.isNowPlayingActive) {
            [island setNowPlayingActive:active && gPrefs.showMedia];
        }

        if (!active) {
            gLastTrack = nil;
            return;
        }

        BOOL changed = (gLastTrack == nil) || ![gLastTrack isEqualToString:track];
        if (changed) {
            gLastTrack = [track copy];

            if (gPrefs.showMedia) {
                [island showNowPlayingTrack:track artist:artist];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] media error: %@", e);
    }
}

@interface GlintPump : NSObject
- (void)start;
- (void)tick:(NSTimer *)timer;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation GlintPump

+ (instancetype)sharedPump {
    static GlintPump *pump = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pump = [[GlintPump alloc] init];
    });
    return pump;
}

- (void)start {
    if (self.timer) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) return;
        self.timer = [NSTimer timerWithTimeInterval:2.0
                                             target:self
                                           selector:@selector(tick:)
                                           userInfo:nil
                                            repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    });
}

- (void)tick:(NSTimer *)timer {
    GlintMediaTick();
}

@end

#pragma mark - Torch watcher (KVO on the camera torch)

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
                NSLog(@"[Glint] no torch device available");
                return;
            }
            [_device addObserver:self
                      forKeyPath:@"torchMode"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:NULL];
            gLastTorchOn = (_device.torchMode == AVCaptureTorchModeOn);
        } @catch (NSException *e) {
            NSLog(@"[Glint] torch watcher error: %@", e);
            _device = nil;
        }
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:@"torchMode"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            GlintIsland *island = [GlintIsland shared];
            if (!island.isSetup || !gPrefs.enabled || !gPrefs.showTorch) return;
            BOOL on = (self->_device && self->_device.torchMode == AVCaptureTorchModeOn);
            if (on == gLastTorchOn) return;
            gLastTorchOn = on;
            [island showTorchOn:on];
        } @catch (NSException *e) {
            NSLog(@"[Glint] torch observe error: %@", e);
        }
    });
}

@end

#pragma mark - Charging watch (IOPS APIs + darwin power notification)

typedef CFTypeRef (*IOPSCopyPowerSourcesInfoFn)(void);
typedef CFArrayRef (*IOPSCopyPowerSourcesListFn)(CFTypeRef blob);
typedef CFDictionaryRef (*IOPSGetPowerSourceDescriptionFn)(CFTypeRef blob, CFTypeRef source);

static BOOL gChargingNow = NO;
static BOOL gFirstChargeTickDone = NO;

static NSDictionary<NSString *, id> *GlintIOPSDictionary(CFTypeRef blob, CFTypeRef source) {
    IOPSGetPowerSourceDescriptionFn getDesc =
        (IOPSGetPowerSourceDescriptionFn)dlsym(NULL, "IOPSGetPowerSourceDescription");
    if (!getDesc) return nil;
    CFDictionaryRef dict = getDesc(blob, source);
    if (!dict) return nil;
    return (__bridge_transfer NSDictionary<NSString *, id> *)dict;
}

static BOOL GlintReadBattery(NSInteger *levelOut, BOOL *chargingOut, BOOL *pluggedOut) {
    @try {
        IOPSCopyPowerSourcesInfoFn copyInfo =
            (IOPSCopyPowerSourcesInfoFn)dlsym(NULL, "IOPSCopyPowerSourcesInfo");
        IOPSCopyPowerSourcesListFn copyList =
            (IOPSCopyPowerSourcesListFn)dlsym(NULL, "IOPSCopyPowerSourcesList");
        if (!copyInfo || !copyList) return NO;

        CFTypeRef blob = copyInfo();
        if (!blob) return NO;
        @try {
            CFArrayRef list = copyList(blob);
            if (!list) return NO;
            CFIndex count = CFArrayGetCount(list);
            for (CFIndex i = 0; i < count; i++) {
                NSDictionary *dict = GlintIOPSDictionary(blob, CFArrayGetValueAtIndex(list, i));
                if (!dict) continue;

                NSString *state = dict[@"Power Source State"];
                NSNumber *isCharging = dict[@"Is Charging"];
                NSNumber *capacity = dict[@"Current Capacity"];
                NSNumber *maxCap = dict[@"Max Capacity"];

                if ([state isKindOfClass:[NSString class]] &&
                    [(NSString *)state containsString:@"AC"] && capacity) {
                    NSInteger cap = [capacity isKindOfClass:[NSNumber class]] ? capacity.integerValue : 50;
                    NSInteger max = ([maxCap isKindOfClass:[NSNumber class]] && maxCap.integerValue > 0)
                                        ? maxCap.integerValue
                                        : 100;
                    NSInteger percent = max > 0 ? (cap * 100) / max : cap;
                    if (percent > 100) percent = 100;
                    if (levelOut) *levelOut = percent;
                    if (chargingOut) *chargingOut = isCharging.boolValue;
                    if (pluggedOut) *pluggedOut = YES;
                    return YES;
                }
            }
        } @finally {
            CFRelease(blob);
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] battery read error: %@", e);
    }
    if (pluggedOut) *pluggedOut = NO;
    return NO;
}

// Runs on the main queue.
static void GlintChargeTick(BOOL showPill) {
    @try {
        GlintIsland *island = [GlintIsland shared];

        NSInteger level = 0;
        BOOL charging = NO, plugged = NO;
        GlintReadBattery(&level, &charging, &plugged);

        BOOL firstTick = !gFirstChargeTickDone;
        gFirstChargeTickDone = YES;

        if (!island.isSetup || !gPrefs.enabled) return;

        if (plugged && gPrefs.showCharging) {
            [island setChargingSlotLevel:level orNil:NO];
        } else if (island.isSetup) {
            [island setChargingSlotLevel:0 orNil:YES];
        }

        if (!gPrefs.showCharging) {
            gChargingNow = charging;
            return;
        }

        if (charging) {
            // Show the pill when charging starts, or as reminder once at boot.
            if (showPill && (!gChargingNow || firstTick)) {
                [island showChargingAtLevel:level];
            }
        } else if (gChargingNow && plugged && showPill) {
            // Plugged but not charging: quick 100% style pill.
            [island showChargingAtLevel:100];
        }
        gChargingNow = charging;
    } @catch (NSException *e) {
        NSLog(@"[Glint] charge tick error: %@", e);
    }
}

static void GlintRegisterChargeWatch(void) {
    static BOOL registered = NO;
    if (registered) return;
    registered = YES;

    uint32_t token = 0;
    notify_register_dispatch("com.apple.iokit.powerSource",
                             &token,
                             dispatch_get_main_queue(),
                             ^(int note) {
                                 GlintChargeTick(YES);
                             });
}

#pragma mark - Boot

// Kept alive to retain KVO observers.
static GlintTorchWatcher *gTorchWatcher = nil;

static void GlintBootOnMain(void) {
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

            // Prime the charging state so a replug later triggers the pill.
            GlintChargeTick(NO);

            GlintRegisterChargeWatch();
        } @catch (NSException *e) {
            NSLog(@"[Glint] boot error: %@", e);
        }
    });
}

// Reads prefs preemptively so the boot pipeline picks up the correct layout.
static void GlintLoadPrefsNow(void) {
    GlintLoadPrefsOnMain();
}

#pragma mark - Preferences reload listener

static void GlintDarwinCallback(CFNotificationCenterRef center, void *observer,
                                CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    CFPreferencesAppSynchronize(CFSTR("com.cocxace.glint"));
    GlintLoadPrefsOnMain();
}

static void GlintInstallPrefsObserver(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    GlintDarwinCallback,
                                    CFSTR("com.cocxace.glint/reload"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

static void (*orig_appDidFinishLaunching)(id self, SEL _cmd, id app);
static void hook_appDidFinishLaunching(id self, SEL _cmd, id app) {
    if (orig_appDidFinishLaunching) {
        orig_appDidFinishLaunching(self, _cmd, app);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        GlintBootOnMain();
    });
}

__attribute__((constructor)) static void initGlint(void) {
    @autoreleasepool {
        NSLog(@"[Glint] loaded — Dynamic Island core for iOS 12");

        GlintInstallPrefsObserver();
        GlintLoadPrefsNow();

        Class sb = objc_getClass("SpringBoard");
        if (sb) {
            Method m = class_getInstanceMethod(sb, sel_registerName("applicationDidFinishLaunching:"));
            if (m) {
                orig_appDidFinishLaunching = (void (*)(id, SEL, id))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_appDidFinishLaunching);
                NSLog(@"[Glint] SpringBoard launch hook installed");
            }
        }

        GlintHookBBServer();
    }
}
