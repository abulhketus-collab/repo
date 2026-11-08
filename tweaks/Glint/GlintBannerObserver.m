#import "GlintBannerObserver.h"
#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import <os/log.h>

static void *gOrigPresentBanner = NULL;

static void hook_presentBanner(id self, SEL _cmd, id bulletin) {
    if (gOrigPresentBanner) ((void (*)(id, SEL, id))gOrigPresentBanner)(self, _cmd, bulletin);
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GlintStateManager sharedManager] addNotificationBulletin:bulletin];
    });
}

@implementation GlintBannerObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowNotifications" defaultValue:YES]) return;
    Class cls = NSClassFromString(@"SBBulletinBannerController");
    if (!cls) return;
    SEL sel = NSSelectorFromString(@"_presentBulletin:");
    if (![cls respondsToSelector:sel]) sel = NSSelectorFromString(@"_presentBannerView:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        os_log(OS_LOG_DEFAULT, "[GlintBanner] selector %@ not found", NSStringFromSelector(sel));
        return;
    }
    MSHookMessageEx(cls, sel, (IMP)&hook_presentBanner, (IMP *)&gOrigPresentBanner);
    os_log(OS_LOG_DEFAULT, "[GlintBanner] hooked %@", NSStringFromSelector(sel));
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
}

@end