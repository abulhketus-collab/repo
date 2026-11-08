// Lumina — Always-On-Display styled lock screen for iOS 12 (com.cocxace.lumina)
// v1.2.0: opacity presets + showDate + enabled from the Settings pane,
// live reload via darwin notification, stale overlay re-attach fix.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Preferences

static NSDictionary *LuminaPrefs = nil;

static void LuminaReloadPrefs(void) {
    LuminaPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.lumina.plist"] ?: @{};
}

static BOOL LuminaEnabled(void) {
    id value = LuminaPrefs[@"enabled"];
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return YES;
}

// Legacy numeric opacity still wins when present; otherwise opacityChoice.
static double LuminaOpacity(void) {
    id value = LuminaPrefs[@"opacity"];
    if ([value isKindOfClass:[NSNumber class]]) {
        double opacity = [value doubleValue];
        if (opacity < 0.5) opacity = 0.5;
        if (opacity > 0.97) opacity = 0.97;
        return opacity;
    }

    NSInteger choice = 3; // default: 90%
    id pick = LuminaPrefs[@"opacityChoice"];
    if ([pick isKindOfClass:[NSNumber class]]) choice = [pick integerValue];

    switch (choice) {
        case 0: return 0.50;
        case 1: return 0.65;
        case 2: return 0.80;
        case 3: default: return 0.90;
    }
}

static BOOL LuminaShowDate(void) {
    id value = LuminaPrefs[@"showDate"];
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return YES;
}

#pragma mark - AOD view

static void LuminaUpdateFace(void);

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
        LuminaUpdateFace();
    });
}

@end

static UIView *aodView = nil;
static UILabel *aodClock = nil;
static UILabel *aodDate = nil;
static NSTimer *aodTimer = nil;

static void LuminaAttachIfNeeded(UIViewController *self) {
    @try {
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGFloat H = [UIScreen mainScreen].bounds.size.height;

        if (aodView == nil) {
            aodView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
            aodView.backgroundColor = [UIColor blackColor];
            aodView.alpha = 0.0;
            aodView.userInteractionEnabled = NO;

            aodClock = [[UILabel alloc] initWithFrame:CGRectMake(0, H * 0.30, W, 90)];
            aodClock.textColor = [UIColor whiteColor];
            aodClock.font = [UIFont systemFontOfSize:62.0 weight:UIFontWeightUltraLight];
            aodClock.textAlignment = NSTextAlignmentCenter;
            aodClock.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
            [aodView addSubview:aodClock];

            aodDate = [[UILabel alloc] initWithFrame:CGRectMake(0, H * 0.30 + 96.0, W, 24)];
            aodDate.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            aodDate.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
            aodDate.textAlignment = NSTextAlignmentCenter;
            aodDate.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
            [aodView addSubview:aodDate];

            aodView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        } else {
            // Re-attach fix: the previous view/container may have died with the last lock screen.
            [aodView removeFromSuperview];
        }

        [self.view addSubview:aodView];
    } @catch (NSException *e) {
        NSLog(@"[Tweak Error] Lumina attach: %@", e);
    }
}

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
    [UIView animateWithDuration:duration animations:^{
        aodView.alpha = alpha;
        aodDate.alpha = LuminaShowDate() ? 1.0 : 0.0;
    }];
}

#pragma mark - Hooks

static void (*orig_viewWillAppear)(UIViewController *self, SEL _cmd, BOOL animated);
static void (*orig_viewWillDisappear)(UIViewController *self, SEL _cmd, BOOL animated);

static void hook_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewWillAppear) orig_viewWillAppear(self, _cmd, animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.isViewLoaded) return;
            if (!LuminaEnabled()) return;
            LuminaAttachIfNeeded(self);
            LuminaUpdateFace();

            if (!aodTimer) {
                aodTimer = [NSTimer timerWithTimeInterval:1.0
                                                  target:[LuminaTimerStub sharedStub]
                                                selector:@selector(theTick)
                                                userInfo:nil
                                                 repeats:YES];
                [[NSRunLoop mainRunLoop] addTimer:aodTimer forMode:NSRunLoopCommonModes];
            }            LuminaFade(LuminaOpacity(), 0.5);
        } @catch (NSException *e) {
            NSLog(@"[Tweak Error] Lumina appear: %@", e);
        }
    });
}

static void hook_viewWillDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewWillDisappear) orig_viewWillDisappear(self, _cmd, animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (aodView) {
                LuminaFade(0.0, 0.2);
            }
            [aodTimer invalidate];
            aodTimer = nil;
        } @catch (NSException *e) {}
    });
}

#pragma mark - Prefs reload

static void LuminaDarwinCallback(CFNotificationCenterRef center, void *observer,
                                 CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            LuminaReloadPrefs();
            if (!LuminaEnabled()) {
                if (aodView) [aodView removeFromSuperview];
                return;
            }
            if (aodView && aodView.superview && aodView.alpha > 0.0) {
                LuminaUpdateFace();
                LuminaFade(LuminaOpacity(), 0.3);
            }
        } @catch (NSException *e) {}
    });
}

__attribute__((constructor)) static void initLumina() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Lumina 1.2.0 loaded");
        LuminaReloadPrefs();

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
                orig_viewWillAppear = (void (*)(UIViewController *, SEL, BOOL))method_getImplementation(m1);
                method_setImplementation(m1, (IMP)hook_viewWillAppear);
                NSLog(@"[CocxaceTweak] Lumina appear hook installed");
            }
            Method m2 = class_getInstanceMethod(cls, sel_registerName("viewWillDisappear:"));
            if (m2) {
                orig_viewWillDisappear = (void (*)(UIViewController *, SEL, BOOL))method_getImplementation(m2);
                method_setImplementation(m2, (IMP)hook_viewWillDisappear);
            }
        } else {
            NSLog(@"[Tweak Error] Lumina: SBLockScreenViewControllerBase not found");
        }
    }
}
