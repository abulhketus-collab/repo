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

static NSDictionary *gGlintLastMRInfo = nil;

static void _glintMediaCallback(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] updateMusicState];
    });
}

static void _glintMediaDarwinCallback(CFNotificationCenterRef center, void *observer,
                                      CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    _glintMediaCallback();
}

@implementation GlintMediaObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowMusic" defaultValue:YES]) return;

    // MediaRemote notifications are delivered to this queue; Darwin observer
    // triggers a refresh of the island state when Safari/Music changes track.
    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    _glintMediaDarwinCallback,
                                    CFSTR("com.apple.mobilemedia.remote.nowplaying.info"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    [[GlintStateManager sharedManager] updateMusicState];
}

+ (void)uninstall {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                       NULL,
                                       CFSTR("com.apple.mobilemedia.remote.nowplaying.info"),
                                       NULL);
    gGlintLastMRInfo = nil;
}

+ (NSDictionary *)currentNowPlayingInfo {
    @try {
        // Primary source on iOS 12: SBMediaController (works for Music and Safari audio).
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
                    UIImage *artwork = nil;
                    if ([media respondsToSelector:@selector(nowPlayingArtwork)]) {
                        @try {
                            id art = [media performSelector:@selector(nowPlayingArtwork)];
                            if ([art isKindOfClass:[UIImage class]]) artwork = art;
                        } @catch (NSException *e) { artwork = nil; }
                    }
                    return @{
                        @"title": title,
                        @"artist": artist ?: @"",
                        @"bundleID": bundleID ?: @"",
                        @"artwork": artwork ?: [NSNull null],
                        @"source": @"SBMediaController"
                    };
                }
            }
        }

        // Fallback: MediaRemote (async, cached between callbacks).
        MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
            if (info) gGlintLastMRInfo = [(__bridge NSDictionary *)info copy];
            _glintMediaCallback();
        });
        NSDictionary *dict = gGlintLastMRInfo;
        if (!dict) return nil;

        NSString *title = dict[@"title"] ?: dict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTitle];
        NSString *artist = dict[@"artist"] ?: dict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtist];
        if (!title || title.length == 0) return nil;

        // v1.2.3: album artwork bytes -> UIImage (Safari web audio included)
        UIImage *artwork = nil;
        NSData *artData = dict[@"artworkData"] ?: dict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
        if ([artData isKindOfClass:[NSData class]] && artData.length > 0) {
            UIImage *decoded = [UIImage imageWithData:artData];
            if (decoded) artwork = decoded;
        }

        return @{
            @"title": title,
            @"artist": artist ?: @"",
            @"bundleID": @"",
            @"artwork": artwork ?: [NSNull null],
            @"source": @"MediaRemote"
        };
    } @catch (NSException *e) {
        os_log(OS_LOG_DEFAULT, "[GlintMedia] error: %@", e);
        return nil;
    }
}

@end
