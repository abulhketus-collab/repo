// Lumina вЂ” Always-On-Display styled lock screen for iOS 12 (com.cocxace.lumina)
// v1.2.2: UIWindow-based overlay (no orphaned views), CFPreferences,
// live reload via darwin notification, destroy on respring / disable.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <os/log.h>

#import "LuminaPrefs.h"

#define LuminaLog(fmt, ...) \
    do { if ([LuminaPrefs sharedPrefs].debugEnabled) \
        os_log(OS_LOG_DEFAULT, "[Lumina] %s: " fmt, __PRETTY_FUNCTION__, ##__VA_ARGS__); } while (0)

#pragma mark - AOD window

static UIWindow *aodWindow = nil;
static UILabel *aodClock = nil;
static UILabel *aodDate = nil;
static NSTimer *aodTimer = nil;

@interface LuminaTimerStub : NSObject
+ (instancetype)sharedStub;
- (void)theTick;
@end

@implementation LuminaTimerStub

+ (instancetype)sharedStub {
    static LuminaTimerStub *stub = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        stub = [[LuminaTimerStub alloc] init];
    });
    return stub;
}

- (void)theTick {
    dispatch_async(dispatch_get_main_queue(), ^{
        [LuminaUpdateFace];
    });
}

@end

static void LuminaUpdateFace(void) {
    @try {
        NSDateFormatter *clock = [[NSDateFormatter alloc] init];
        [clock setDateFormat:@"HH:mm"];
        aodClock.text = [clock stringFromDate:[NSDate date]];

        NSDateFormatter *date = [[NSDateFormatter alloc] init];
        [date setDateFormat:@"EEE, d MMM"];
        aodDate.text = [date stringFromDate:[NSDate date]];
    } @catch (NSException *e) {}
}

static void LuminaFade(double alpha, double duration) {
    if (!aodWindow) return;
    [UIView animateWithDuration:duration animations:^{
        aodWindow.alpha = alpha;
        aodDate.alpha = [LuminaPrefs boolForKey:@"showDate" defaultValue:YES] ? 1.0 : 0.0;
    }];
}

- (void)showAOD {
    if (aodWindow) return;
    if (![LuminaPrefs boolForKey:@"enabled" defaultValue:YES]) return;

    aodWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    aodWindow.windowLevel = 2000.f;
    aodWindow.backgroundColor = [UIColor blackColor];
    aodWindow.alpha = 0.0;
    aodWindow.userInteractionEnabled = NO;
    aodWindow.rootViewController = [[UIViewController alloc] init];
    aodWindow.hidden = NO;
    [aodWindow makeKeyAndVisible];

    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGFloat H = [UIScreen mainScreen].bounds.size.height;

    aodClock = [[UILabel alloc] initWithFrame:CGRectMake(0, H * 0.30, W, 90)];
    aodClock.textColor = [UIColor whiteColor];
    aodClock.font = [UIFont systemFontOfSize:62.0 weight:UIFontWeightUltraLight];
    aodClock.textAlignment = NSTextAlignmentCenter;
    aodClock.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [aodWindow addSubview:aodClock];

    aodDate = [[UILabel alloc] initWithFrame:CGRectMake(0, H * 0.30 + 96.0, W, 24)];
    aodDate.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    aodDate.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    aodDate.textAlignment = NSTextAlignmentCenter;
    aodDate.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [aodWindow addSubview:aodDate];

    [LuminaUpdateFace];

    aodTimer = [NSTimer timerWithTimeInterval:1.0
                                      target:[LuminaTimerStub sharedStub]
                                    selector:@selector(theTick)
                                    userInfo:nil
                                     repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:aodTimer forMode:NSRunLoopCommonModes];

    LuminaFade([LuminaPrefs floatForKey:@"opacity" defaultValue:0.90f], 0.5);
}

- (void)hideAOD {
    if (!aodWindow) return;
    [aodTimer invalidate];
    aodTimer = nil;
    aodWindow.hidden = YES;
    aodWindow.rootViewController = nil;
    aodWindow = nil;
    aodClock = nil;
    aodDate = nil;
}

- (void)destroy {
    [self hideAOD];
    LuminaLog(@"destroy");
}

#pragma mark - Hooks

static void (*orig_viewWillAppear)(id self, SEL _cmd, BOOL animated);
static void (*orig_viewWillDisappear)(id self, SEL _cmd, BOOL animated);

static void hook_viewWillAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_viewWillAppear) ((void (*)(id, SEL, BOOL))orig_viewWillAppear)(self, _cmd, animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (![LuminaPrefs boolForKey:@"enabled" defaultValue:YES]) return;
            [self showAOD];
        } @catch (NSException *e) {
            NSLog(@"[Tweak Error] Lumina appear: %@", e);
        }
    });
}

static void hook_viewWillDisappear(id self, SEL _cmd, BOOL animated) {
    if (orig_viewWillDisappear) ((void (*)(id, SEL, BOOL))orig_viewWillDisappear)(self, _cmd, animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self hideAOD];
        } @catch (NSException *e) {}
    });
}

#pragma mark - Prefs reload

static void LuminaDarwinCallback(CFNotificationCenterRef center, void *observer,
                                 CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (![LuminaPrefs boolForKey:@"enabled" defaultValue:YES]) {
                [self hideAOD];
                return;
            }
            if (aodWindow && aodWindow.alpha > 0.0) {
                [LuminaUpdateFace];
                LuminaFade([LuminaPrefs floatForKey:@"opacity" defaultValue:0.90f], 0.3);
            }
        } @catch (NSException *e) {}
    });
}

__attribute__((constructor)) static void initLumina() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Lumina 1.2.3 loaded");

        [LuminaPrefs registerDefaults];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LuminaDarwinCallback,
                                        CFSTR("com.cocxace.lumina/reload"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        Class cls = objc_getClass("SBLockScreenViewControllerBase");
        if (cls) {
            Method m1 = class_getInstanceMethod(cls, sel_registerName("viewWillAppear:"));
            if (m1) {
                orig_viewWillAppear = (void (*)(id, SEL, BOOL))method_getImplementation(m1);
                method_setImplementation(m1, (IMP)hook_viewWillAppear);
                NSLog(@"[CocxaceTweak] Lumina appear hook installed");
            }
            Method m2 = class_getInstanceMethod(cls, sel_registerName("viewWillDisappear:"));
            if (m2) {
                orig_viewWillDisappear = (void (*)(id, SEL, BOOL))method_getImplementation(m2);
                method_setImplementation(m2, (IMP)hook_viewWillDisappear);
            }
        } else {
            NSLog(@"[Tweak Error] Lumina: SBLockScreenViewControllerBase not found");
        }
    }
}

// Р”РµСЃС‚СЂСѓРєС‚РѕСЂ: С‡РёСЃС‚РёРј AOD РѕРєРЅРѕ РїСЂРё РІС‹РіСЂСѓР·РєРµ tweak (%c / respring)
__attribute__((destructor)) static void cleanupLumina(void) {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Lumina destructor вЂ” cleaning up AOD window");
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                hideAOD();
            } @catch (NSException *e) {}
        });
    }
}
