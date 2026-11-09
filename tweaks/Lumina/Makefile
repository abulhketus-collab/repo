TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Lumina
Lumina_FILES = Tweak.m LuminaPrefs.m
Lumina_FRAMEWORKS = UIKit CoreGraphics QuartzCore
Lumina_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-deprecated-declarations

THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu

include $(THEOS_MAKE_PATH)/tweak.mk

# PreferenceLoader bundle
BUNDLE_NAME = Luminaprefs
Luminaprefs_FILES = prefs/RootListController.m
Luminaprefs_INSTALL_PATH = /Library/PreferenceBundles
Luminaprefs_FRAMEWORKS = UIKit
Luminaprefs_PRIVATE_FRAMEWORKS = Preferences
Luminaprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
