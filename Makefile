TARGET = iphone:clang:latest:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

# Built as a plain LIBRARY (not a Theos TWEAK) on purpose: a tweak links
# CydiaSubstrate, which does not exist on a non-jailbroken device and crashes a
# sideloaded IPA at launch. This dylib hooks purely via Objective-C runtime
# swizzling (libobjc only), so it has zero external dependencies.
LIBRARY_NAME = OmarTweak

OmarTweak_FILES = \
	Sources/OmarHooks.m \
	Sources/OmarPrefs.m \
	Sources/OmarSettingsViewController.m

OmarTweak_CFLAGS = -fobjc-arc -ISources -Wno-deprecated-declarations
OmarTweak_FRAMEWORKS = UIKit Foundation CoreLocation LocalAuthentication
# @rpath so the injector (Sideloadly) can place the dylib and add its own rpath.
OmarTweak_LDFLAGS = -install_name @rpath/OmarTweak.dylib

include $(THEOS)/makefiles/library.mk
