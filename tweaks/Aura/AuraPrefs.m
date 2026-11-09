#import "AuraPrefs.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation AuraPrefs

+ (instancetype)sharedPrefs {
    static AuraPrefs *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (BOOL)debugEnabled { return NO; }

+ (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.cocxace.aura"));
    BOOL result = def;
    if (val) {
        if (CFGetTypeID(val) == CFBooleanGetTypeID()) result = CFBooleanGetValue((CFBooleanRef)val);
        else if (CFGetTypeID(val) == CFNumberGetTypeID()) {
            NSInteger v = 0;
            CFNumberGetValue((CFNumberRef)val, kCFNumberNSIntegerType, &v);
            result = (v != 0);
        }
        CFRelease(val);
    }
    return result;
}

+ (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    CFTypeRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.cocxace.aura"));
    NSInteger result = def;
    if (val) {
        if (CFGetTypeID(val) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)val, kCFNumberNSIntegerType, &result);
        }
        CFRelease(val);
    }
    return result;
}

+ (void)registerDefaults {}

@end
