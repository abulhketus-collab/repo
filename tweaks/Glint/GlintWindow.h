#import <UIKit/UIKit.h>
#import "GlintState.h"

NS_ASSUME_NONNULL_BEGIN

@interface GlintWindow : UIWindow

+ (instancetype)sharedWindow;
- (void)showState:(nullable GlintState *)state animated:(BOOL)animated;
- (void)collapseAnimated:(BOOL)animated;
- (void)destroy;
- (void)updatePosition;

@property (nonatomic, assign, readonly) BOOL isVisible;

@end

NS_ASSUME_NONNULL_END