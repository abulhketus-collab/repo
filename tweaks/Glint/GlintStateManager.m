#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import "GlintWindow.h"
#import <os/log.h>

NSString *const GlintStateDidChangeNotification = @"GlintStateDidChangeNotification";

static const char *kGlintLog = "GlintStateManager";

#define GlintSMLog(...) \
    do { if ([GlintPrefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[GlintSM] %s: " __VA_ARGS__, __PRETTY_FUNCTION__); } while(0)

// Р”РµРґСѓРїР»РёРєР°С†РёСЏ СѓРІРµРґРѕРјР»РµРЅРёР№: РѕРґРЅРѕ Рё С‚Рѕ Р¶Рµ РїСЂРёР»РѕР¶РµРЅРёРµ РЅРµ СЃРїР°РјРёС‚ С‡Р°С‰Рµ 1 СЂР°Р·Р° РІ 2 СЃРµРє
static NSString *gLastNotifKey = nil;
static NSTimeInterval gLastNotifAt = 0;

@implementation GlintStateManager {
    NSMutableOrderedSet<GlintState *> *_states;
    dispatch_queue_t _queue;
}

+ (instancetype)sharedManager {
    static GlintStateManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[self alloc] init];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _states = [NSMutableOrderedSet orderedSet];
        _queue = dispatch_queue_create("com.cocxace.glint.state", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)setupIfEnabled {
    if (![GlintPrefs boolForKey:@"enableGlint" defaultValue:YES]) return;
    GlintSMLog(@"setupIfEnabled");
    [[GlintWindow sharedWindow] updatePosition];
}

- (void)tearDown {
    GlintSMLog(@"tearDown");
    [self removeAllStates];
    [[GlintWindow sharedWindow] destroy];
}

- (void)addState:(GlintState *)state {
    if (!state) return;
    dispatch_sync(_queue, ^{
        NSUInteger idx = [_states indexOfObjectPassingTest:^BOOL(GlintState *s, NSUInteger i, BOOL *stop) {
            return [s.key isEqualToString:state.key];
        }];
        if (idx != NSNotFound) [_states removeObjectAtIndex:idx];
        [_states addObject:state];
        [_states sortUsingComparator:^NSComparisonResult(GlintState *a, GlintState *b) {
            if (a.priority != b.priority) return (b.priority > a.priority) ? NSOrderedDescending : NSOrderedAscending;
            return NSOrderedSame;
        }];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintWindow sharedWindow] showState:self.topState animated:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:GlintStateDidChangeNotification object:self];
    });
}

- (void)removeStateWithKey:(NSString *)key {
    dispatch_sync(_queue, ^{
        NSUInteger idx = [_states indexOfObjectPassingTest:^BOOL(GlintState *s, NSUInteger i, BOOL *stop) {
            return [s.key isEqualToString:key];
        }];
        if (idx != NSNotFound) [_states removeObjectAtIndex:idx];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintWindow sharedWindow] showState:self.topState animated:YES];
    });
}

- (GlintState *)topState {
    __block GlintState *top = nil;
    dispatch_sync(_queue, ^{ top = [_states firstObject]; });
    return top;
}

- (NSArray<GlintState *> *)allStates {
    __block NSArray *arr = nil;
    dispatch_sync(_queue, ^{ arr = [_states copy]; });
    return arr;
}

- (void)addNotificationBulletin:(id)bulletin {
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    @try {
        NSString *title = [bulletin valueForKey:@"title"];
        NSString *body = [bulletin valueForKey:@"message"] ?: [bulletin valueForKey:@"body"];
        NSString *sectionID = [bulletin valueForKey:@"sectionID"];
        if (!sectionID || sectionID.length == 0) sectionID = [bulletin valueForKey:@"bulletinID"];

        // Р”РµРґСѓРїР»РёРєР°С†РёСЏ: РЅРµ РїРѕРєР°Р·С‹РІР°С‚СЊ РѕРґРЅРѕ Рё С‚Рѕ Р¶Рµ СѓРІРµРґРѕРјР»РµРЅРёРµ РѕС‚ С‚РѕРіРѕ Р¶Рµ РїСЂРёР»РѕР¶РµРЅРёСЏ С‡Р°С‰Рµ СЂР°Р·Р° РІ 2 СЃРµРєСѓРЅРґС‹
        NSString *dedupKey = [NSString stringWithFormat:@"notif:%@", sectionID ?: @"unknown"];
        NSTimeInterval now = CACurrentMediaTime();
        if ([dedupKey isEqualToString:gLastNotifKey] && (now - gLastNotifAt) < 2.0) {
            return;
        }
        gLastNotifKey = dedupKey;
        gLastNotifAt = now;

        GlintState *s = [[GlintState alloc] initWithType:GlintStateNotification
                                                       key:dedupKey
                                                    priority:GlintStateNotification];
        s.title = title ?: @"Notification";
        s.subtitle = body;
        s.bundleID = sectionID;
        s.timestamp = now;
        s.icon = [self iconForBundleID:sectionID];
        [self addState:s];
    } @catch (NSException *e) {
        GlintSMLog(@"parse bulletin failed: %@", e);
    }
}

