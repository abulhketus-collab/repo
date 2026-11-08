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
    // Р РµРіРёСЃС‚СЂРёСЂСѓРµРј MediaRemote СѓРІРµРґРѕРјР»РµРЅРёСЏ (fallback)
    MRMediaRemoteRegisterForNowPlayingNotifications(_glintMediaCallback, dispatch_get_main_queue());
    // РџРµСЂРІРёС‡РЅР°СЏ РїСЂРѕРІРµСЂРєР°
    [[GlintStateManager sharedManager] updateMusicState];
}

+ (void)uninstall {
    // РџСѓР±Р»РёС‡РЅРѕРіРѕ API РѕС‚РїРёСЃРєРё Сѓ MediaRemote РЅР° iOS 12 РЅРµС‚
}

+ (NSDictionary *)currentNowPlayingInfo {
    @try {
        // РћРЎРќРћР’РќРћР™ РёСЃС‚РѕС‡РЅРёРє РЅР° iOS 12 вЂ” SBMediaController (РЅР°РґС‘Р¶РЅРµРµ MediaRemote)
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
                    return @{
                        @"title": title ?: @"",
                        @"artist": artist ?: @"",
                        @"bundleID": bundleID ?: @"",
                        @"source": @"SBMediaController"
                    };
                }
            }
        }

        // FALLBACK вЂ” MediaRemote
        CFDictionaryRef info = MRMediaRemoteGetNowPlayingInfo();
        if (!info) return nil;
        NSDictionary *dict = (__bridge_transfer NSDictionary *)info;

        // РљР»СЋС‡Рё MediaRemote вЂ” СЃС‚СЂРѕРєРѕРІС‹Рµ Р»РёС‚РµСЂР°Р»С‹, С‚.Рє. РєРѕРЅСЃС‚Р°РЅС‚С‹ РјРѕРіСѓС‚ РЅРµ СЃСѓС‰РµСЃС‚РІРѕРІР°С‚СЊ РІ iOS 12 Р·Р°РіРѕР»РѕРІРєР°С…
        NSString *title = dict[@"title"] ?: dict[@(kMRMediaRemoteNowPlayingInfoTitle)];
        NSString *artist = dict[@"artist"] ?: dict[@(kMRMediaRemoteNowPlayingInfoArtist)];
        NSDictionary *client = dict[@"clientPropertiesData"] ?: dict[@(kMRMediaRemoteNowPlayingInfoClientPropertiesData)];
        NSString *clientBundle = client ? (client[@"bundleID"] ?: client[@(kMRMediaRemoteNowPlayingInfoClientBundleID)]) : @"";

        if (!title || title.length == 0) return nil;

        return @{
            @"title": title,
            @"artist": artist ?: @"",
            @"bundleID": clientBundle ?: @"",
            @"source": @"MediaRemote"
        };
    } @catch (NSException *e) {
        os_log(OS_LOG_DEFAULT, "[GlintMedia] error: %@", e);
        return nil;
    }
}

@end
