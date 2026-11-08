#import "GlintIslandView.h"
#import <AudioToolbox/AudioToolbox.h>

// SBUIController — classic iOS 12 API for launching apps from SpringBoard.
@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID suspended:(BOOL)suspended;
@end

static CGFloat GlintScreenWidth() {
    return [UIScreen mainScreen].bounds.size.width;
}

// Truncates long strings by composed characters (emoji-safe) with an ellipsis.
static NSString *GlintClean(NSString *raw, NSInteger maxGraphemes) {
    if (!raw) return nil;
    NSString *s = [raw stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    s = [s stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    while ([s hasPrefix:@" "]) { s = [s substringFromIndex:1]; }
    if (s.length == 0) return nil;
    if ((NSInteger)s.length <= maxGraphemes) return s;

    NSMutableString *out = [NSMutableString string];
    __block NSInteger count = 0;
    NSRange whole = NSMakeRange(0, s.length);
    [s enumerateSubstringsInRange:whole
                          options:NSStringEnumerationByComposedCharacterSequences
                       usingBlock:^(NSString *sub, NSRange subRange, NSRange enclosing, BOOL *stop) {
        if (!sub) { *stop = YES; return; }
        if (count >= maxGraphemes) { *stop = YES; return; }
        [out appendString:sub];
        count++;
    }];
    [out appendString:@"…"];
    return out;
}

@interface GlintIsland ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIView *iconBadge;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *iconGlyphLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *musicLabel;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL nowPlayingFlag;
@property (nonatomic, assign) NSInteger eventGen;
@property (nonatomic, copy) NSString *tapBundleID;
@end

#pragma mark - Touch router

// Only the pill itself should catch touches; everything else passes to SpringBoard.
@interface GlintTouchPassView : UIView
@property (nonatomic, weak) GlintIsland *island;
@end

@implementation GlintTouchPassView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.island || !self.island.pill) return NO;
    CGRect hit = CGRectInset(self.island.pill.frame, -8.0, -8.0);
    return CGRectContainsPoint(hit, point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return [self pointInside:point withEvent:event] ? [super hitTest:point withEvent:event] : nil;
}

@end

@implementation GlintIsland

+ (instancetype)shared {
    static GlintIsland *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GlintIsland alloc] init];
    });
    return instance;
}

- (BOOL)isSetup {
    return self.window != nil;
}

- (BOOL)isNowPlayingActive {
    return self.nowPlayingFlag;
}

#pragma mark - Setup

- (void)setup {
    if (self.window) return;
    @try {
        CGFloat W = GlintScreenWidth();

        self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, W, 64)];
        self.window.windowLevel = UIWindowLevelStatusBar + 200.0;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.userInteractionEnabled = YES;

        UIViewController *host = [[UIViewController alloc] init];
        self.window.rootViewController = host;
        GlintTouchPassView *touchView = [[GlintTouchPassView alloc] initWithFrame:CGRectMake(0, 0, W, 64)];
        touchView.island = self;
        touchView.backgroundColor = [UIColor clearColor];
        touchView.userInteractionEnabled = YES;
        host.view = touchView;

        // Collapsed pill: 112x26, top center. Like the real island — pure black.
        self.pill = [[UIView alloc] initWithFrame:CGRectMake((W - 112.0) / 2.0, 6.0, 112.0, 26.0)];
        self.pill.backgroundColor = [UIColor blackColor];
        self.pill.layer.cornerRadius = 13.0;
        self.pill.clipsToBounds = YES;
        self.pill.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        self.pill.layer.borderWidth = 0.5;
        [touchView addSubview:self.pill];

        // App icon badge (only visible while expanded)
        self.iconBadge = [[UIView alloc] initWithFrame:CGRectMake(8.0, 6.0, 32.0, 32.0)];
        self.iconBadge.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1.0];
        self.iconBadge.layer.cornerRadius = 10.0;
        self.iconBadge.clipsToBounds = YES;
        self.iconBadge.alpha = 0.0;
        [self.pill addSubview:self.iconBadge];

        self.iconImageView = [[UIImageView alloc] initWithFrame:self.iconBadge.bounds];
        self.iconImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.iconImageView.clipsToBounds = YES;
        [self.iconBadge addSubview:self.iconImageView];

        self.iconGlyphLabel = [[UILabel alloc] initWithFrame:self.iconBadge.bounds];
        self.iconGlyphLabel.font = [UIFont systemFontOfSize:15.0];
        self.iconGlyphLabel.textColor = [UIColor whiteColor];
        self.iconGlyphLabel.textAlignment = NSTextAlignmentCenter;
        self.iconGlyphLabel.backgroundColor = [UIColor clearColor];
        [self.iconBadge addSubview:self.iconGlyphLabel];

        // Texts (only visible while expanded)
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.0, 6.0, 110.0, 15.0)];
        self.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.textAlignment = NSTextAlignmentLeft;
        self.titleLabel.userInteractionEnabled = NO;
        self.titleLabel.alpha = 0.0;
        [self.pill addSubview:self.titleLabel];

        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.0, 23.0, 110.0, 14.0)];
        self.messageLabel.font = [UIFont systemFontOfSize:11.5];
        self.messageLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        self.messageLabel.textAlignment = NSTextAlignmentLeft;
        self.messageLabel.userInteractionEnabled = NO;
        self.messageLabel.alpha = 0.0;
        [self.pill addSubview:self.messageLabel];

        // Music note in collapsed pill
        self.musicLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 112.0, 26.0)];
        self.musicLabel.font = [UIFont systemFontOfSize:13.0];
        self.musicLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
        self.musicLabel.textAlignment = NSTextAlignmentCenter;
        self.musicLabel.text = @"♪";
        self.musicLabel.userInteractionEnabled = NO;
        self.musicLabel.alpha = 0.0;
        [self.pill addSubview:self.musicLabel];

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pillTapped)];
        [self.pill addGestureRecognizer:tap];

        // Reveal on the very first frame (fade in from a scale so it doesn't "pop").
        self.pill.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.pill.alpha = 0.0;
        self.window.hidden = NO;
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.pill.transform = CGAffineTransformIdentity;
            self.pill.alpha = 1.0;
        } completion:nil];
    } @catch (NSException *e) {
        NSLog(@"[Glint] setup error: %@", e);
    }
}

