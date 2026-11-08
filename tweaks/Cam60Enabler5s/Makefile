TARGET = iphone:clang:12.4:12.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Camera

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Cam60Enabler5s

Cam60Enabler5s_FILES = Tweak.m
Cam60Enabler5s_FRAMEWORKS = UIKit AVFoundation CoreMedia CoreVideo Foundation
Cam60Enabler5s_PRIVATE_FRAMEWORKS = CameraUI
Cam60Enabler5s_CFLAGS = -fobjc-arc -fobjc-exceptions -O2 -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk