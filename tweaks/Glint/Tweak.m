#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AudioToolbox/AudioToolbox.h>

@interface GlintRootVC : UIViewController
@end
@implementation GlintRootVC
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
@end

@interface GlintIsland : NSObject
+ (instancetype)shared;
- (void)setupAfterLaunch;
- (void)expandDemo;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *pillView;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation GlintIsland

+ (instancetype)shared {
    static GlintIsland *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[GlintIsland alloc] init];
    });
    return s;
}

- (void)setupAfterLaunch {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.window) return;
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            self.window = [[UIWindow alloc] initWithFrame:CGRectMake((screenWidth - 120)/2, 6, 120, 28)];
            self.window.windowLevel = UIWindowLevelStatusBar - 1.0;
            self.window.backgroundColor = [UIColor clearColor];
            self.window.userInteractionEnabled = NO;

            GlintRootVC *vc = [[GlintRootVC alloc] init];
            self.window.rootViewController = vc;

            self.pillView = [[UIView alloc] initWithFrame:vc.view.bounds];
            self.pillView.backgroundColor = [UIColor blackColor];
            self.pillView.layer.cornerRadius = 14.0;
            self.pillView.clipsToBounds = YES;
            self.pillView.layer.borderWidth = 0.5;
            self.pillView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;

            self.titleLabel = [[UILabel alloc] initWithFrame:self.pillView.bounds];
            self.titleLabel.textColor = [UIColor whiteColor];
            self.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
            self.titleLabel.text = @"Glint";
            self.titleLabel.textAlignment = NSTextAlignmentCenter;
            [self.pillView addSubview:self.titleLabel];

            [vc.view addSubview:self.pillView];
            self.window.hidden = NO;
        } @catch (NSException *e) {}
    });
}

- (void)expandDemo {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.window) return;
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            AudioServicesPlaySystemSound(1519);
            [UIView animateWithDuration:0.35 delay:0.0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.window.frame = CGRectMake((screenWidth - 220)/2, 6, 220, 36);
                self.window.rootViewController.view.frame = self.window.bounds;
                self.pillView.frame = self.window.bounds;
                self.pillView.layer.cornerRadius = 18.0;
                self.titleLabel.frame = self.pillView.bounds;
                self.titleLabel.text = @"Glint Island ⚡";
            } completion:^(BOOL finished) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.3 animations:^{
                        self.window.frame = CGRectMake((screenWidth - 120)/2, 6, 120, 28);
                        self.window.rootViewController.view.frame = self.window.bounds;
                        self.pillView.frame = self.window.bounds;
                        self.pillView.layer.cornerRadius = 14.0;
                        self.titleLabel.frame = self.pillView.bounds;
                        self.titleLabel.text = @"Glint";
                    }];
                });
            }];
        } @catch (NSException *e) {}
    });
}

@end

static void (*orig_appDidFinishLaunching)(id self, SEL _cmd, id app);
static void hook_appDidFinishLaunching(id self, SEL _cmd, id app) {
    if (orig_appDidFinishLaunching) {
        orig_appDidFinishLaunching(self, _cmd, app);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[GlintIsland shared] setupAfterLaunch];
    });
}

__attribute__((constructor)) static void initGlint() {
    @autoreleasepool {
        Class sb = objc_getClass("SpringBoard");
        if (sb) {
            Method m = class_getInstanceMethod(sb, sel_registerName("applicationDidFinishLaunching:"));
            if (m) {
                orig_appDidFinishLaunching = (void (*)(id, SEL, id))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_appDidFinishLaunching);
            }
        }
    }
}
