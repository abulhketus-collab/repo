#import "GlintWindow.h"
#import "GlintPrefs.h"
#import "GlintStateManager.h"
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <os/log.h>

#define kGlintPillWidth        120.f
#define kGlintPillHeight        32.f
#define kGlintMinimalSize       16.f
#define kGlintExpandedWidth    360.f

#define kGlintCornerRadiusCollapsed 16.f
#define kGlintCornerRadiusExpanded  24.f

#define kGlintWaveCount 5

static const char *kGlintLog = "GlintWindow";

#define GlintWinLog(...) \
    do { if ([GlintPrefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[GlintWin] %s: " __VA_ARGS__, __PRETTY_FUNCTION__); } while(0)

@interface GlintWindow ()

@property (nonatomic, strong) CAShapeLayer *pillLayer;
@property (nonatomic, strong) UIVisualEffectView *backdropView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) NSArray<CALayer *> *waveLayers;
@property (nonatomic, strong) UIView *minimalDotView;

@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) GlintStateType currentType;
@property (nonatomic, strong) NSTimer *autoCollapseTimer;

@end

@implementation GlintWindow

static GlintWindow *_sharedWindow = nil;

+ (instancetype)sharedWindow {
    if (!_sharedWindow) {
        _sharedWindow = [[self alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [_sharedWindow commonInit];
    }
    return _sharedWindow;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.windowLevel = 2000.f;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.userInteractionEnabled = YES;
    self.isHidden = YES;
    self.rootViewController = [[UIViewController alloc] init];

    _pillLayer = [CAShapeLayer layer];
    _pillLayer.fillColor = [UIColor colorWithWhite:0.12f alpha:0.88f].CGColor;
    _pillLayer.shadowColor = [UIColor blackColor].CGColor;
    _pillLayer.shadowOpacity = 0.5f;
    _pillLayer.shadowRadius = 10.f;
    _pillLayer.shadowOffset = CGSizeMake(0, 4);
    [self.layer addSublayer:_pillLayer];

    [self buildContent];
    [self addGestures];
    [self updatePosition];
    self.isHidden = YES;
}

- (void)buildContent {
    _backdropView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    _backdropView.layer.masksToBounds = YES;
    [self addSubview:_backdropView];

    _iconView = [[UIImageView alloc] init];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.layer.masksToBounds = YES;
    [self addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont boldSystemFontOfSize:16];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.numberOfLines = 1;
    _titleLabel.minimumScaleFactor = 0.75f;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    [self addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.font = [UIFont systemFontOfSize:13];
    _subtitleLabel.textColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
    _subtitleLabel.backgroundColor = [UIColor clearColor];
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.minimumScaleFactor = 0.7f;
    _subtitleLabel.adjustsFontSizeToFitWidth = YES;
    [self addSubview:_subtitleLabel];

    _minimalDotView = [[UIView alloc] init];
    _minimalDotView.layer.cornerRadius = kGlintMinimalSize / 2.f;
    _minimalDotView.layer.masksToBounds = YES;
    _minimalDotView.backgroundColor = [UIColor systemBlueColor];
    _minimalDotView.alpha = 0;
    [self addSubview:_minimalDotView];

    // --- Р­РєРІР°Р»Р°Р№Р·РµСЂ (now-playing РІРѕР»РЅС‹) ---
    NSMutableArray<CALayer *> *waves = [NSMutableArray array];
    CGFloat totalW = 0.f;
    for (NSInteger i = 0; i < kGlintWaveCount; i++) {
        CALayer *wave = [CALayer layer];
        CGFloat bw = 3.f;
        CGFloat bh = 4.f + (arc4random_uniform(6)) * 2.f; // 4..14
        wave.frame = CGRectMake(totalW, 0, bw, bh);
        wave.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9f].CGColor;
        wave.cornerRadius = bw / 2.f;
        wave.hidden = YES;
        [self.layer addSublayer:wave];
        [waves addObject:wave];
        totalW += bw + 3.f;
    }
    _waveLayers = [waves copy];
}

- (void)addGestures {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.numberOfTapsRequired = 1;
    [self addGestureRecognizer:tap];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [tap requireGestureRecognizerToFail:doubleTap];
    [self addGestureRecognizer:doubleTap];

    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self addGestureRecognizer:swipeUp];
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self addGestureRecognizer:swipeDown];
}

- (void)updatePosition {
    CGSize screen = [[UIScreen mainScreen] bounds].size;
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    CGFloat topInset = statusBarFrame.size.height > 0 ? statusBarFrame.size.height : 20.f;
    CGFloat cx = screen.width / 2.f;
    CGFloat cy = topInset + 12.f + kGlintPillHeight / 2.f;
    self.center = CGPointMake(cx, cy);
}

- (CGRect)collapsedFrame {
    return CGRectMake(0, 0, kGlintPillWidth, kGlintPillHeight);
}
- (CGRect)expandedFrame {
    return CGRectMake(0, 0, kGlintExpandedWidth, [GlintPrefs floatForKey:@"glintExpandedHeight" defaultValue:140.f]);
}

- (void)showState:(nullable GlintState *)state animated:(BOOL)animated {
    @autoreleasepool {
        if (![GlintPrefs boolForKey:@"enableGlint" defaultValue:YES]) {
            self.isHidden = YES;
            return;
        }

        // Р—Р°С‰РёС‚Р° РѕС‚ РїРѕРєР°Р·Р° РїРѕРІРµСЂС… РІС…РѕРґСЏС‰РµРіРѕ Р·РІРѕРЅРєР°
        Class lsmCls = NSClassFromString(@"SBLockScreenManager");
        if (lsmCls) {
            id lsm = [lsmCls performSelector:@selector(sharedInstance)];
            if (lsm && [lsm respondsToSelector:@selector(isUILocked)] && [lsm isUILocked]) {
                self.isHidden = YES;
                return;
            }
        }

        GlintStateType type = state ? state.type : GlintStateNone;

        // Р’СЃРµРіРґР° РѕР±РЅРѕРІР»СЏРµРј UI, РґР°Р¶Рµ РµСЃР»Рё С‚РёРї С‚РѕС‚ Р¶Рµ вЂ” РєРѕРЅС‚РµРЅС‚ РјРѕР¶РµС‚ Р±С‹С‚СЊ РґСЂСѓРіРёРј (РЅРѕРІРѕРµ СѓРІРµРґРѕРјР»РµРЅРёРµ)
        self.currentType = type;
        self.isHidden = NO;
        [self populateWithState:state];
        [self animateToType:type animated:animated];
        [self scheduleAutoCollapse];
        GlintWinLog(@"show state %ld animated=%d", (long)type, animated);
    }
}

- (void)populateWithState:(nullable GlintState *)state {
    if (!state) {
        _iconView.image = nil;
        _titleLabel.text = nil;
        _subtitleLabel.text = nil;
        _minimalDotView.hidden = YES;
        [self setWavesVisible:NO];
        return;
    }

    _iconView.image = state.icon;
    _titleLabel.text = state.title;
    _subtitleLabel.text = state.subtitle;

    BOOL isMusic = (state.type == GlintStateMusic);
    [self setWavesVisible:isMusic];

    if ([GlintPrefs stringForKey:@"glintPosition" defaultValue:@"top"] isEqualToString:@"minimal"]) {
        _minimalDotView.hidden = NO;
        _minimalDotView.backgroundColor = (state.type == GlintStateTorch) ? [UIColor yellowColor] :
                                            (state.type == GlintStateCharging) ? [UIColor orangeColor] :
                                            (state.type == GlintStateMusic) ? [UIColor redColor] :
                                            [UIColor blueColor];
    } else {
        _minimalDotView.hidden = YES;
    }

    // Р Р°СЃРїРѕР»РѕР¶РёС‚СЊ РІРѕР»РЅС‹ СЃРїСЂР°РІР° РІ СЂР°СЃС€РёСЂРµРЅРЅРѕРј СЃРѕСЃС‚РѕСЏРЅРёРё
    if (isMusic && state.type == GlintStateMusic) {
        CGRect exp = [self expandedFrame];
        CGFloat startX = exp.size.width - 40.f;
        CGFloat step = 6.f;
        for (NSInteger i = 0; i < _waveLayers.count; i++) {
            CALayer *wave = _waveLayers[i];
            wave.frame = CGRectMake(startX + i * step, (exp.size.height - wave.frame.size.height) / 2.f, wave.frame.size.width, wave.frame.size.height);
            if (!wave.animationForKey:@"waveScale") {
                CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.scale.y"];
                anim.fromValue = @(0.5f);
                anim.toValue = @(1.8f);
                anim.duration = 0.35f + (0.1f * (arc4random_uniform(100) / 100.0f));
                anim.autoreverse = YES;
                anim.repeatCount = HUGE_VALF;
                anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                [wave addAnimation:anim forKey:@"waveScale"];
            }
        }
    }
}

