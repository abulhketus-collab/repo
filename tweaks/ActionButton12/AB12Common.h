#ifndef AB12COMMON_H
#define AB12COMMON_H

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioServices.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>

#define AB12_APP_ID CFSTR("com.cocxace.actionbutton12")
#define AB12_RELOAD_NOTIFICATION CFSTR("com.cocxace.actionbutton12/reload")
#define PREF_CHANGED_NOTIFICATION "com.cocxace.actionbutton12.prefschanged"

typedef NS_ENUM(NSInteger, AB12Trigger) {
    AB12TriggerPower = 0,
    AB12TriggerHome = 1,
    AB12TriggerBoth = 2
};

typedef NS_ENUM(NSInteger, AB12Action) {
    AB12ActionFlashlight = 0,
    AB12ActionCamera = 1,
    AB12ActionVoiceMemos = 2,
    AB12ActionScreenshot = 3,
    AB12ActionWiFi = 4,
    AB12ActionBluetooth = 5
};

static inline NSString *AB12ActionName(AB12Action action) {
    switch (action) {
        case AB12ActionFlashlight: return @"flashlight";
        case AB12ActionCamera: return @"camera";
        case AB12ActionVoiceMemos: return @"voicememos";
        case AB12ActionScreenshot: return @"screenshot";
        case AB12ActionWiFi: return @"wifi";
        case AB12ActionBluetooth: return @"bluetooth";
        default: return @"flashlight";
    }
}

#endif
