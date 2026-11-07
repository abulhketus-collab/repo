#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static void (*orig_viewWillAppear)(UIViewController *self, SEL _cmd, BOOL animated);
static void (*orig_viewWillDisappear)(UIViewController *self, SEL _cmd, BOOL animated);

static UIView *aodOverlay = nil;
static UILabel *aodClockLabel = nil;
static NSTimer *aodTimer = nil;

static void updateAODClock() {
    @try {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm"];
        aodClockLabel.text = [formatter stringFromDate:[NSDate date]];
    } @catch (NSException *e) {}
}

static void custom_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewWillAppear) {
        orig_viewWillAppear(self, _cmd, animated);
    }
    @try {
        if (!aodOverlay && self.isViewLoaded) {
            aodOverlay = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
            aodOverlay.backgroundColor = [UIColor blackColor];
            aodOverlay.alpha = 0.0;
            aodOverlay.userInteractionEnabled = NO;

            aodClockLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height * 0.3, [UIScreen mainScreen].bounds.size.width, 80)];
            aodClockLabel.textColor = [UIColor whiteColor];
            aodClockLabel.font = [UIFont systemFontOfSize:64 weight:UIFontWeightUltraLight];
            aodClockLabel.textAlignment = NSTextAlignmentCenter;
            [aodOverlay addSubview:aodClockLabel];

            [self.view addSubview:aodOverlay];
        }

        updateAODClock();
        if (!aodTimer) {
            aodTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                updateAODClock();
            }];
        }

        [UIView animateWithDuration:0.5 animations:^{
            aodOverlay.alpha = 0.88;
        }];
    } @catch (NSException *e) {}
}

static void custom_viewWillDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewWillDisappear) {
        orig_viewWillDisappear(self, _cmd, animated);
    }
    @try {
        if (aodOverlay) {
            [UIView animateWithDuration:0.2 animations:^{
                aodOverlay.alpha = 0.0;
            }];
        }
        [aodTimer invalidate];
        aodTimer = nil;
    } @catch (NSException *e) {}
}

__attribute__((constructor)) static void initLumina() {
    @autoreleasepool {
        Class cls = objc_getClass("SBLockScreenViewControllerBase");
        if (cls) {
            Method mApp = class_getInstanceMethod(cls, sel_registerName("viewWillAppear:"));
            if (mApp) {
                orig_viewWillAppear = (void (*)(UIViewController *, SEL, BOOL))method_getImplementation(mApp);
                method_setImplementation(mApp, (IMP)custom_viewWillAppear);
            }
            Method mDis = class_getInstanceMethod(cls, sel_registerName("viewWillDisappear:"));
            if (mDis) {
                orig_viewWillDisappear = (void (*)(UIViewController *, SEL, BOOL))method_getImplementation(mDis);
                method_setImplementation(mDis, (IMP)custom_viewWillDisappear);
            }
        }
    }
}
