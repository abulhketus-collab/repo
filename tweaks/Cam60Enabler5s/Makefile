TARGET = iphone:clang:12.4:12.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Camera

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Cam60Enabler5s

Cam60Enabler5s_FILES = Tweak.m
Cam60Enabler5s_FRAMEWORKS = UIKit AVFoundation CoreMedia CoreVideo Foundation
Cam60Enabler5s_PRIVATE_FRAMEWORKS = CameraUI
Cam60Enabler5s_CFLAGS = -fobjc-arc -fobjc-exceptions -O2 -Wno-deprecated-declarations

THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu

include $(THEOS_MAKE_PATH)/tweak.mk

# PreferenceLoader bundle
BUNDLE_NAME = Cam60Prefs
Cam60Prefs_FILES = prefs/RootListController.m
Cam60Prefs_INSTALL_PATH = /Library/PreferenceBundles
Cam60Prefs_FRAMEWORKS = UIKit
Cam60Prefs_PRIVATE_FRAMEWORKS = Preferences
Cam60Prefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
