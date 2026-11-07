#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static void (*orig_viewWillAppear)(UIViewController *self, SEL _cmd, BOOL animated);
static void (*orig_viewWillDisappear)(UIViewController *self, SEL _cmd, BOOL animated);
static UIView *aodView = nil;
static UILabel *aodLabel = nil;
static NSTimer *aodTimer = nil;

static void updateClock() {
    @try {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"HH:mm"];
        aodLabel.text = [fmt stringFromDate:[NSDate date]];
    } @catch (NSException *e) {}
}

static void hook_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (orig_viewWillAppear) orig_viewWillAppear(self, _cmd, animated);
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!aodView && self.isViewLoaded) {
                // iPhone 5s 320x568 screen bounds
                aodView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 568)];
                aodView.backgroundColor = [UIColor blackColor];
                aodView.alpha = 0.0;
                aodView.userInteractionEnabled = NO;

                aodLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 180, 320, 70)];
                aodLabel.textColor = [UIColor whiteColor];
                aodLabel.font = [UIFont systemFontOfSize:58 weight:UIFontWeightUltraLight];
                aodLabel.textAlignment = NSTextAlignmentCenter;
                [aodView addSubview:aodLabel];

                [self.view addSubview:aodView];
            }
            updateClock();
            if (!aodTimer) {
                aodTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) { updateClock(); }];
            }
            [UIView animateWithDuration:0.5 animations:^{ aodView.alpha = 0.88; }];
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
                [UIView animateWithDuration:0.2 animations:^{ aodView.alpha = 0.0; }];
            }
            [aodTimer invalidate];
            aodTimer = nil;
        } @catch (NSException *e) {}
    });
}

__attribute__((constructor)) static void initLumina() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Lumina Loaded successfully");
        Class cls = objc_getClass("SBLockScreenViewControllerBase");
        if (cls) {
            Method m1 = class_getInstanceMethod(cls, sel_registerName("viewWillAppear:"));
            if (m1) {
                orig_viewWillAppear = (void (*)(UIViewController *, SEL, BOOL))method_getImplementation(m1);
                method_setImplementation(m1, (IMP)hook_viewWillAppear);
            }
            Method m2 = class_getInstanceMethod(cls, sel_registerName("viewWillDisappear:"));
            if (m2) {
                orig_viewWillDisappear = (void (*)(UIViewController *, SEL, BOOL))method_getImplementation(m2);
                method_setImplementation(m2, (IMP)hook_viewWillDisappear);
            }
        }
    }
}
