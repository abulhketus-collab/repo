#import "GlintPrefs.h"
#import "GlintStateManager.h"
#import "GlintWindow.h"
#import "GlintBannerObserver.h"
#import "GlintMediaObserver.h"
#import "GlintPowerObserver.h"
#import "GlintTorchObserver.h"
#import "GlintTimerModule.h"
#import "GlintState.h"
#import <os/log.h>

#define GlintXLog(...) \
    do { if ([GlintPrefs debugEnabled]) \
        os_log(OS_LOG_DEFAULT, "[Glint.xm] %s: " __VA_ARGS__, __PRETTY_FUNCTION__); } while(0)

static void GlintShowGreeting(void) {
    // One-shot "Glint 1.2.3" pill on launch, low priority so real events win
    @try {
        GlintState *s = [[GlintState alloc] initWithType:GlintStateNone
                                                        key:@"glint-greeting"
                                                 priority:500];
        s.title = @"Glint 1.2.3";
        s.subtitle = @"Dynamic Island active";
        s.persistent = NO;
        s.timestamp = CACurrentMediaTime();
        [[GlintStateManager sharedManager] addState:s];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[GlintStateManager sharedManager] removeStateWithKey:@"glint-greeting"];
        });
    } @catch (NSException *e) { }
}

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
            // v1.2.3: native countdown timer mirrored next to the clock
            [GlintTimerModule install];
            GlintShowGreeting();
        });
    }
}
%end

%hook SBBulletinBannerController
// Уточнить селектор через class-dump iOS 12.4: _presentBulletin:animated: / _presentBannerView:
- (void)_presentBulletin:(id)bulletin animated:(BOOL)animated {
    %orig;
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] addNotificationBulletin:bulletin];
    });
}
// Удалить состояние Glint при закрытии баннера уведомления
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

// Деструктор: чистим окно и наблюдатели при выгрузке tweak (%c / respring)
__attribute__((destructor)) static void cleanupGlint(void) {
    @autoreleasepool {
        GlintXLog(@"destructor — cleaning up Glint window and observers");
        [[GlintWindow sharedWindow] destroy];
        [[GlintStateManager sharedManager] tearDown];
        [GlintMediaObserver uninstall];
        [GlintPowerObserver uninstall];
        [GlintTorchObserver uninstall];
        [GlintBannerObserver uninstall];
        [GlintTimerModule uninstall];
    }
}
