#import "GlintIslandView.h"
#import <AudioToolbox/AudioToolbox.h>

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID suspended:(BOOL)suspended;
- (void)launchApplicationWithIdentifier:(NSString *)bundleID;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

static NSInteger GlintPreset = 1;

static CGFloat GlintScreenWidth() {
    return [UIScreen mainScreen].bounds.size.width;
}

static void GlintPillMetrics(CGFloat *w, CGFloat *h, CGFloat *expW, CGFloat *expH, CGFloat *y) {
    CGFloat W = GlintScreenWidth();
    switch (GlintPreset) {
        case 0: if (w) *w = 92.0;  if (h) *h = 24.0;  if (y) *y = 8.0;  break;
        case 2: if (w) *w = 140.0; if (h) *h = 30.0;  if (y) *y = 6.0;  break;
        default: if (w) *w = 118.0; if (h) *h = 27.0; if (y) *y = 7.0; break;
    }
    if (expW) *expW = MIN(W - 28.0, 248.0);
    if (expH) *expH = 44.0;
}

static NSString *GlintClean(NSString *raw, NSInteger maxGraphemes) {
    if (!raw) return nil;
    NSString *s = [raw stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    s = [s stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    while ([s hasPrefix:@" "]) { s = [s substringFromIndex:1]; }
    if (s.length == 0) return nil;
    if ((NSInteger)s.length <= maxGraphemes) return s;
    NSMutableString *out = [NSMutableString string];
    __block NSInteger count = 0;
    [s enumerateSubstringsInRange:NSMakeRange(0, s.length)
                          options:NSStringEnumerationByComposedCharacterSequences
                       usingBlock:^(NSString *sub, NSRange subRange, NSRange enclosing, BOOL *stop) {
        if (!sub || count >= maxGraphemes) { *stop = YES; return; }
        [out appendString:sub];
        count++;
    }];
    [out appendString:@"…"];
    return out;
}

// Returns a system SF Symbol image (iOS 13+, guarded)
static UIImage *GlintSymbolImage(NSString *symbolName, CGFloat size, UIColor *color) {
    if (!symbolName) return nil;
    UIImage *img = [UIImage imageNamed:symbolName];
    return img;
}

// Returns a colored circle badge image (for flashlight lamp etc.)
static UIImage *GlintBadgeCircle(CGFloat diameter, UIColor *fillColor, UIColor *borderColor) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, diameter, diameter);
    if (borderColor) {
        CGContextSetStrokeColorWithColor(ctx, borderColor.CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddEllipseInRect(ctx, rect);
        CGContextDrawPath(ctx, kCGPathStroke);
    }
    if (fillColor) {
        CGContextSetFillColorWithColor(ctx, fillColor.CGColor);
        CGContextAddEllipseInRect(ctx, rect);
        CGContextFillPath(ctx);
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@interface GlintWaveView : UIView
@property (nonatomic, strong) NSArray<UIView *> *bars;
- (void)startAnimating;
- (void)stopAnimating;
@end

@implementation GlintWaveView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        NSMutableArray<UIView *> *bs = [NSMutableArray array];
        CGFloat x = 0.0;
        for (NSInteger i = 0; i < 3; i++) {
            CGFloat bw = 3.0, bh = 7.0 + i * 2.0;
            UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(x, (frame.size.height - bh) / 2.0, bw, bh)];
            bar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.95];
            bar.layer.cornerRadius = bw / 2.0;
            [self addSubview:bar];
            [bs addObject:bar];
            x += bw + 3.0;
        }
        self.bars = bs;
    }
    return self;
}

- (void)startAnimating {
    for (NSUInteger i = 0; i < self.bars.count; i++) {
        UIView *bar = self.bars[i];
        [bar.layer removeAllAnimations];
        bar.transform = CGAffineTransformIdentity;
        CGFloat dur = 0.30 + 0.09 * i;
        [UIView animateWithDuration:dur
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut |
                                    UIViewAnimationOptionRepeat |
                                    UIViewAnimationOptionAutoreverse |
                                    UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            bar.transform = CGAffineTransformMakeScale(1.0, 1.9);
            bar.alpha = 0.55;
        } completion:nil];
    }
}

- (void)stopAnimating {
    for (UIView *bar in self.bars) {
        [bar.layer removeAllAnimations];
        bar.transform = CGAffineTransformIdentity;
        bar.alpha = 1.0;
    }
}

@end

