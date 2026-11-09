#import "GlintTimerModule.h"
#import "GlintPrefs.h"
#import "GlintStateManager.h"
#import <os/log.h>

static NSTimer *_pollTimer = nil;
static NSInteger _remaining = -1;
static BOOL _wasActive = NO;
static BOOL _finishFired = NO;

#define GlintTLog(...) \
    do { if ([GlintPrefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[GlintTimer] " __VA_ARGS__); } while (0)

#pragma mark - Deep search helpers

// Recursively look for a countdown inside an arbitrary plist structure.
// mobiletimerd schema is not public, so we search for well-known keys.
static void TimerDeepSearch(id node, NSString *path, NSDate **endDate, CGFloat *secondsLeft, BOOL *paused) {
    if (!node) return;

    @try {
        if ([node isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)node;
            for (NSString *key in dict) {
                NSString *lk = key.lowercaseString;
                id val = dict[key];

                // Direct remaining-seconds counters
                if ([val isKindOfClass:[NSNumber class]] &&
                    ([lk containsString:@"secondsremaining"] ||
                     [lk containsString:@"timeleft"] ||
                     [lk containsString:@"remainingtime"])) {
                    CGFloat v = [(NSNumber *)val doubleValue];
                    if (v > 0 && v < 86400.0 && *secondsLeft < 0) *secondsLeft = v;
                }

                // Target end dates
                if ([val isKindOfClass:[NSDate class]] &&
                    ([lk containsString:@"enddate"] ||
                     [lk containsString:@"firedate"] ||
                     [lk containsString:@"targetdate"] ||
                     [lk containsString:@"countdowndate"])) {
                    NSTimeInterval delta = [(NSDate *)val timeIntervalSinceNow];
                    if (delta > 0 && delta < 86400.0 && !*endDate) *endDate = val;
                }

                // Pause flag
                if ([val isKindOfClass:[NSNumber class]] &&
                    ([lk isEqualToString:@"paused"] || [lk isEqualToString:@"ispaused"])) {
                    if ([(NSNumber *)val boolValue]) *paused = YES;
                }

                TimerDeepSearch(val, [path stringByAppendingFormat:@"/%@", key], endDate, secondsLeft, paused);
            }
        } else if ([node isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)node) {
                TimerDeepSearch(item, path, endDate, secondsLeft, paused);
            }
        }
    } @catch (NSException *e) {
        GlintTLog(@"deep search exception: %@", e);
    }
}

static NSInteger TimerComputeRemaining(void) {
    @try {
        NSArray *candidateKeys = @[@"timerState", @"timer", @"timers", @"countdown", @"countdownTimer", @"state"];
        for (NSString *ck in candidateKeys) {
            CFTypeRef raw = CFPreferencesCopyAppValue((CFStringRef)ck, CFSTR("com.apple.mobiletimerd"));
            if (!raw) continue;
            @autoreleasepool {
                NSDictionary *dict = nil;
                if (CFGetTypeID(raw) == CFDictionaryGetTypeID()) {
                    dict = [(__bridge NSDictionary *)raw copy];
                } else if (CFGetTypeID(raw) == CFArrayGetTypeID()) {
                    // wrap the array so the deep search can walk it
                    dict = @{@"__wrapped": (__bridge NSArray *)raw};
                }
                if (dict) {
                    NSDate *endDate = nil;
                    CGFloat secondsLeft = -1.0;
                    BOOL paused = NO;
                    TimerDeepSearch(dict, ck, &endDate, &secondsLeft, &paused);
                    if (endDate && !paused) {
                        CGFloat delta = (CGFloat)[endDate timeIntervalSinceNow];
                        if (delta > 0 && delta < 86400.0) return (NSInteger)delta;
                    }
                    if (secondsLeft > 0 && !paused) return (NSInteger)secondsLeft;
                }
                CFRelease(raw);
            }
        }
    } @catch (NSException *e) {
        GlintTLog(@"compute remaining exception: %@", e);
    }
    return -1;
}

#pragma mark - Poll

static void TimerPoll(void) {
    if (![GlintPrefs boolForKey:@"glintShowTimer" defaultValue:YES]) {
        if (_wasActive) {
            _wasActive = NO;
            _remaining = -1;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[GlintStateManager sharedManager] removeStatesOfType:GlintStateTimer];
            });
        }
        return;
    }

    NSInteger remaining = TimerComputeRemaining();

    dispatch_async(dispatch_get_main_queue(), ^{
        if (remaining > 0) {
            _remaining = remaining;
            _finishFired = NO;
            if (!_wasActive) GlintTLog(@"native timer detected, %ld s left", (long)remaining);
            _wasActive = YES;
            [[GlintStateManager sharedManager] updateTimerState];
        } else {
            if (_wasActive && !_finishFired) {
                // Timer just crossed zero — celebrate once
                _finishFired = YES;
                [[GlintStateManager sharedManager] timerDidFinish];
            }
            if (_wasActive && remaining < 0) {
                _wasActive = NO;
                _remaining = -1;
                [[GlintStateManager sharedManager] removeStatesOfType:GlintStateTimer];
            }
        }
    });
}

@implementation GlintTimerModule

+ (void)install {
    if (_pollTimer) return;
    _pollTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(pollTick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_pollTimer forMode:NSRunLoopCommonModes];
    TimerPoll();
    GlintTLog(@"installed");
}

+ (void)pollTick {
    TimerPoll();
}

+ (void)uninstall {
    if (_pollTimer) {
        [_pollTimer invalidate];
        _pollTimer = nil;
    }
    _remaining = -1;
    _wasActive = NO;
}

+ (NSInteger)remainingSeconds {
    return _remaining;
}

@end