#pragma mark - Layout & animation

- (void)applyLayoutAnimated:(BOOL)animated {
    if (!self.window || !self.pill) return;

    CGFloat W = GlintScreenWidth();
    self.window.frame = CGRectMake(0, 0, W, 64);

    BOOL exp = self.expanded;
    CGFloat pillW = exp ? MIN(W - 28.0, 240.0) : 112.0;
    CGFloat pillH = exp ? 44.0 : 26.0;
    CGFloat pillY = exp ? 4.0 : 6.0;

    self.iconBadge.frame = CGRectMake(8.0, 6.0, 32.0, 32.0);
    self.titleLabel.frame = CGRectMake(exp ? 50.0 : 0.0,
                                       exp ? 6.0 : 0.0,
                                       exp ? (pillW - 60.0) : 112.0,
                                       exp ? 15.0 : 26.0);
    self.messageLabel.frame = CGRectMake(50.0, 23.0, pillW - 62.0, 14.0);
    self.musicLabel.frame = CGRectMake(0.0, 0.0, 112.0, 26.0);

    self.iconBadge.alpha = exp ? 1.0 : 0.0;
    self.titleLabel.alpha = exp ? 1.0 : 0.0;
    self.messageLabel.alpha = exp ? 1.0 : 0.0;
    self.musicLabel.alpha = exp ? 0.0 : (self.nowPlayingFlag ? 1.0 : 0.0);

    void (^block)(void) = ^{
        self.pill.frame = CGRectMake((W - pillW) / 2.0, pillY, pillW, pillH);
        self.pill.layer.cornerRadius = pillH / 2.0;
    };

    self.pill.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

    if (animated) {
        [UIView animateWithDuration:0.45
                              delay:0.0
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.45
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:block
                         completion:nil];
    } else {
        block();
    }
}

#pragma mark - Events

