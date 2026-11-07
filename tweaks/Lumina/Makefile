TARGET = iphone:clang:12.4:12.0
ARCHS = arm64 armv7
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = Lumina
Lumina_FILES = Tweak.m
Lumina_FRAMEWORKS = UIKit CoreGraphics QuartzCore
Lumina_CFLAGS = -fobjc-arc
THEOS_PACKAGE_COMPRESSION = gzip
THEOS_PACKAGE_FORMAT = gnu
include $(THEOS_MAKE_PATH)/tweak.mk
