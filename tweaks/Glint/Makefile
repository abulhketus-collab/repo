TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Glint
Glint_FILES = Tweak.xm \
              GlintWindow.m \
              GlintState.m \
              GlintStateManager.m \
              GlintMediaObserver.m \
              GlintPowerObserver.m \
              GlintTorchObserver.m \
              GlintBannerObserver.m \
              GlintPrefs.m
Glint_FRAMEWORKS = UIKit CoreGraphics QuartzCore AudioToolbox MediaRemote IOKit AVFoundation
Glint_PRIVATE_FRAMEWORKS = SpringBoard
Glint_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-deprecated-declarations
Glint_LIBRARIES = substrate
THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = GlintPreferences
GlintPreferences_FILES = prefs/GlintRootListController.mm
GlintPreferences_INSTALL_PATH = /Library/PreferenceBundles
GlintPreferences_FRAMEWORKS = UIKit
GlintPreferences_PRIVATE_FRAMEWORKS = Preferences
GlintPreferences_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk