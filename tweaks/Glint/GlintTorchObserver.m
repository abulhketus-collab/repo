#import "GlintTorchObserver.h"
#import "GlintStateManager.h"
#import "GlintPrefs.h"
#import <AVFoundation/AVFoundation.h>
#import <os/log.h>

@implementation GlintTorchObserver

+ (void)install {
    if (![GlintPrefs boolForKey:@"glintShowTorch" defaultValue:YES]) return;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceChanged:)
                                                 name:AVCaptureDeviceWasConnectedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceChanged:)
                                                 name:AVCaptureDeviceWasDisconnectedNotification
                                               object:nil];
    [[GlintStateManager sharedManager] updateTorchState];
}

+ (void)uninstall {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (BOOL)hasTorch {
    AVCaptureDevice *d = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!d) return NO;
    if ([d respondsToSelector:@selector(hasTorch)]) return [d hasTorch];
    if ([d respondsToSelector:@selector(isTorchAvailable)]) return [d isTorchAvailable];
    return NO;
}

+ (BOOL)isTorchOn {
    AVCaptureDevice *d = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!d) return NO;
    return d.torchMode == AVCaptureTorchModeOn;
}

+ (void)setTorchOn:(BOOL)on {
    AVCaptureDevice *d = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!d) return;
    NSError *err = nil;
    if ([d lockForConfiguration:&err]) {
        if (on) {
            if ([d isTorchModeSupported:AVCaptureTorchModeOn]) {
                [d setTorchModeOnWithLevel:1.0 error:&err];
            }
        } else {
            [d setTorchMode:AVCaptureTorchModeOff];
        }
        [d unlockForConfiguration];
    }
    if (err) os_log(OS_LOG_DEFAULT, "[GlintTorch] lock error: %@", err);
    [[GlintStateManager sharedManager] updateTorchState];
}

- (void)deviceChanged:(id)note {
    [[GlintStateManager sharedManager] updateTorchState];
}

@end