- (void)setWavesVisible:(BOOL)visible {
    for (CALayer *layer in _waveLayers) {
        if (visible) {
            layer.hidden = NO;
        } else {
            layer.hidden = YES;
            [layer removeAnimationForKey:@"waveScale"];
        }
    }
}

- (void)animateToType:(GlintStateType)type animated:(BOOL)animated {
    CGRect targetRect = [self expandedFrame];
    CGFloat targetRadius = kGlintCornerRadiusExpanded;

    if (!animated) {
        _pillLayer.frame = targetRect;
        _pillLayer.cornerRadius = targetRadius;
        _pillLayer.path = [UIBezierPath bezierPathWithRoundedRect:targetRect cornerRadius:targetRadius].CGPath;
        [self layoutContentForRect:targetRect];
        self.alpha = (type == GlintStateNone) ? 0.f : 1.f;
        return;
    }

    CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:@"bounds"];
    spring.mass = 1.f;
    spring.stiffness = [GlintPrefs floatForKey:@"glintSpringStiffness" defaultValue:180.f];
    spring.damping = [GlintPrefs floatForKey:@"glintSpringDamping" defaultValue:18.f];
    spring.initialVelocity = 0.f;
    spring.fromValue = [NSValue valueWithCGRect:_pillLayer.bounds];
    spring.toValue = [NSValue valueWithCGRect:targetRect];
    spring.duration = spring.settlingDuration;
    spring.fillMode = kCAFillModeForwards;
    spring.removedOnCompletion = NO;

    CABasicAnimation *radius = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
    radius.fromValue = @(_pillLayer.cornerRadius);
    radius.toValue = @(targetRadius);
    radius.duration = spring.duration;
    radius.fillMode = kCAFillModeForwards;
    radius.removedOnCompletion = NO;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[spring, radius];
    group.duration = spring.duration;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;

    [_pillLayer addAnimation:group forKey:@"glintPillSpring"];
    CATransaction.begin();
    CATransaction.setAnimationDuration(spring.duration);
    _pillLayer.frame = targetRect;
    _pillLayer.cornerRadius = targetRadius;
    _pillLayer.path = [UIBezierPath bezierPathWithRoundedRect:targetRect cornerRadius:targetRadius].CGPath;
    [self layoutContentForRect:targetRect];
    self.alpha = 1.f;
    CATransaction.commit();
}