@interface GlintIsland ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIView *iconBadge;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *iconGlyphLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) GlintWaveView *wave;
@property (nonatomic, strong) UILabel *leftGlyphLabel;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL nowPlayingFlag;
@property (nonatomic, assign) NSInteger eventGen;
@property (nonatomic, copy) NSString *tapBundleID;
@property (nonatomic, copy) NSString *lastTitle;
@property (nonatomic, copy) NSString *lastBody;
@property (nonatomic, copy) NSString *lastGlyph;
@property (nonatomic, copy) NSString *lastBundleID;
@property (nonatomic, strong) UIImage *lastIcon;
@property (nonatomic, copy) NSString *lastAppName;
@property (nonatomic, assign) BOOL lastWasMusic;
@property (nonatomic, copy) NSString *lastTrack;
@property (nonatomic, copy) NSString *lastArtist;
@end

#pragma mark - Touch pass-through

@interface GlintTouchPassView : UIView
@property (nonatomic, weak) GlintIsland *island;
@end

@implementation GlintTouchPassView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.island || !self.island.pill) return NO;
    CGRect hit = CGRectInset(self.island.pill.frame, -12.0, -12.0);
    return CGRectContainsPoint(hit, point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return [self pointInside:point withEvent:event] ? [super hitTest:point withEvent:event] : nil;
}

@end

@implementation GlintIsland

+ (instancetype)shared {
    static GlintIsland *inst = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [[GlintIsland alloc] init]; });
    return inst;
}

- (BOOL)isSetup { return self.window != nil; }
- (BOOL)isNowPlayingActive { return self.nowPlayingFlag; }

#pragma mark - Setup

- (void)setup {
    if (self.window) return;
    @try {
        CGFloat W = GlintScreenWidth();
        CGFloat pw = 118.0, ph = 27.0, py = 7.0;
        GlintPillMetrics(&pw, &ph, NULL, NULL, &py);

        self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, W, 70)];
        self.window.windowLevel = UIWindowLevelNormal + 1500.0;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.userInteractionEnabled = YES;

        UIViewController *host = [[UIViewController alloc] init];
        self.window.rootViewController = host;
        GlintTouchPassView *touchView = [[GlintTouchPassView alloc] initWithFrame:CGRectMake(0, 0, W, 70)];
        touchView.island = self;
        touchView.backgroundColor = [UIColor clearColor];
        touchView.userInteractionEnabled = YES;
        host.view = touchView;

        self.pill = [[UIView alloc] initWithFrame:CGRectMake((W - pw) / 2.0, py, pw, ph)];
        self.pill.backgroundColor = [UIColor blackColor];
        self.pill.layer.cornerRadius = ph / 2.0;
        self.pill.clipsToBounds = YES;
        self.pill.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
        self.pill.layer.borderWidth = 0.5;
        self.pill.userInteractionEnabled = YES;
        [touchView addSubview:self.pill];

        self.iconBadge = [[UIView alloc] initWithFrame:CGRectMake(7.0, 4.0, 30.0, 30.0)];
        self.iconBadge.backgroundColor = [UIColor colorWithWhite:0.20 alpha:1.0];
        self.iconBadge.layer.cornerRadius = 9.0;
        self.iconBadge.clipsToBounds = YES;
        self.iconBadge.alpha = 0.0;
        [self.pill addSubview:self.iconBadge];

        self.iconImageView = [[UIImageView alloc] initWithFrame:self.iconBadge.bounds];
        self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconImageView.clipsToBounds = YES;
        [self.iconBadge addSubview:self.iconImageView];

        self.iconGlyphLabel = [[UILabel alloc] initWithFrame:self.iconBadge.bounds];
        self.iconGlyphLabel.font = [UIFont systemFontOfSize:14.0];
        self.iconGlyphLabel.textColor = [UIColor whiteColor];
        self.iconGlyphLabel.textAlignment = NSTextAlignmentCenter;
        self.iconGlyphLabel.backgroundColor = [UIColor clearColor];
        [self.iconBadge addSubview:self.iconGlyphLabel];

        CGFloat dummyY, expW, expH;
        GlintPillMetrics(NULL, NULL, &expW, &expH, &dummyY);

        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(46.0, 8.0, expW - 56.0, 16.0)];
        self.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.textAlignment = NSTextAlignmentLeft;
        self.titleLabel.userInteractionEnabled = NO;
        self.titleLabel.alpha = 0.0;
        [self.pill addSubview:self.titleLabel];

        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(46.0, 25.0, expW - 56.0, 14.0)];
        self.messageLabel.font = [UIFont systemFontOfSize:11.5];
        self.messageLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
        self.messageLabel.textAlignment = NSTextAlignmentLeft;
        self.messageLabel.userInteractionEnabled = NO;
        self.messageLabel.alpha = 0.0;
        [self.pill addSubview:self.messageLabel];

        self.leftGlyphLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0, 0.0, pw / 2.0 - 10.0, ph)];
        self.leftGlyphLabel.font = [UIFont systemFontOfSize:12.0];
        self.leftGlyphLabel.textColor = [UIColor whiteColor];
        self.leftGlyphLabel.textAlignment = NSTextAlignmentLeft;
        self.leftGlyphLabel.userInteractionEnabled = NO;
        self.leftGlyphLabel.alpha = 0.0;
        [self.pill addSubview:self.leftGlyphLabel];

        self.wave = [[GlintWaveView alloc] initWithFrame:CGRectMake(pw - 26.0, 0.0, 18.0, ph)];
        self.wave.userInteractionEnabled = NO;
        self.wave.alpha = 0.0;
        [self.pill addSubview:self.wave];

        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pillLongPressed:)];
        lp.minimumPressDuration = 0.32;
        [self.pill addGestureRecognizer:lp];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pillTapped)];
        [self.pill addGestureRecognizer:tap];

        self.pill.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.pill.alpha = 0.0;
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];
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

