#import "GlintMediaObserver.h"
#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import <MediaRemote/MediaRemote.h>
#import <os/log.h>

static void _glintMediaCallback(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] updateMusicState];
    });
}

@implementation GlintMediaObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowMusic" defaultValue:YES]) return;
    MRMediaRemoteRegisterForNowPlayingNotifications(_glintMediaCallback, dispatch_get_main_queue());
    [[GlintStateManager sharedManager] updateMusicState];
}

+ (void)uninstall {
    // РџСѓР±Р»РёС‡РЅРѕРіРѕ API РѕС‚РїРёСЃРєРё Сѓ MediaRemote РЅР° iOS 12 РЅРµС‚ вЂ” РїРѕР»Р°РіР°РµРјСЃСЏ РЅР° respring / destructor
}

+ (NSDictionary *)currentNowPlayingInfo {
    CFDictionaryRef info = MRMediaRemoteGetNowPlayingInfo();
    if (!info) return nil;
    return (__bridge_transfer NSDictionary *)info;
}

@end
