#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AudioToolbox/AudioToolbox.h>

@interface GlintVC : UIViewController
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation GlintVC
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    // Fit 320 width screen: 110x26 pill
    self.pill = [[UIView alloc] initWithFrame:CGRectMake((320 - 110)/2, 6, 110, 26)];
    self.pill.backgroundColor = [UIColor blackColor];
    self.pill.layer.cornerRadius = 13.0;
    self.pill.clipsToBounds = YES;
    self.pill.layer.borderWidth = 0.5;
    self.pill.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;

    self.titleLabel = [[UILabel alloc] initWithFrame:self.pill.bounds];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    self.titleLabel.text = @"Glint";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.pill addSubview:self.titleLabel];

    [self.view addSubview:self.pill];
}
@end

@interface GlintManager : NSObject
+ (instancetype)shared;
- (void)start;
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GlintManager
+ (instancetype)shared {
    static GlintManager *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s = [[GlintManager alloc] init]; });
    return s;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.window) return;
            self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
            self.window.windowLevel = UIWindowLevelStatusBar - 1.0;
            self.window.backgroundColor = [UIColor clearColor];
            self.window.userInteractionEnabled = NO;
            self.window.rootViewController = [[GlintVC alloc] init];
            self.window.hidden = NO;
        } @catch (NSException *e) {
            NSLog(@"[Tweak Error] Glint start: %@", e);
        }
    });
}
@end

static void (*orig_appDidFinishLaunching)(id self, SEL _cmd, id app);
static void hook_appDidFinishLaunching(id self, SEL _cmd, id app) {
    if (orig_appDidFinishLaunching) orig_appDidFinishLaunching(self, _cmd, app);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[GlintManager shared] start];
    });
}

__attribute__((constructor)) static void initGlint() {
    @autoreleasepool {
        NSLog(@"[CocxaceTweak] Glint Loaded successfully");
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