- (void)applySizePreset:(NSInteger)preset {
    GlintPreset = preset;
    if (self.window) [self applyLayoutAnimated:YES];
}

- (void)setIslandHidden:(BOOL)hidden {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.window) {
                [UIView animateWithDuration:0.25 animations:^{
                    self.pill.alpha = hidden ? 0.0 : 1.0;
                } completion:^(BOOL finished) {
                    if (!self.expanded) self.window.hidden = hidden;
                    else { self.window.hidden = NO; self.pill.alpha = 1.0; }
                }];
            }
        } @catch (NSException *e) {}
    });
}

- (void)waveSetActive:(BOOL)active {
    self.wave.alpha = (self.expanded || !active) ? 0.0 : 1.0;
    if (active) [self.wave startAnimating];
    else [self.wave stopAnimating];
}

#pragma mark - Layout

- (void)applyLayoutAnimated:(BOOL)animated {
    if (!self.window || !self.pill) return;

    CGFloat W = GlintScreenWidth();
    self.window.frame = CGRectMake(0, 0, W, 70);

    BOOL exp = self.expanded;
    CGFloat pw = 118.0, ph = 27.0, py = 7.0, expW = 248.0, expH = 44.0;
    GlintPillMetrics(&pw, &ph, &expW, &expH, &py);

    CGFloat pillW = exp ? expW : pw;
    CGFloat pillH = exp ? pillH = expH : ph;
    CGFloat pillY = exp ? 4.0 : py;

    self.iconBadge.frame = CGRectMake(7.0, (pillH - 30.0) / 2.0, 30.0, 30.0);
    self.titleLabel.frame = CGRectMake(46.0, 8.0, expW - 56.0, 16.0);
    self.messageLabel.frame = CGRectMake(46.0, 25.0, expW - 56.0, 14.0);
    self.leftGlyphLabel.frame = CGRectMake(10.0, 0.0, pw / 2.0 - 10.0, ph);
    self.wave.frame = CGRectMake(pw - 26.0, 0.0, 18.0, ph);

    self.iconBadge.alpha = exp ? 1.0 : 0.0;
    self.titleLabel.alpha = exp ? 1.0 : 0.0;
    self.messageLabel.alpha = exp ? 1.0 : 0.0;
    [self waveSetActive:self.nowPlayingFlag];

    self.pill.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;

    void (^block)(void) = ^{
        self.pill.frame = CGRectMake((W - pillW) / 2.0, pillY, pillW, pillH);
        self.pill.layer.cornerRadius = pillH / 2.0;
    };

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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentEventOnMainWithGlyph:glyph icon:icon title:title message:message tapOpen:bundleID delay:collapseDelay];
    });
}