- (void)presentEventWithGlyph:(NSString *)glyph
                         icon:(UIImage *)icon
                        title:(NSString *)title
                      message:(NSString *)message
                      tapOpen:(NSString *)bundleID
                        delay:(double)collapseDelay {
    if (!self.window) [self setup];
    if (!self.window) return;

    BOOL wasIdle = !self.expanded;

    // Empty title & body guarded: keep the pill honest.
    if (!title.length && !message.length) {
        title = @"Glint";
    } else if (!title.length) {
        title = message;
        message = nil;
    }

    self.expanded = YES;
    self.eventGen++;
    NSInteger gen = self.eventGen;
    self.tapBundleID = ([bundleID length] > 0) ? bundleID : nil;

    NSString *cleanTitle = GlintClean(title, 30);
    NSString *cleanBody = GlintClean(message, 48);

    self.messageLabel.hidden = (cleanBody.length == 0);

    self.titleLabel.text = cleanTitle;
    self.messageLabel.text = cleanBody;

    if (icon && [icon isKindOfClass:[UIImage class]]) {
        self.iconImageView.image = icon;
        self.iconImageView.alpha = 1.0;
        self.iconGlyphLabel.text = @"";
    } else {
        self.iconImageView.image = nil;
        self.iconImageView.alpha = 0.0;
        self.iconGlyphLabel.text = glyph ?: @"📱";
    }

    if (wasIdle) {
        AudioServicesPlaySystemSound(1519);
    }

    [self applyLayoutAnimated:YES];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(collapseDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.eventGen != gen) return;
        [strongSelf collapse];
    });
}

- (void)collapse {
    self.expanded = NO;
    self.eventGen++;
    self.tapBundleID = nil;
    self.messageLabel.hidden = NO;
    [self applyLayoutAnimated:YES];
}

- (void)showEventForApp:(NSString *)appName
                 bundle:(NSString *)bundleID
                  glyph:(NSString *)glyph
                   icon:(UIImage *)icon
                  title:(NSString *)title
                message:(NSString *)message {
    [self presentEventWithGlyph:(glyph.length > 0 ? glyph : @"📱")
                           icon:icon
                          title:title
                        message:message
                        tapOpen:bundleID
                          delay:4.0];
}

- (void)showChargingAtLevel:(NSInteger)levelPercent {
    if (levelPercent < 0 || levelPercent > 100) levelPercent = 99;
    NSString *title = [NSString stringWithFormat:@"⚡ Charging %ld%%", (long)levelPercent];
    [self presentEventWithGlyph:@"⚡"
                           icon:nil
                          title:title
                        message:nil
                        tapOpen:nil
                          delay:3.0];
}

- (void)showTorchOn:(BOOL)on {
    [self presentEventWithGlyph:on ? @"🔦" : @"🔦"
                           icon:nil
                          title:on ? @"Flashlight On" : @"Flashlight Off"
                        message:nil
                        tapOpen:nil
                          delay:2.5];
}

- (void)showNowPlayingTrack:(NSString *)track artist:(NSString *)artist {
    self.nowPlayingFlag = YES;
    NSString *body = artist.length ? [@"♪ " stringByAppendingString:artist] : nil;
    [self presentEventWithGlyph:@"🎧"
                           icon:nil
                          title:(track.length ? track : @"Now Playing")
                        message:body
                        tapOpen:nil
                          delay:3.0];
}

- (void)showBootGreeting {
    [self presentEventWithGlyph:@"🏝"
                           icon:nil
                          title:@"Glint"
                        message:@"Dynamic Island online"
                        tapOpen:nil
                          delay:3.5];
}

- (void)setNowPlayingActive:(BOOL)active {
    self.nowPlayingFlag = active;
    if (!self.expanded) {
        [self applyLayoutAnimated:YES];
    }
}

- (void)playIdleTapPulse {
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.1
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        weakSelf.pill.transform = CGAffineTransformMakeScale(1.08, 1.18);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.6
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            weakSelf.pill.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Tap

- (void)pillTapped {
    @try {
        self.eventGen++; // cancels any pending auto-collapse timers
        NSString *bid = self.tapBundleID;
        self.tapBundleID = nil;

        if (bid.length > 0) {
            [self collapse];
            // Small delay so the collapse animation starts before the launch takes over.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self openAppWithIdentifier:bid];
            });
        } else {
            [self playIdleTapPulse];
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] tap error: %@", e);
    }
}

- (void)openAppWithIdentifier:(NSString *)bundleID {
    @try {
        Class cls = NSClassFromString(@"SBUIController");
        if (!cls) return;
        id ui = [cls performSelector:@selector(sharedInstance)];
        if (!ui) return;
        SEL sel = @selector(launchApplicationWithIdentifier:suspended:);
        if ([ui respondsToSelector:sel]) {
            [ui launchApplicationWithIdentifier:bundleID suspended:NO];
        } else {
            SEL sel2 = @selector(launchApplicationWithIdentifier:);
            if ([ui respondsToSelector:sel2]) {
                [ui performSelector:sel2 withObject:bundleID];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] launch error: %@", e);
    }
}

@end
