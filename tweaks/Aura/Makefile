TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Aura
Aura_FILES = Tweak.m AuraHUDView.m AuraPrefs.m
Aura_FRAMEWORKS = UIKit CoreGraphics QuartzCore AudioToolbox AVFoundation
Aura_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-deprecated-declarations

THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu

include $(THEOS_MAKE_PATH)/tweak.mk

# PreferenceLoader bundle
BUNDLE_NAME = Auraprefs
Auraprefs_FILES = prefs/RootListController.m
Auraprefs_INSTALL_PATH = /Library/PreferenceBundles
Auraprefs_FRAMEWORKS = UIKit
Auraprefs_PRIVATE_FRAMEWORKS = Preferences
Auraprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
