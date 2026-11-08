// Aura — Action Button HUD for iOS 12 (com.cocxace.aura)
// Long-press of the side/power button opens a glass panel with 4 actions.
// v1.1.0: dynamic screen layout, app launching via SBUIController, preferences.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - Local interfaces (runtime-guarded)

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID suspended:(BOOL)suspended;
@end

#pragma mark - Preferences

static BOOL AuraEnabled(void) {
    @try {
        NSDictionary *prefs =
            [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.aura.plist"];
        if (!prefs) return YES;
        return (prefs[@"enabled"] != nil) ? [prefs[@"enabled"] boolValue] : YES;
    } @catch (NSException *e) {
        return YES;
    }
}

// Haptics toggle from the Settings pane (default: on).
static BOOL AuraHaptics(void) {
    @try {
        NSDictionary *prefs =
            [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.cocxace.aura.plist"];
        if (!prefs) return YES;
        return (prefs[@"haptics"] != nil) ? [prefs[@"haptics"] boolValue] : YES;
    } @catch (NSException *e) {
        return YES;
    }
}

static void AuraTapBuzz(void) {
    if (AuraHaptics()) AudioServicesPlaySystemSound(1519);
}

#pragma mark - Actions

typedef NS_ENUM(NSUInteger, AuraAction) {
    AuraActionTorch = 100,
    AuraActionCamera = 101,
    AuraActionVoiceMemos = 102,
    AuraActionScreenshot = 103,
};

static void AuraTorchToggle(void) {
    @try {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!device || !device.hasTorch || !device.torchAvailable) return;
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            device.torchMode = (device.torchMode == AVCaptureTorchModeOn)
                                   ? AVCaptureTorchModeOff
                                   : AVCaptureTorchModeOn;
            [device unlockForConfiguration];
        }
    } @catch (NSException *e) {
        NSLog(@"[Aura] torch error: %@", e);
    }
}

static void AuraScreenshot(void) {
    extern void notify_post(const char *);
    notify_post("com.apple.springboard.takeScreenshot");
}

static void AuraLaunchApp(NSString *bundleID, NSString *fallbackURL) {
    @try {
        Class cls = NSClassFromString(@"SBUIController");
        if (cls) {
            id ui = [cls performSelector:@selector(sharedInstance)];
            if (ui && [ui respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)]) {
                [ui launchApplicationWithIdentifier:bundleID suspended:NO];
                return;
            }
        }
        // Fallback (SpringBoard passes openURL on to the system anyway).
        NSURL *url = [NSURL URLWithString:fallbackURL];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } @catch (NSException *e) {
        NSLog(@"[Aura] launch error: %@", e);
    }
}

#pragma mark - Panel VC

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

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPanel)];
    [self.view addGestureRecognizer:tap];

    // Dynamic screen bounds (no legacy hardcoded 320x568).
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGFloat H = [UIScreen mainScreen].bounds.size.height;
    CGFloat size = MIN(MIN(W, H) - 60.0, 200.0);

    self.panel = [[UIView alloc] initWithFrame:CGRectMake((W - size) / 2.0, (H - size) / 2.0, size, size)];
    self.panel.layer.cornerRadius = 20.0;
    self.panel.clipsToBounds = YES;
    self.panel.layer.borderWidth = 1.0;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.frame = self.panel.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.blurView];

    NSArray *icons = @[ @[ @"🔦", @(AuraActionTorch) ],
                        @[ @"📷", @(AuraActionCamera) ],
                        @[ @"🎙️", @(AuraActionVoiceMemos) ],
                        @[ @"📸", @(AuraActionScreenshot) ] ];

    CGFloat cell = (size - 40.0) / 2.0;
    CGFloat gap  = 10.0;
    for (int i = 0; i < 4; i++) {
        int r = i / 2;
        int c = i % 2;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(20.0 + c * (cell + gap), 20.0 + r * (cell + gap), cell, cell);
        btn.layer.cornerRadius = 16.0;
        btn.clipsToBounds = YES;
        btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        btn.titleLabel.font = [UIFont systemFontOfSize:27.0];
        [btn setTitle:icons[i][0] forState:UIControlStateNormal];
        btn.tag = [icons[i][1] unsignedIntegerValue];
        [btn addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:btn];
    }
    [self.view addSubview:self.panel];
}

- (void)dismissPanel {
    [UIView animateWithDuration:0.2 animations:^{
        self.panel.transform = CGAffineTransformMakeScale(0.8, 0.8);
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.view.window.hidden = YES;
    }];
}

- (void)actionTapped:(UIButton *)btn {
    AuraTapBuzz();
    @try {
        switch (btn.tag) {
            case AuraActionTorch:       AuraTorchToggle();    break;
            case AuraActionCamera:      AuraLaunchApp(@"com.apple.camera", @"camera:");           break;
            case AuraActionVoiceMemos:  AuraLaunchApp(@"com.apple.VoiceMemos", @"voicememos:");   break;
            case AuraActionScreenshot:  AuraScreenshot();     break;
            default: break;
        }
    } @catch (NSException *e) {
        NSLog(@"[Aura] action error: %@", e);
    }
    [self dismissPanel];
}

@end

#pragma mark - Manager

@interface AuraManager : NSObject
+ (instancetype)shared;
- (void)toggleHUD;
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AuraManager

+ (instancetype)shared {
    static AuraManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[AuraManager alloc] init];
    });
    return sharedManager;
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
                AuraTapBuzz();
                AuraVC *vc = (AuraVC *)self.window.rootViewController;
                vc.panel.transform = CGAffineTransformMakeScale(0.7, 0.7);
                vc.view.alpha = 0.0;
                self.window.hidden = NO;
                [self.window makeKeyAndVisible];
                [UIView animateWithDuration:0.35
                                      delay:0.0
                     usingSpringWithDamping:0.7
                      initialSpringVelocity:0.8
                                    options:UIViewAnimationOptionCurveEaseInOut
                                 animations:^{
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

#pragma mark - Hook

static void (*orig_longPress)(id self, SEL _cmd, id btn);
static void hook_longPress(id self, SEL _cmd, id btn) {
    if (AuraEnabled()) {
        [[AuraManager shared] toggleHUD];
        return;
    }
    if (orig_longPress) orig_longPress(self, _cmd, btn);
}

__attribute__((constructor)) static void initAura() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Aura 1.1.0 loaded");
        Class sb = objc_getClass("SpringBoard");
        if (sb) {
            Method m = class_getInstanceMethod(sb, sel_registerName("_hardwareButtonLongPressed:"));
            if (m) {
                orig_longPress = (void (*)(id, SEL, id))method_getImplementation(m);
                method_setImplementation(m, (IMP)hook_longPress);
                NSLog(@"[CocxaceTweak] Aura long-press hook installed");
            }
        }
    }
}
