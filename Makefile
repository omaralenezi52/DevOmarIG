TARGET = iphone:clang:latest:15.0
ARCHS = arm64

# Sideloaded (non-jailbroken) IPA injection: build a plain dylib, no rootless
# packaging. Flip these if you install on a jailbroken device via a .deb instead.
INSTALL_TARGET_PROCESSES = Instagram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = OmarTweak

OmarTweak_FILES = \
	Tweak.xm \
	Sources/OmarStandalone.xm \
	Sources/OmarPrefs.m \
	Sources/OmarSettingsViewController.m

OmarTweak_CFLAGS = -fobjc-arc -ISources -Wno-deprecated-declarations
OmarTweak_FRAMEWORKS = UIKit Foundation CoreLocation LocalAuthentication

include $(THEOS)/makefiles/tweak.mk
