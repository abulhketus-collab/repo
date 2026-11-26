#import "GlintMediaObserver.h"
#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import <MediaRemote/MediaRemote.h>
#import <os/log.h>

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (NSString *)nowPlayingTitle;
- (NSString *)nowPlayingArtist;
- (id)nowPlayingApplication;
- (BOOL)isPlaying;
@end

static void _glintMediaCallback(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] updateMusicState];
    });
}

@implementation GlintMediaObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowMusic" defaultValue:YES]) return;
    // Регистрируем MediaRemote уведомления (fallback)
    MRMediaRemoteRegisterForNowPlayingNotifications(_glintMediaCallback, dispatch_get_main_queue());
    // Первичная проверка
    [[GlintStateManager sharedManager] updateMusicState];
}

+ (void)uninstall {
    // Публичного API отписки у MediaRemote на iOS 12 нет
}

+ (NSDictionary *)currentNowPlayingInfo {
    @try {
        // ОСНОВНОЙ источник на iOS 12 — SBMediaController (надёжнее MediaRemote)
        Class sbMediaCls = NSClassFromString(@"SBMediaController");
        if (sbMediaCls) {
            id media = [sbMediaCls performSelector:@selector(sharedInstance)];
            if (media) {
                NSString *title = nil;
                NSString *artist = nil;
                if ([media respondsToSelector:@selector(nowPlayingTitle)]) {
                    title = [media performSelector:@selector(nowPlayingTitle)];
                }
                if ([media respondsToSelector:@selector(nowPlayingArtist)]) {
                    artist = [media performSelector:@selector(nowPlayingArtist)];
                }
                if (title && title.length > 0) {
                    id app = nil;
                    NSString *bundleID = @"";
                    if ([media respondsToSelector:@selector(nowPlayingApplication)]) {
                        app = [media performSelector:@selector(nowPlayingApplication)];
                        if (app && [app respondsToSelector:@selector(bundleIdentifier)]) {
                            bundleID = [app performSelector:@selector(bundleIdentifier)];
                        }
                    }
                    // v1.2.3: artwork if SBMediaController exposes it (guarded)
                    UIImage *artwork = nil;
                    if ([media respondsToSelector:@selector(nowPlayingArtwork)]) {
                        @try {
                            id art = [media performSelector:@selector(nowPlayingArtwork)];
                            if ([art isKindOfClass:[UIImage class]]) artwork = art;
                        } @catch (NSException *e) { artwork = nil; }
                    }
                    return @{
                        @"title": title ?: @"",
                        @"artist": artist ?: @"",
                        @"bundleID": bundleID ?: @"",
                        @"artwork": artwork ?: [NSNull null],
                        @"source": @"SBMediaController"
                    };
                }
            }
        }

        // FALLBACK — MediaRemote
        CFDictionaryRef info = MRMediaRemoteGetNowPlayingInfo();
        if (!info) return nil;
        NSDictionary *dict = (__bridge_transfer NSDictionary *)info;

        // Ключи MediaRemote — строковые литералы, т.к. константы могут не существовать в iOS 12 заголовках
        NSString *title = dict[@"title"] ?: dict[@(kMRMediaRemoteNowPlayingInfoTitle)];
        NSString *artist = dict[@"artist"] ?: dict[@(kMRMediaRemoteNowPlayingInfoArtist)];
        NSDictionary *client = dict[@"clientPropertiesData"] ?: dict[@(kMRMediaRemoteNowPlayingInfoClientPropertiesData)];
        NSString *clientBundle = client ? (client[@"bundleID"] ?: client[@(kMRMediaRemoteNowPlayingInfoClientBundleID)]) : @"";

        if (!title || title.length == 0) return nil;

        // v1.2.3: album artwork bytes → UIImage (Safari web audio тоже попадает сюда)
        UIImage *artwork = nil;
        NSData *artData = dict[@"artworkData"] ?: dict[@(kMRMediaRemoteNowPlayingInfoArtworkData)];
        if ([artData isKindOfClass:[NSData class]] && artData.length > 0) {
            UIImage *decoded = [UIImage imageWithData:artData];
            if (decoded) artwork = decoded;
        }

        return @{
            @"title": title,
            @"artist": artist ?: @"",
            @"bundleID": clientBundle ?: @"",
            @"artwork": artwork ?: [NSNull null],
            @"source": @"MediaRemote"
        };
    } @catch (NSException *e) {
        os_log(OS_LOG_DEFAULT, "[GlintMedia] error: %@", e);
        return nil;
    }
}

@end
