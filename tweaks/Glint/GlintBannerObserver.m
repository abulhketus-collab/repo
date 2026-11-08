#import "GlintBannerObserver.h"
#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import <os/log.h>

static void *gOrigPresentBanner = NULL;
static void *gOrigDismissBanner = NULL;

static void hook_presentBanner(id self, SEL _cmd, id bulletin) {
    if (gOrigPresentBanner) ((void (*)(id, SEL, id))gOrigPresentBanner)(self, _cmd, bulletin);
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] addNotificationBulletin:bulletin];
    });
}

static void hook_dismissBanner(id self, SEL _cmd, id bannerView) {
    if (gOrigDismissBanner) ((void (*)(id, SEL, id))gOrigDismissBanner)(self, _cmd, bannerView);
    id bulletin = [bannerView valueForKey:@"bulletin"];
    if (bulletin) {
        NSString *sid = [bulletin valueForKey:@"sectionID"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[GlintStateManager sharedManager] removeStateWithKey:sid ? [NSString stringWithFormat:@"notif:%@", sid] : @"notif:unknown"];
        });
    }
}

@implementation GlintBannerObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    Class cls = NSClassFromString(@"SBBulletinBannerController");
    if (!cls) return;

    // РџСЂРѕР±СѓРµРј РЅРµСЃРєРѕР»СЊРєРѕ РІР°СЂРёР°РЅС‚РѕРІ СЃРµР»РµРєС‚РѕСЂР° РґР»СЏ iOS 12.4
    SEL presentSels[] = {
        NSSelectorFromString(@"_presentBulletin:"),
        NSSelectorFromString(@"_presentBulletin:animated:"),
        NSSelectorFromString(@"_presentBannerView:"),
        NSSelectorFromString(@"_presentBannerView:animated:")
    };
    BOOL hookedPresent = NO;
    for (SEL sel in presentSels) {
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            MSHookMessageEx(cls, sel, (IMP)&hook_presentBanner, (IMP *)&gOrigPresentBanner);
            hookedPresent = YES;
            os_log(OS_LOG_DEFAULT, "[GlintBanner] hooked present: %@", NSStringFromSelector(sel));
            break;
        }
    }

    SEL dismissSels[] = {
        NSSelectorFromString(@"_dismissBannerView:"),
        NSSelectorFromString(@"_dismissBulletin:"),
        NSSelectorFromString(@"dismissBanner:")
    };
    for (SEL sel in dismissSels) {
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            MSHookMessageEx(cls, sel, (IMP)&hook_dismissBanner, (IMP *)&gOrigDismissBanner);
            os_log(OS_LOG_DEFAULT, "[GlintBanner] hooked dismiss: %@", NSStringFromSelector(sel));
            break;
        }
    }

    if (!hookedPresent) {
        os_log(OS_LOG_DEFAULT, "[GlintBanner] no present selector found on this firmware");
    }
}

+ (void)uninstall {
    if (gOrigPresentBanner) {
        Class cls = NSClassFromString(@"SBBulletinBannerController");
        if (cls) {
            SEL sel = NSSelectorFromString(@"_presentBulletin:");
            Method m = class_getInstanceMethod(cls, sel);
            if (m) method_setImplementation(m, gOrigPresentBanner);
        }
        gOrigPresentBanner = NULL;
    }
    if (gOrigDismissBanner) {
        Class cls = NSClassFromString(@"SBBulletinBannerController");
        if (cls) {
            SEL sel = NSSelectorFromString(@"_dismissBannerView:");
            Method m = class_getInstanceMethod(cls, sel);
            if (m) method_setImplementation(m, gOrigDismissBanner);
        }
        gOrigDismissBanner = NULL;
    }
}

@end
