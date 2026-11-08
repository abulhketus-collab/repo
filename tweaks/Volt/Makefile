TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 armv7
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = Volt
Volt_FILES = Tweak.m
Volt_FRAMEWORKS = UIKit
Volt_CFLAGS = -fobjc-arc -fobjc-exceptions -Wno-deprecated-declarations
THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu
include $(THEOS_MAKE_PATH)/tweak.mk