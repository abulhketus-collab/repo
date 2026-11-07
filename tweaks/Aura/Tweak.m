#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface AuraVC : UIViewController
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@end

@implementation AuraVC
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPanel)];
    [self.view addGestureRecognizer:tap];

    // Fitted for 320x568 iPhone 5s display: 200x200 box centered
    self.panel = [[UIView alloc] initWithFrame:CGRectMake((320 - 200)/2, (568 - 200)/2, 200, 200)];
    self.panel.layer.cornerRadius = 20.0;
    self.panel.clipsToBounds = YES;
    self.panel.layer.borderWidth = 1.0;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.frame = self.panel.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.blurView];

    NSArray *icons = @[@"🔦", @"📷", @"🎙️", @"📸"];
    for (int i = 0; i < 4; i++) {
        int r = i / 2;
        int c = i % 2;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(20 + c * 85, 20 + r * 85, 75, 75);
        btn.layer.cornerRadius = 16.0;
        btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        btn.titleLabel.font = [UIFont systemFontOfSize:30];
        [btn setTitle:icons[i] forState:UIControlStateNormal];
        btn.tag = 100 + i;
        [btn addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:btn];
    }
    [self.view addSubview:self.panel];
}

- (void)dismissPanel {
    AudioServicesPlaySystemSound(1519);
    [UIView animateWithDuration:0.2 animations:^{
        self.panel.transform = CGAffineTransformMakeScale(0.8, 0.8);
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.view.window.hidden = YES;
    }];
}

- (void)actionTapped:(UIButton *)btn {
    AudioServicesPlaySystemSound(1519);
    switch (btn.tag) {
        case 100: {
            AVCaptureDevice *dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            if ([dev hasTorch]) {
                [dev lockForConfiguration:nil];
                dev.torchMode = (dev.torchMode == AVCaptureTorchModeOn) ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
                [dev unlockForConfiguration];
            }
            break;
        }
        case 101: [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"camera:"] options:@{} completionHandler:nil]; break;
        case 102: [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"voicememos:"] options:@{} completionHandler:nil]; break;
        case 103: {
            extern void notify_post(const char *);
            notify_post("com.apple.springboard.takeScreenshot");
            break;
        }
    }
    [self dismissPanel];
}
@end

@interface AuraManager : NSObject
+ (instancetype)shared;
- (void)toggleHUD;
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AuraManager
+ (instancetype)shared {
    static AuraManager *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s = [[AuraManager alloc] init]; });
    return s;
}

- (void)toggleHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.window) {
                self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                self.window.windowLevel = UIWindowLevelAlert + 50.0;
                self.window.backgroundColor = [UIColor clearColor];
                self.window.rootViewController = [[AuraVC alloc] init];
            }
            if (!self.window.hidden) {
                [((AuraVC *)self.window.rootViewController) dismissPanel];
            } else {
                AudioServicesPlaySystemSound(1519);
                AuraVC *vc = (AuraVC *)self.window.rootViewController;
                vc.panel.transform = CGAffineTransformMakeScale(0.7, 0.7);
                vc.view.alpha = 0.0;
                self.window.hidden = NO;
                [UIView animateWithDuration:0.35 delay:0.0 usingSpringWithDamping:0.7 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    vc.panel.transform = CGAffineTransformIdentity;
                    vc.view.alpha = 1.0;
                } completion:nil];
            }
        } @catch (NSException *e) {
            NSLog(@"[Tweak Error] Aura toggleHUD: %@", e);
        }
    });
}
@end

static void (*orig_longPress)(id self, SEL _cmd, id btn);
static void hook_longPress(id self, SEL _cmd, id btn) {
    @try {
        [[AuraManager shared] toggleHUD];
        return;
    } @catch (NSException *e) {
        NSLog(@"[Tweak Error] Aura hook: %@", e);
    }
    if (orig_longPress) orig_longPress(self, _cmd, btn);
}

__attribute__((constructor)) static void initAura() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Aura Loaded successfully");
        Class sb = objc_getClass("SpringBoard");
        if (sb) {
            Method m = class_getInstanceMethod(sb, sel_registerName("_hardwareButtonLongPressed:"));
            if (m) {
                orig_longPress = (void (*)(id, SEL, id))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_longPress);
            }
        }
    }
}
