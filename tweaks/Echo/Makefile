TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 armv7
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = Echo
Echo_FILES = Tweak.m
Echo_FRAMEWORKS = UIKit
Echo_CFLAGS = -fobjc-arc
THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu
include $(THEOS_MAKE_PATH)/tweak.mk
