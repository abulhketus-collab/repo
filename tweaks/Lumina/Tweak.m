#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static UIView *aodOverlay = nil;
static UILabel *aodClockLabel = nil;
static NSTimer *aodTimer = nil;

static void updateAODClock() {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm"];
    aodClockLabel.text = [formatter stringFromDate:[NSDate date]];
}

static void custom_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (!aodOverlay) {
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

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.duration = 2.0;
    pulse.fromValue = @(0.7);
    pulse.toValue = @(1.0);
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [aodClockLabel.layer addAnimation:pulse forKey:@"pulse"];
}

static void custom_viewWillDisappear(UIViewController *self, SEL _cmd, BOOL animated) {
    [UIView animateWithDuration:0.2 animations:^{
        aodOverlay.alpha = 0.0;
    }];
    [aodTimer invalidate];
    aodTimer = nil;
}

__attribute__((constructor)) static void initLumina() {
    @autoreleasepool {
        Class cls = objc_getClass("SBLockScreenViewControllerBase");
        if (cls) {
            Method mApp = class_getInstanceMethod(cls, sel_registerName("viewWillAppear:"));
            if (mApp) method_setImplementation(mApp, (IMP)custom_viewWillAppear);
            Method mDis = class_getInstanceMethod(cls, sel_registerName("viewWillDisappear:"));
            if (mDis) method_setImplementation(mDis, (IMP)custom_viewWillDisappear);
        }
    }
}
