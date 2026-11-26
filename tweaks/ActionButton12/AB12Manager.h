#import <Foundation/Foundation.h>
#import "AB12Common.h"

@interface AB12Manager : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) AB12Trigger trigger;
@property (nonatomic, assign) BOOL showSliders;
@property (nonatomic, assign) AB12Action action1;
@property (nonatomic, assign) AB12Action action2;
@property (nonatomic, assign) AB12Action action3;
@property (nonatomic, assign) AB12Action action4;

+ (instancetype)sharedManager;
- (void)loadPreferences;
- (void)toggleHUD;
- (void)showHUD;
- (void)hideHUD;
- (void)executeAction:(AB12Action)action;
- (void)destroy;

@end
