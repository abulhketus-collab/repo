#import <UIKit/UIKit.h>
@interface GlintIslandView : UIView
+ (instancetype)sharedInstance;
- (void)expandWithTitle:(NSString *)title message:(NSString *)msg;
@end
