#import <Preferences/PSListController.h>
#import <spawn.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>

@interface Cam60RootListController : PSListController
@end

@implementation Cam60RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cam60Enabler5s"
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cam60Enabler5s"
                                                                   message:@"Reset all settings to safe defaults?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // v1.0.3 safe defaults — 60fps off, protections on
        NSDictionary<NSString *, id> *defaults = @{
            @"enabled": @(NO),
            @"slowmo": @(NO),
            @"f4k60": @(NO),
            @"proraw": @(NO),
            @"cine": @(NO),
            @"bitrate": @(50.0),
            @"quality": @(85.0),
            @"thermal": @(YES),
            @"autodis": @(YES),
            @"profile": @(-1)
        };
        CFStringRef appID = CFSTR("com.cocxace.cam60enabler5s");
        for (NSString *key in defaults) {
            CFPreferencesSetAppValue((CFStringRef)key, (__bridge CFTypeRef)defaults[key], appID);
        }
        CFPreferencesAppSynchronize(appID);
        notify_post("com.cocxace.cam60enabler5s/reload");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self reloadSpecifiers];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