- (void)presentEventOnMainWithGlyph:(NSString *)glyph
                               icon:(UIImage *)icon
                              title:(NSString *)title
                            message:(NSString *)message
                            tapOpen:(NSString *)bundleID
                              delay:(double)collapseDelay {
    if (!self.window) [self setup];
    if (!self.window) return;

    if (!title.length && !message.length) title = @"Glint";
    else if (!title.length) { title = message; message = nil; }

    NSString *cleanTitle = GlintClean(title, 34);
    NSString *cleanBody = GlintClean(message, 52);

    self.expanded = YES;
    self.eventGen++;
    NSInteger gen = self.eventGen;
    self.tapBundleID = ([bundleID length] > 0) ? bundleID : nil;

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
        self.iconGlyphLabel.text = glyph ?: @"";
    }

    self.lastTitle = cleanTitle;
    self.lastBody = cleanBody;
    self.lastGlyph = glyph;
    self.lastBundleID = self.tapBundleID;
    self.lastIcon = icon;
    self.lastWasMusic = NO;

    self.leftGlyphLabel.text = glyph ?: @"";
    self.leftGlyphLabel.alpha = 1.0;

    AudioServicesPlaySystemSound(1519);
    [self applyLayoutAnimated:YES];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(collapseDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) s = weakSelf;
        if (!s || s.eventGen != gen) return;
        [s collapse];
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
    self.lastAppName = [appName copy] ?: @"Application";
    [self presentEventWithGlyph:(glyph.length > 0 ? glyph : @"")
                           icon:icon
                          title:title
                        message:message
                        tapOpen:bundleID
                          delay:4.0];
}

- (void)showChargingAtLevel:(NSInteger)level {
    if (level < 0 || level > 100) level = 99;
    [self presentEventWithGlyph:@""
                           icon:nil
                          title:[NSString stringWithFormat:@"⚡ Charging %ld%%", (long)level]
                        message:nil
                        tapOpen:nil
                          delay:2.6];
}

- (void)setChargingSlotLevel:(NSInteger)level orNil:(BOOL)clear {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (clear && self.leftGlyphLabel.text && [self.leftGlyphLabel.text isEqualToString:@""])
                self.leftGlyphLabel.text = nil;
            if (!clear) {
                // Show lightning bolt in left slot
                self.leftGlyphLabel.text = @"⚡";
                if (!self.expanded) self.leftGlyphLabel.alpha = 1.0;
            }
        } @catch (NSException *e) {}
    });
}

- (void)showTorchOn:(BOOL)on {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (on) {
                // Yellow filled circle badge = flashlight lamp
                UIImage *badgeImg = GlintBadgeCircle(30.0, [UIColor colorWithRed:1.0 green:0.82 blue:0.1 alpha:1.0], [UIColor whiteColor]);
                self.iconImageView.image = badgeImg;
                self.iconImageView.alpha = 1.0;
                self.iconGlyphLabel.text = @"";
                self.iconBadge.alpha = 1.0;
                self.titleLabel.text = @"Flashlight On";
                self.messageLabel.text = @"";
                self.leftGlyphLabel.text = @"🔦";
                self.leftGlyphLabel.alpha = 1.0;
            } else {
                self.iconBadge.alpha = 0.0;
                self.leftGlyphLabel.text = @"";
                self.leftGlyphLabel.alpha = 0.0;
            }
            [self applyLayoutAnimated:YES];
            AudioServicesPlaySystemSound(1519);
        } @catch (NSException *e) { NSLog(@"[Glint] torch error: %@", e); }
    });
}

- (void)showNowPlayingTrack:(NSString *)track artist:(NSString *)artist {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            self.nowPlayingFlag = YES;
            self.lastWasMusic = YES;
            NSString *body = artist.length ? [@"♪ " stringByAppendingString:artist] : nil;
            self.lastTrack = [track copy] ?: @"Now Playing";
            self.lastArtist = [artist copy];
            [self presentEventWithGlyph:@""
                                   icon:nil
                                  title:(track.length ? track : @"Now Playing")
                                message:body
                                tapOpen:nil
                                  delay:3.0];
            self.lastTitle = track.length ? track : @"Now Playing";
            self.lastBody = body;
        } @catch (NSException *e) { NSLog(@"[Glint] now playing error: %@", e); }
    });
}

- (void)showBootGreeting {
    [self presentEventWithGlyph:@""
                           icon:nil
                          title:@"Glint 1.2.1"
                        message:@"Dynamic Island online"
                        tapOpen:nil
                          delay:3.2];
}

- (void)setNowPlayingActive:(BOOL)active {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.nowPlayingFlag = active;
        if (!self.expanded) [self applyLayoutAnimated:YES];
    });
}

