#import "GlintPrefs.h"
#import "GlintStateManager.h"
#import "GlintWindow.h"
#import "GlintBannerObserver.h"
#import "GlintMediaObserver.h"
#import "GlintPowerObserver.h"
#import "GlintTorchObserver.h"
#import <os/log.h>

#define GlintXLog(...)     do { if ([GlintPrefs debugEnabled])         os_log(OS_LOG_DEFAULT, "[Glint.xm] %s: " __VA_ARGS__, __PRETTY_FUNCTION__); } while(0)

%group GlintGroup

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    if ([GlintPrefs boolForKey:@"enableGlint" defaultValue:YES]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[GlintStateManager sharedManager] setupIfEnabled];
            [GlintMediaObserver install];
            [GlintPowerObserver install];
            [GlintTorchObserver install];
            [GlintBannerObserver install];
        });
    }
}
%end

%hook SBBulletinBannerController
- (void)_presentBulletin:(id)bulletin animated:(BOOL)animated {
    %orig;
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] addNotificationBulletin:bulletin];
    });
}
- (void)_dismissBannerView:(id)bannerView {
    %orig;
    id bulletin = [bannerView valueForKey:@"bulletin"];
    if (bulletin) {
        NSString *sid = [bulletin valueForKey:@"sectionID"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[GlintStateManager sharedManager] removeStateWithKey:sid ? [NSString stringWithFormat:@"notif:%@", sid] : @"notif:unknown"];
        });
    }
}
%end

%end