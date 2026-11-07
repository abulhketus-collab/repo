#import "GlintIslandView.h"
#import <AudioToolbox/AudioToolbox.h>

@interface GlintIslandView ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *pillView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *msgLabel;
@property (nonatomic, assign) BOOL isExpanded;
@end

@implementation GlintIslandView

+ (instancetype)sharedInstance {
    static GlintIslandView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GlintIslandView alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupIsland];
    }
    return self;
}

- (void)setupIsland {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake((screenWidth - 120)/2, 6, 120, 30)];
    self.window.windowLevel = UIWindowLevelStatusBar + 200.0;
    self.window.backgroundColor = [UIColor clearColor];

    self.pillView = [[UIView alloc] initWithFrame:self.window.bounds];
    self.pillView.backgroundColor = [UIColor blackColor];
    self.pillView.layer.cornerRadius = 15.0;
    self.pillView.clipsToBounds = YES;
    self.pillView.layer.borderWidth = 0.5;
    self.pillView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, 100, 18)];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.titleLabel.text = @"Glint";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.pillView addSubview:self.titleLabel];

    self.msgLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 24, 220, 16)];
    self.msgLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.msgLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    self.msgLabel.alpha = 0.0;
    [self.pillView addSubview:self.msgLabel];

    [self.window addSubview:self.pillView];
    self.window.hidden = NO;
}

- (void)expandWithTitle:(NSString *)title message:(NSString *)msg {
    if (self.isExpanded) return;
    self.isExpanded = YES;
    AudioServicesPlaySystemSound(1519);

    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGRect expandedFrame = CGRectMake((screenWidth - 250)/2, 6, 250, 48);

    self.titleLabel.text = title;
    self.msgLabel.text = msg;
    self.titleLabel.textAlignment = NSTextAlignmentLeft;

    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.window.frame = expandedFrame;
        self.pillView.frame = self.window.bounds;
        self.pillView.layer.cornerRadius = 24.0;
        self.titleLabel.frame = CGRectMake(16, 8, 218, 16);
        self.msgLabel.frame = CGRectMake(16, 26, 218, 16);
        self.msgLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self collapseIsland];
        });
    }];
}

- (void)collapseIsland {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGRect collapsedFrame = CGRectMake((screenWidth - 120)/2, 6, 120, 30);

    [UIView animateWithDuration:0.35
                          delay:0.0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.msgLabel.alpha = 0.0;
        self.window.frame = collapsedFrame;
        self.pillView.frame = self.window.bounds;
        self.pillView.layer.cornerRadius = 15.0;
        self.titleLabel.frame = CGRectMake(12, 6, 100, 18);
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.text = @"Glint";
    } completion:^(BOOL finished) {
        self.isExpanded = NO;
    }];
}

@end