- (void)playIdleTapPulse {
    __weak typeof(self) ws = self;
    [UIView animateWithDuration:0.1
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        ws.pill.transform = CGAffineTransformMakeScale(1.08, 1.16);
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.6
              initialSpringVelocity:0.4
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            ws.pill.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - Long-press expand

- (void)expandDetails:(BOOL)isMusic {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.expanded) return;
            NSString *title, *body, *glyph, *tapBid;
            UIImage *icon;
            if (isMusic) {
                title = self.lastTrack ?: @"Now Playing";
                body = self.lastArtist.length ? [@"♪ " stringByAppendingString:self.lastArtist] : nil;
                glyph = @"";
                tapBid = @"com.apple.mobilemusic";
                icon = nil;
            } else {
                title = self.lastTitle ?: @"Glint";
                body = self.lastBody;
                glyph = self.lastGlyph ?: @"";
                tapBid = self.lastBundleID;
                icon = self.lastIcon;
            }
            if (!title.length) return;

            self.eventGen++;
            NSInteger gen = self.eventGen;
            self.expanded = YES;
            self.tapBundleID = tapBid;
            self.messageLabel.hidden = (body.length == 0);
            self.titleLabel.text = GlintClean(title, 34);
            self.messageLabel.text = GlintClean(body, 52);
            if (icon && [icon isKindOfClass:[UIImage class]]) {
                self.iconImageView.image = icon;
                self.iconImageView.alpha = 1.0;
                self.iconGlyphLabel.text = @"";
            } else {
                self.iconImageView.image = nil;
                self.iconImageView.alpha = 0.0;
                self.iconGlyphLabel.text = glyph;
            }
            AudioServicesPlaySystemSound(1109);
            [self applyLayoutAnimated:YES];

            __weak typeof(self) ws = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                __strong typeof(self) s = ws;
                if (!s || s.eventGen != gen) return;
                [s collapse];
            });
        } @catch (NSException *e) { NSLog(@"[Glint] expand error: %@", e); }
    });
}

#pragma mark - Tap

- (void)pillTapped {
    @try {
        self.eventGen++;
        NSString *bid = self.tapBundleID;
        self.tapBundleID = nil;
        BOOL wasExpanded = self.expanded;

        if (bid.length > 0) {
            [self collapse];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self openAppWithIdentifier:bid];
            });
        } else if (self.nowPlayingFlag && !wasExpanded) {
            [self collapse];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self openAppWithIdentifier:@"com.apple.mobilemusic"];
            });
        } else {
            [self playIdleTapPulse];
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] tap error: %@", e);
    }
}

- (void)pillLongPressed:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    @try {
        if (self.nowPlayingFlag && !self.lastTitle.length) {
            [self expandDetails:YES];
        } else if (self.lastTitle.length > 0) {
            [self expandDetails:self.lastWasMusic];
        } else if (self.nowPlayingFlag) {
            [self expandDetails:YES];
        } else {
            [self playIdleTapPulse];
        }
    } @catch (NSException *e) { NSLog(@"[Glint] long press error: %@", e); }
}

- (void)openAppWithIdentifier:(NSString *)bundleID {
    @try {
        Class cls = NSClassFromString(@"SBUIController");
        if (cls) {
            id ui = [cls performSelector:@selector(sharedInstance)];
            if (ui) {
                SEL sel = @selector(launchApplicationWithIdentifier:suspended:);
                if ([ui respondsToSelector:sel]) {
                    [ui launchApplicationWithIdentifier:bundleID suspended:NO];
                    return;
                }
                SEL sel2 = @selector(launchApplicationWithIdentifier:);
                if ([ui respondsToSelector:sel2]) {
                    [ui performSelector:sel2 withObject:bundleID];
                    return;
                }
            }
        }
        Class ws = NSClassFromString(@"LSApplicationWorkspace");
        if (ws) {
            id w = [ws performSelector:@selector(defaultWorkspace)];
            if (w && [w respondsToSelector:@selector(openApplicationWithBundleID:)]) {
                [w openApplicationWithBundleID:bundleID];
                return;
            }
        }
        if ([bundleID isEqualToString:@"com.apple.camera"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"camera:"]];
        } else if ([bundleID isEqualToString:@"com.apple.mobilemusic"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"music:"]];
        } else if ([bundleID isEqualToString:@"com.apple.VoiceMemos"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"voicememos:"]];
        } else if ([bundleID isEqualToString:@"com.apple.mobilesms"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"sms:"]];
        } else if ([bundleID isEqualToString:@"com.apple.mobilephone"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tel:"]];
        } else if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://"]];
        }
    } @catch (NSException *e) {
        NSLog(@"[Glint] launch error: %@", e);
    }
}

@end
