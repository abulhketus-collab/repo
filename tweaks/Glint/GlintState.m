#import "GlintState.h"

@implementation GlintState

- (instancetype)initWithType:(GlintStateType)type key:(NSString *)key priority:(NSInteger)priority {
    if (self = [super init]) {
        _type = type;
        _priority = priority;
        _key = key ?: @"";
        _timestamp = CACurrentMediaTime();
        _persistent = NO;
    }
    return self;
}

@end