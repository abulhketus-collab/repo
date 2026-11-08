#import "AB12HUDView.h"

@interface AVSystemController : NSObject
+ (instancetype)sharedAVSystemController;
- (BOOL)getVolume:(float *)volume forCategory:(NSString *)category;
- (BOOL)setVolumeTo:(float)volume forCategory:(NSString *)category;
@end

static UIImage *AB12GetActionIcon(AB12Action action) {
    NSString *name = AB12ActionName(action);
    NSString *bundlePath = [BUNDLE_PATH stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        return [UIImage imageWithContentsOfFile:bundlePath];
    }
    NSString *supportPath = [APP_SUPPORT_PATH stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:supportPath]) {
        return [UIImage imageWithContentsOfFile:supportPath];
    }
    return nil;
}

static UIImage *AB12GetSliderIcon(AB12SliderType type) {
    NSString *name = (type == AB12SliderTypeBrightness) ? @"brightness" : @"volume";
    NSString *bundlePath = [BUNDLE_PATH stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        return [UIImage imageWithContentsOfFile:bundlePath];
    }
    NSString *supportPath = [APP_SUPPORT_PATH stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:supportPath]) {
        return [UIImage imageWithContentsOfFile:supportPath];
    }
    return nil;
}

@implementation AB12HUDCell

- (instancetype)initWithFrame:(CGRect)frame action:(AB12Action)action {
    self = [super initWithFrame:frame];
    if (self) {
        self.action = action;
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        self.layer.cornerRadius = 16.0;
        self.layer.masksToBounds = YES;
        
        _iconImageView = [[UIImageView alloc] initWithFrame:CGRectInset(self.bounds, 12, 12)];
        _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        _iconImageView.userInteractionEnabled = NO;
        [self addSubview:_iconImageView];
        
        [self updateAction:action];
    }
    return self;
}

- (void)updateAction:(AB12Action)action {
    self.action = action;
    self.iconImageView.image = AB12GetActionIcon(action);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.1 animations:^{
        if (highlighted) {
            self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
            self.transform = CGAffineTransformMakeScale(0.92, 0.92);
        } else {
            self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
            self.transform = CGAffineTransformIdentity;
        }
    }];
}

@end

@implementation AB12SliderView {
    UIView *_trackContainer;
}

- (instancetype)initWithFrame:(CGRect)frame type:(AB12SliderType)type {
    self = [super initWithFrame:frame];
    if (self) {
        self.type = type;
        self.userInteractionEnabled = YES;
        
        _trackContainer = [[UIView alloc] initWithFrame:self.bounds];
        _trackContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        _trackContainer.layer.cornerRadius = frame.size.height / 2.0;
        _trackContainer.layer.masksToBounds = YES;
        [self addSubview:_trackContainer];
        
        _fillView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, frame.size.height)];
        _fillView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.35];
        [_trackContainer addSubview:_fillView];
        
        CGFloat iconSize = frame.size.height - 8.0;
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 4, iconSize, iconSize)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.image = AB12GetSliderIcon(type);
        _iconView.userInteractionEnabled = NO;
        [self addSubview:_iconView];
        
        // Initial value reading
        if (type == AB12SliderTypeBrightness) {
            self.value = [UIScreen mainScreen].brightness;
        } else {
            float vol = 0.5f;
            Class avClass = NSClassFromString(@"AVSystemController");
            if (avClass) {
                [[avClass sharedAVSystemController] getVolume:&vol forCategory:@"Audio/Video"];
            }
            self.value = vol;
        }
        [self updateValue:self.value animated:NO];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)updateValue:(CGFloat)val animated:(BOOL)animated {
    val = fmaxf(0.0f, fminf(1.0f, val));
    _value = val;
    CGFloat width = self.bounds.size.width * val;
    
    void (^animBlock)(void) = ^{
        self.fillView.frame = CGRectMake(0, 0, width, self.bounds.size.height);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:animBlock completion:nil];
    } else {
        animBlock();
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self];
    CGFloat val = loc.x / self.bounds.size.width;
    [self updateValue:val animated:NO];
    [self applyValueToSystem:self.value];
    if (self.valueChangedBlock) {
        self.valueChangedBlock(self.value);
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self];
    CGFloat val = loc.x / self.bounds.size.width;
    [self updateValue:val animated:YES];
    [self applyValueToSystem:self.value];
    if (self.valueChangedBlock) {
        self.valueChangedBlock(self.value);
    }
}

- (void)applyValueToSystem:(CGFloat)val {
    if (self.type == AB12SliderTypeBrightness) {
        [UIScreen mainScreen].brightness = val;
    } else {
        Class avClass = NSClassFromString(@"AVSystemController");
        if (avClass) {
            [[avClass sharedAVSystemController] setVolumeTo:(float)val forCategory:@"Audio/Video"];
        }
    }
}

@end

@interface AB12HUDView ()
@property (nonatomic, strong) NSMutableArray<AB12HUDCell *> *cells;
@property (nonatomic, strong) UIView *dividerView;
@property (nonatomic, strong) AB12SliderView *brightnessSlider;
@property (nonatomic, strong) AB12SliderView *volumeSlider;
@end

@implementation AB12HUDView

- (instancetype)initWithActions:(NSArray<NSNumber *> *)actions showSliders:(BOOL)showSliders {
    self.showSliders = showSliders;
    CGFloat width = 176.0;
    CGFloat height = showSliders ? 250.0 : 176.0;
    CGRect frame = CGRectMake(0, 0, width, height);
    
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
        self.layer.cornerRadius = 22.0;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
        self.layer.borderWidth = 0.5;
        
        _cells = [NSMutableArray arrayWithCapacity:4];
        [self buildGridWithActions:actions];
        
        if (showSliders) {
            [self buildSliders];
        }
    }
    return self;
}

