#import "VoltPrefs.h"
#import <CoreFoundation/CoreFoundation.h>

#define VOLT_APP_ID CFSTR("com.cocxace.volt")

@implementation VoltPrefs {
    BOOL _debugEnabled;
}

+ (instancetype)sharedPrefs {
    static VoltPrefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
    });
    return s;
}

+ (void)registerDefaults {
    CFPreferencesSetAppValue(CFSTR("highThreshold"), (__bridge CFPropertyListRef)@(40.0), VOLT_APP_ID);
    CFPreferencesSetAppValue(CFSTR("lowThreshold"), (__bridge CFPropertyListRef)@(20.0), VOLT_APP_ID);
    CFPreferencesAppSynchronize(VOLT_APP_ID);
}

+ (BOOL)debugEnabled {
    return [self sharedPrefs]->_debugEnabled;
}

@end
