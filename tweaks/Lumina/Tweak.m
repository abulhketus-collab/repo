// Lumina — Always-On-Display styled lock screen for iOS 12 (com.cocxace.lumina)
// v1.1.0: dynamic screen layout, stale overlay re-attach fix, date line, prefs.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Preferences

static NSDictionary *LuminaPrefs(void) {
    static NSDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.lumina.plist"] ?: @{};
    });
    return cache;
}

static BOOL LuminaEnabled(void) {
    id value = LuminaPrefs()[@"enabled"];
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return YES;
}

static double LuminaOpacity(void) {
    id value = LuminaPrefs()[@"opacity"];
    double opacity = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0.88;
    if (opacity < 0.5) opacity = 0.5;
    if (opacity > 0.97) opacity = 0.97;
    return opacity;
}

static BOOL LuminaShowDate(void) {
    id value = LuminaPrefs()[@"showDate"];
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return YES;
}

static void LuminaUpdateFace(void); // forward decl (timer stub calls it)

#pragma mark - AOD view

static UIView *aodView = nil;
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
        LuminaUpdateFace();
    });
}

@end

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
            }
            LuminaFade(LuminaOpacity(), 0.5);
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

__attribute__((constructor)) static void initLumina() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Lumina 1.1.0 loaded");
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
