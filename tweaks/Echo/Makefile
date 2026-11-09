TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Echo
Echo_FILES = Tweak.m
Echo_FRAMEWORKS = UIKit
Echo_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-deprecated-declarations

THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu

include $(THEOS_MAKE_PATH)/tweak.mk

# PreferenceLoader bundle
BUNDLE_NAME = Echoprefs
Echoprefs_FILES = prefs/RootListController.m
Echoprefs_INSTALL_PATH = /Library/PreferenceBundles
Echoprefs_FRAMEWORKS = UIKit
Echoprefs_PRIVATE_FRAMEWORKS = Preferences
Echoprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