- (void)removeNotificationWithSectionID:(NSString *)sectionID {
    [self removeStateWithKey:sectionID ? [NSString stringWithFormat:@"notif:%@", sectionID] : @"notif:unknown"];
}

- (UIImage *)iconForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;
    Class uiImage = NSClassFromString(@"UIImage");
    if ([uiImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:scale:)]) {
        UIImage *img = [uiImage performSelector:@selector(_applicationIconImageForBundleIdentifier:scale:)
                                  withObject:bundleID
                                  withObject:@(UIScreen.mainScreen.scale)];
        if (img) return img;
    }
    return nil;
}

- (BOOL)openBundleID:(NSString *)bundleID {
    if (!bundleID) return NO;
    Class ws = NSClassFromString(@"LSApplicationWorkspace");
    if (!ws || ![ws respondsToSelector:@selector(defaultWorkspace)]) return NO;
    id workspace = [ws performSelector:@selector(defaultWorkspace)];
    SEL sel = @selector(openApplicationWithBundleID:);
    if ([workspace respondsToSelector:sel]) {
        @try {
            [workspace performSelector:sel withObject:bundleID];
            return YES;
        } @catch (NSException *e) {
            GlintSMLog(@"open app failed: %@", e);
        }
    }
    return NO;
}

- (void)updateMusicState {
    if (![GlintPrefs boolForKey:@"glintShowMusic" defaultValue:YES]) {
        [self removeStatesOfType:GlintStateMusic];
        return;
    }
    NSDictionary *info = [GlintMediaObserver currentNowPlayingInfo];
    if (!info) {
        [self removeStatesOfType:GlintStateMusic];
        return;
    }
    NSString *title = info[(NSString *)kMRMediaRemoteNowPlayingInfoTitle];
    NSString *artist = info[(NSString *)kMRMediaRemoteNowPlayingInfoArtist];
    NSDictionary *client = info[(NSString *)kMRMediaRemoteNowPlayingInfoClientPropertiesData];
    NSString *clientBundle = client ? client[(NSString *)kMRMediaRemoteNowPlayingInfoClientBundleID] : @"";
    if (!title || title.length == 0) {
        [self removeStatesOfType:GlintStateMusic];
        return;
    }
    GlintState *s = [[GlintState alloc] initWithType:GlintStateMusic
                                                   key:[NSString stringWithFormat:@"music:%@", clientBundle]
                                                priority:GlintStateMusic];
    s.title = title;
    s.subtitle = artist ?: @"";
    s.bundleID = clientBundle;
    s.timestamp = CACurrentMediaTime();
    s.icon = [self iconForBundleID:clientBundle];
    [self addState:s];
}

- (void)updatePowerState {
    if (![GlintPrefs boolForKey:@"glintShowCharging" defaultValue:YES]) {
        [self removeStatesOfType:GlintStateCharging];
        return;
    }
    if (![GlintPowerObserver isCharging]) {
        [self removeStatesOfType:GlintStateCharging];
        return;
    }
    CGFloat capacity = [GlintPowerObserver currentCapacity];
    GlintState *s = [[GlintState alloc] initWithType:GlintStateCharging
                                                 key:@"charging"
                                              priority:GlintStateCharging];
    s.title = @"Charging";
    s.subtitle = [NSString stringWithFormat:@"%.0f%%", capacity];
    s.persistent = YES;
    s.icon = [UIImage imageNamed:@"bolt"];
    [self addState:s];
}

- (void)updateTorchState {
    if (![GlintPrefs boolForKey:@"glintShowTorch" defaultValue:YES]) {
        [self removeStatesOfType:GlintStateTorch];
        return;
    }
    if (![GlintTorchObserver isTorchOn]) {
        [self removeStatesOfType:GlintStateTorch];
        return;
    }
    GlintState *s = [[GlintState alloc] initWithType:GlintStateTorch
                                                 key:@"torch"
                                              priority:GlintStateTorch];
    s.title = @"Flashlight";
    s.subtitle = @"On";
    s.persistent = YES;
    s.icon = [UIImage imageNamed:@"flashlight.on"];
    [self addState:s];
}

- (void)removeStatesOfType:(GlintStateType)type {
    dispatch_sync(_queue, ^{
        [_states removeObjectsWithOptions:NSSortConcurrent usingBlock:^BOOL(GlintState *s, NSUInteger idx, BOOL *stop) {
            return s.type == type;
        }];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintWindow sharedWindow] showState:self.topState animated:YES];
    });
}

- (void)removeAllStates {
    [self removeStatesOfType:GlintStateNotification];
    [self removeStatesOfType:GlintStateMusic];
    [self removeStatesOfType:GlintStateCharging];
    [self removeStatesOfType:GlintStateTorch];
}

@end
