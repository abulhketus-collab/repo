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
        if (dbg) _debugEnabled = CFBooleanGetValue(dbg);
        if (dbg) CFRelease(dbg);
    });
    return s;
}

+ (void)registerDefaults {
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    [defs setObject:@(40.0) forKey:@"highThreshold"];
    [defs setObject:@(20.0) forKey:@"lowThreshold"];
    [defs setObject:@(0) forKey:@"highColorChoice"];
    [defs setObject:@(1) forKey:@"midColorChoice"];
    [defs setObject:@(2) forKey:@"lowColorChoice"];
    [defs setObject:@(NO) forKey:@"voltDebug"];
    CFPreferencesSetAppValues((CFDictionaryRef)defs, VOLT_APP_ID);
    CFPreferencesAppSynchronize(VOLT_APP_ID);
}

+ (BOOL)debugEnabled {
    return [self sharedPrefs]->_debugEnabled;
}

@end