#import <UIKit/UIKit.h>

@interface AuraHUDView : UIView
+ (instancetype)sharedInstance;
- (void)presentHUD;
- (void)dismissHUD;
@end
