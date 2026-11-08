TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ActionButton12
ActionButton12_FILES = Tweak.xm AB12Manager.m AB12HUDView.m AB12Prefs.m
ActionButton12_FRAMEWORKS = UIKit CoreGraphics AudioToolbox AVFoundation
ActionButton12_PRIVATE_FRAMEWORKS = SpringBoard
ActionButton12_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-deprecated-declarations
ActionButton12_LIBRARIES = substrate

THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu

include $(THEOS_MAKE_PATH)/tweak.mk

# PreferenceLoader bundle
BUNDLE_NAME = ActionButton12Prefs
ActionButton12Prefs_FILES = prefs/AB12RootListController.mm
ActionButton12Prefs_INSTALL_PATH = /Library/PreferenceBundles
ActionButton12Prefs_FRAMEWORKS = UIKit
ActionButton12Prefs_PRIVATE_FRAMEWORKS = Preferences
ActionButton12Prefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
