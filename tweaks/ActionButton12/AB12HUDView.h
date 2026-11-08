#import <UIKit/UIKit.h>
#import "AB12Common.h"

@protocol AB12HUDViewDelegate <NSObject>
- (void)hudDidSelectAction:(AB12Action)action;
- (void)hudDidRequestDismiss;
@end

@interface AB12HUDCell : UIControl
@property (nonatomic, assign) AB12Action action;
@property (nonatomic, strong) UIImageView *iconImageView;
- (instancetype)initWithFrame:(CGRect)frame action:(AB12Action)action;
- (void)updateAction:(AB12Action)action;
@end

typedef NS_ENUM(NSInteger, AB12SliderType) {
    AB12SliderTypeBrightness = 0,
    AB12SliderTypeVolume = 1
};

@interface AB12SliderView : UIView
@property (nonatomic, assign) AB12SliderType type;
@property (nonatomic, assign) CGFloat value;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, copy) void (^valueChangedBlock)(CGFloat value);
- (instancetype)initWithFrame:(CGRect)frame type:(AB12SliderType)type;
- (void)updateValue:(CGFloat)value animated:(BOOL)animated;
@end

@interface AB12HUDView : UIView
@property (nonatomic, weak) id<AB12HUDViewDelegate> delegate;
@property (nonatomic, assign) BOOL showSliders;
- (instancetype)initWithActions:(NSArray<NSNumber *> *)actions showSliders:(BOOL)showSliders;
- (void)updateActions:(NSArray<NSNumber *> *)actions showSliders:(BOOL)showSliders;
@end

@interface AB12ViewController : UIViewController <AB12HUDViewDelegate>
@property (nonatomic, strong) AB12HUDView *hudView;
@property (nonatomic, copy) void (^actionBlock)(AB12Action);
@property (nonatomic, copy) void (^dismissBlock)(void);
@end

@interface AB12HUDWindow : UIWindow
+ (instancetype)sharedWindow;
- (void)showWithActions:(NSArray<NSNumber *> *)actions showSliders:(BOOL)showSliders;
- (void)hideWithCompletion:(void (^)(void))completion;
@property (nonatomic, readonly) BOOL isShowing;
@end