- (void)layoutContentForRect:(CGRect)rect {
    _backdropView.frame = rect;
    _pillLayer.frame = rect;
    _pillLayer.cornerRadius = rect.size.height / 2.f;
    _pillLayer.path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:rect.size.height / 2.f].CGPath;

    CGFloat padding = 12.f;
    _iconView.frame = CGRectMake(padding, (rect.size.height - 40) / 2.f, 40, 40);
    _iconView.layer.cornerRadius = 8.f;

    CGFloat labelX = padding + 40 + 10;
    CGFloat labelW = rect.size.width - labelX - padding;
    _titleLabel.frame = CGRectMake(labelX, padding + 2, labelW, 20);
    _subtitleLabel.frame = CGRectMake(labelX, rect.size.height - padding - 18, labelW, 18);

    _minimalDotView.frame = CGRectMake((rect.size.width - kGlintMinimalSize) / 2.f,
                                       (rect.size.height - kGlintMinimalSize) / 2.f,
                                       kGlintMinimalSize, kGlintMinimalSize);
}

- (void)scheduleAutoCollapse {
    [self autoCollapseTimerInvalidate];
    CGFloat delay = [GlintPrefs floatForKey:@"glintAutoCollapseDelay" defaultValue:4.f];
    if (delay <= 0) return;
    _autoCollapseTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                          target:self
                                                        selector:@selector(autoCollapseFire)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)autoCollapseTimerInvalidate {
    if (_autoCollapseTimer) {
        [_autoCollapseTimer invalidate];
        _autoCollapseTimer = nil;
    }
}

- (void)autoCollapseFire {
    [self collapseAnimated:YES];
}

- (void)collapseAnimated:(BOOL)animated {
    self.currentType = GlintStateNone;
    [self animateToType:GlintStateNone animated:animated];
    [self scheduleAutoCollapse];
}

- (void)destroy {
    GlintWinLog(@"destroy");
    [self autoCollapseTimerInvalidate];
    [self setWavesVisible:NO];
    _waveLayers = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    for (UIGestureRecognizer *g in self.gestureRecognizers) [self removeGestureRecognizer:g];

    _pillLayer = nil;
    _backdropView = nil;
    _iconView = nil;
    _titleLabel = nil;
    _subtitleLabel = nil;
    _minimalDotView = nil;

    self.rootViewController = nil;
    self.isHidden = YES;

    _sharedWindow = nil;
    GlintWinLog(@"window destroyed");
}

- (void)handleTap:(UITapGestureRecognizer *)g {
    GlintState *top = [[GlintStateManager sharedManager] topState];
    if (!top || top.type == GlintStateNone) return;
    if ([GlintPrefs boolForKey:@"glintHapticOnTap" defaultValue:YES]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
    [self collapseAnimated:YES];
    if (top.bundleID && top.bundleID.length) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[GlintStateManager sharedManager] openBundleID:top.bundleID];
        });
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)g {
    GlintState *top = [[GlintStateManager sharedManager] topState];
    if (top && top.bundleID && top.bundleID.length) {
        [[GlintStateManager sharedManager] openBundleID:top.bundleID];
    }
    [self collapseAnimated:YES];
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)g {
    [self collapseAnimated:YES];
}

@end
