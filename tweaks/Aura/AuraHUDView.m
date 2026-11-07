#import "AuraHUDView.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface AuraHUDView ()
@property (nonatomic, strong) UIWindow *hudWindow;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UISlider *brightnessSlider;
@property (nonatomic, strong) UISlider *volumeSlider;
@end

@implementation AuraHUDView

+ (instancetype)sharedInstance {
    static AuraHUDView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AuraHUDView alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.hudWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.hudWindow.windowLevel = UIWindowLevelStatusBar + 150.0;
    self.hudWindow.backgroundColor = [UIColor clearColor];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissHUD)];
    [self.hudWindow addGestureRecognizer:dismissTap];

    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 280)];
    self.containerView.center = self.hudWindow.center;
    self.containerView.layer.cornerRadius = 24.0;
    self.containerView.clipsToBounds = YES;
    self.containerView.layer.borderWidth = 1.0;
    self.containerView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = self.containerView.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:self.blurView];

    NSArray *actions = @[@"🔦", @"📷", @"🎙️", @"📸"];
    for (int i = 0; i < 4; i++) {
        int row = i / 2;
        int col = i % 2;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(24 + col * 90, 24 + row * 85, 70, 70);
        btn.layer.cornerRadius = 18.0;
        btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        btn.titleLabel.font = [UIFont systemFontOfSize:28];
        [btn setTitle:actions[i] forState:UIControlStateNormal];
        btn.tag = i + 100;
        [btn addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:btn];
    }

    self.brightnessSlider = [[UISlider alloc] initWithFrame:CGRectMake(24, 200, 172, 24)];
    self.brightnessSlider.minimumValue = 0.0;
    self.brightnessSlider.maximumValue = 1.0;
    self.brightnessSlider.value = [UIScreen mainScreen].brightness;
    self.brightnessSlider.minimumTrackTintColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0];
    [self.brightnessSlider addTarget:self action:@selector(brightnessChanged:) forControlEvents:UIControlEventValueChanged];
    [self.containerView addSubview:self.brightnessSlider];

    self.volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(24, 235, 172, 24)];
    self.volumeSlider.minimumValue = 0.0;
    self.volumeSlider.maximumValue = 1.0;
    self.volumeSlider.value = 0.5;
    self.volumeSlider.minimumTrackTintColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [self.containerView addSubview:self.volumeSlider];

    [self.hudWindow addSubview:self.containerView];
}

- (void)presentHUD {
    AudioServicesPlaySystemSound(1519);
    self.brightnessSlider.value = [UIScreen mainScreen].brightness;
    self.containerView.transform = CGAffineTransformMakeScale(0.7, 0.7);
    self.containerView.alpha = 0.0;
    self.hudWindow.hidden = NO;

    [UIView animateWithDuration:0.35
                          delay:0.0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.8
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.containerView.transform = CGAffineTransformIdentity;
        self.containerView.alpha = 1.0;
    } completion:nil];
}

- (void)dismissHUD {
    [UIView animateWithDuration:0.2 animations:^{
        self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        self.containerView.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.hudWindow.hidden = YES;
    }];
}

- (void)actionTapped:(UIButton *)btn {
    AudioServicesPlaySystemSound(1519);
    switch (btn.tag) {
        case 100: [self toggleTorch]; break;
        case 101: [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"camera:"] options:@{} completionHandler:nil]; break;
        case 102: [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"voicememos:"] options:@{} completionHandler:nil]; break;
        case 103: {
            extern void notify_post(const char *);
            notify_post("com.apple.springboard.takeScreenshot");
            break;
        }
    }
    [self dismissHUD];
}

- (void)brightnessChanged:(UISlider *)sender {
    [[UIScreen mainScreen] setBrightness:sender.value];
}

- (void)toggleTorch {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        [device lockForConfiguration:nil];
        device.torchMode = (device.torchMode == AVCaptureTorchModeOn) ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
        [device unlockForConfiguration];
    }
}

@end
