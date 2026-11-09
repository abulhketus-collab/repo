#import "GlintRootListController.h"
#import <spawn.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>

#define GLINT_PREFS_ID CFSTR("com.cocxace.glint")
#define GLINT_RELOAD   "com.cocxace.glint/reload"

@implementation GlintRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Glint"
                                                                   message:@"Respring SpringBoard to apply changes?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        pid_t pid;
        const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)argv, NULL);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetDefaults {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Glint"
                                                                   message:@"Reset all Glint settings to defaults?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // v1.2.3 defaults — must mirror GlintPrefs registerDefaults
        NSDictionary<NSString *, id> *defaults = @{
            @"prefsVersion": @(3),
            @"enableGlint": @(YES),
            @"glintShowNotifications": @(YES),
            @"glintShowCharging": @(YES),
            @"glintShowMusic": @(YES),
            @"glintShowTorch": @(YES),
            @"glintShowTimer": @(YES),
            @"glintShowArtwork": @(YES),
            @"glintBeatPulse": @(YES),
            @"glintGlowEnabled": @(YES),
            @"glintGlowStrength": @(55.0),
            @"glintGlowRadius": @(14.0),
            @"glintGlowSpeed": @(5.0),
            @"glintGlowHue": @(190.0),
            @"glintGlowHue2": @(258.0),
            @"glintGlowRainbow": @(NO),
            @"glintGlowBlink": @(NO),
            @"glintPosition": @"top",
            @"glintCornerRadius": @(16.0),
            @"glintExpandedHeight": @(140.0),
            @"glintSpringStiffness": @(200.0),
            @"glintSpringDamping": @(18.0),
            @"glintAutoCollapseDelay": @(4.0),
            @"glintHapticOnTap": @(YES),
            @"glintDebug": @(NO)
        };
        for (NSString *key in defaults) {
            CFPreferencesSetAppValue((CFStringRef)key, (__bridge CFTypeRef)defaults[key], GLINT_PREFS_ID);
        }
        CFPreferencesAppSynchronize(GLINT_PREFS_ID);
        notify_post(GLINT_RELOAD);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadSpecifiers];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
