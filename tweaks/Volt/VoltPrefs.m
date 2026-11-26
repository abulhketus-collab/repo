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
        CFBooleanRef dbg = CFPreferencesCopyAppValue(CFSTR("voltDebug"), VOLT_APP_ID);
        if (dbg) {
            s->_debugEnabled = CFBooleanGetValue(dbg);
            CFRelease(dbg);
        }
    });
    return s;
}

+ (void)registerDefaults {
    NSDictionary *defs = @{
        @"highThreshold": @(40.0),
        @"lowThreshold": @(20.0),
        @"highColorChoice": @(0),
        @"midColorChoice": @(1),
        @"lowColorChoice": @(2),
        @"voltDebug": @(NO)
    };
    for (NSString *key in defs) {
        if (CFPreferencesCopyAppValue((__bridge CFStringRef)key, VOLT_APP_ID) == NULL) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                     (__bridge CFPropertyListRef)defs[key], VOLT_APP_ID);
        }
    }
    CFPreferencesAppSynchronize(VOLT_APP_ID);
}

- (BOOL)debugEnabled { return _debugEnabled; }

+ (BOOL)debugEnabled { return [self sharedPrefs].debugEnabled; }

@end
