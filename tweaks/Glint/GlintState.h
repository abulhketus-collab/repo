#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GlintStateType) {
    GlintStateNone = 0,
    GlintStateTorch = 100,
    GlintStateCharging = 300,
    GlintStateTimer = 450,
    GlintStateMusic = 600,
    GlintStateNotification = 1000,
};

NS_ASSUME_NONNULL_BEGIN

@interface GlintState : NSObject

@property (nonatomic, assign) GlintStateType type;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, strong, nullable) UIImage *icon;
@property (nonatomic, assign) CFTimeInterval timestamp;
@property (nonatomic, assign) BOOL persistent;

- (instancetype)initWithType:(GlintStateType)type key:(NSString *)key priority:(NSInteger)priority;

@end

NS_ASSUME_NONNULL_END