- (void)buildGridWithActions:(NSArray<NSNumber *> *)actions {
    CGFloat cellSize = 60.0;
    CGFloat padding = 18.0;
    CGFloat spacing = 20.0;
    
    for (NSInteger i = 0; i < 4; i++) {
        NSInteger row = i / 2;
        NSInteger col = i % 2;
        
        CGFloat x = padding + col * (cellSize + spacing);
        CGFloat y = padding + row * (cellSize + spacing);
        
        AB12Action act = (i < actions.count) ? [actions[i] integerValue] : (AB12Action)i;
        AB12HUDCell *cell = [[AB12HUDCell alloc] initWithFrame:CGRectMake(x, y, cellSize, cellSize) action:act];
        cell.tag = i;
        [cell addTarget:self action:@selector(cellTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:cell];
        [self.cells addObject:cell];
    }
}

- (void)buildSliders {
    CGFloat width = self.bounds.size.width - 36.0;
    CGFloat sliderH = 26.0;
    
    _dividerView = [[UIView alloc] initWithFrame:CGRectMake(18, 166, width, 0.5)];
    _dividerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self addSubview:_dividerView];
    
    _brightnessSlider = [[AB12SliderView alloc] initWithFrame:CGRectMake(18, 178, width, sliderH) type:AB12SliderTypeBrightness];
    [self addSubview:_brightnessSlider];
    
    _volumeSlider = [[AB12SliderView alloc] initWithFrame:CGRectMake(18, 212, width, sliderH) type:AB12SliderTypeVolume];
    [self addSubview:_volumeSlider];
}

- (void)updateActions:(NSArray<NSNumber *> *)actions showSliders:(BOOL)showSliders {
    for (NSInteger i = 0; i < self.cells.count; i++) {
        AB12Action act = (i < actions.count) ? [actions[i] integerValue] : (AB12Action)i;
        [self.cells[i] updateAction:act];
    }
    
    if (showSliders && !self.brightnessSlider) {
        self.showSliders = YES;
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 176.0, 250.0);
        [self buildSliders];
    } else if (!showSliders && self.brightnessSlider) {
        self.showSliders = NO;
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 176.0, 176.0);
        [self.dividerView removeFromSuperview];
        [self.brightnessSlider removeFromSuperview];
        [self.volumeSlider removeFromSuperview];
        self.dividerView = nil;
        self.brightnessSlider = nil;
        self.volumeSlider = nil;
    }
    
    if (self.brightnessSlider) {
        [self.brightnessSlider updateValue:[UIScreen mainScreen].brightness animated:NO];
        float vol = 0.5f;
        Class avClass = NSClassFromString(@"AVSystemController");
        if (avClass) {
            [[avClass sharedAVSystemController] getVolume:&vol forCategory:@"Audio/Video"];
        }
        [self.volumeSlider updateValue:vol animated:NO];
    }
}

- (void)cellTapped:(AB12HUDCell *)sender {
    if ([self.delegate respondsToSelector:@selector(hudDidSelectAction:)]) {
        [self.delegate hudDidSelectAction:sender.action];
    }
}

@end

@implementation AB12ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    [self.view addGestureRecognizer:bgTap];
}

- (void)backgroundTapped:(UITapGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self.view];
    if (self.hudView && !CGRectContainsPoint(self.hudView.frame, loc)) {
        if (self.dismissBlock) {
            self.dismissBlock();
        }
    }
}

- (void)hudDidSelectAction:(AB12Action)action {
    if (self.actionBlock) {
        self.actionBlock(action);
    }
}

- (void)hudDidRequestDismiss {
    if (self.dismissBlock) {
        self.dismissBlock();
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end

@interface AB12HUDWindow ()
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, strong) AB12ViewController *viewController;
@end

@implementation AB12HUDWindow

+ (instancetype)sharedWindow {
    static AB12HUDWindow *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AB12HUDWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1000.0;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
        
        _viewController = [[AB12ViewController alloc] init];
        self.rootViewController = _viewController;
    }
    return self;
}

- (void)showWithActions:(NSArray<NSNumber *> *)actions showSliders:(BOOL)showSliders {
    if (self.isShowing) return;
    self.isShowing = YES;
    
    self.frame = [UIScreen mainScreen].bounds;
    
    if (!self.viewController.hudView) {
        self.viewController.hudView = [[AB12HUDView alloc] initWithActions:actions showSliders:showSliders];
        self.viewController.hudView.delegate = self.viewController;
        [self.viewController.view addSubview:self.viewController.hudView];
    } else {
        [self.viewController.hudView updateActions:actions showSliders:showSliders];
    }
    
    // Center HUD in window
    self.viewController.hudView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    
    // Initial state: scale 0.8, alpha 0.0
    self.viewController.hudView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    self.viewController.hudView.alpha = 0.0;
    
    self.hidden = NO;
    [self makeKeyAndVisible];
    
    // Appearance: scale 0.8 -> 1.0 + alpha 0 -> 1, 0.2s
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.viewController.hudView.transform = CGAffineTransformIdentity;
        self.viewController.hudView.alpha = 1.0;
    } completion:nil];
}

- (void)hideWithCompletion:(void (^)(void))completion {
    if (!self.isShowing) {
        if (completion) completion();
        return;
    }
    
    // Dismiss: scale 1.0 -> 0.8 + alpha 1 -> 0, 0.15s
    [UIView animateWithDuration:0.15
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.viewController.hudView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        self.viewController.hudView.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.isShowing = NO;
        self.hidden = YES;
        if (completion) completion();
    }];
}

@end
