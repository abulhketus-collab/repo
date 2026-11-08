#import "GlintPrefs.h"
#import "GlintStateManager.h"
#import "GlintWindow.h"
#import "GlintBannerObserver.h"
#import "GlintMediaObserver.h"
#import "GlintPowerObserver.h"
#import "GlintTorchObserver.h"
#import <os/log.h>

#define GlintXLog(...) \
    do { if ([GlintPrefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[Glint.xm] %s: " __VA_ARGS__, __PRETTY_FUNCTION__); } while(0)

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
// РЈС‚РѕС‡РЅРёС‚СЊ СЃРµР»РµРєС‚РѕСЂ С‡РµСЂРµР· class-dump iOS 12.4: _presentBulletin:animated: / _presentBannerView:
- (void)_presentBulletin:(id)bulletin animated:(BOOL)animated {
    %orig;
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] addNotificationBulletin:bulletin];
    });
}
// РЈРґР°Р»РёС‚СЊ СЃРѕСЃС‚РѕСЏРЅРёРµ Glint РїСЂРё Р·Р°РєСЂС‹С‚РёРё Р±Р°РЅРЅРµСЂР° СѓРІРµРґРѕРјР»РµРЅРёСЏ
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

%end  // %group GlintGroup

// Р”РµСЃС‚СЂСѓРєС‚РѕСЂ: С‡РёСЃС‚РёРј РѕРєРЅРѕ Рё РЅР°Р±Р»СЋРґР°С‚РµР»Рё РїСЂРё РІС‹РіСЂСѓР·РєРµ tweak (%c / respring)
__attribute__((destructor)) static void cleanupGlint(void) {
    @autoreleasepool {
        GlintXLog(@"destructor вЂ” cleaning up Glint window and observers");
        [[GlintWindow sharedWindow] destroy];
        [[GlintStateManager sharedManager] tearDown];
        [GlintMediaObserver uninstall];
        [GlintPowerObserver uninstall];
        [GlintTorchObserver uninstall];
        [GlintBannerObserver uninstall];
    }
}
