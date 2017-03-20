export GO_EASY_ON_ME = 1

export ARCHS = armv7 arm64
export SDKVERSION = 8.1
export TARGET = iphone:clang:8.1

export DEBUG = 0
ifeq ($(DEBUG),1)
	PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)+debug
else
	PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
endif

ADDITIONAL_CFLAGS = -Iinclude
ADDITIONAL_LDFLAGS = -L./lib

PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)

include $(THEOS)/makefiles/common.mk
_THEOS_INTERNAL_CFLAGS += -w

TWEAK_NAME = OpenNotifier
OpenNotifier_FILES = Tweak.xm Preferences.mm
OpenNotifier_LIBRARIES = statusbar

BUNDLE_NAME = OpenNotifierSettings
OpenNotifierSettings_BUNDLE_NAME = OpenNotifier
OpenNotifierSettings_FILES =  Settings.mm Preferences.mm
OpenNotifierSettings_INSTALL_PATH = /Library/PreferenceBundles
OpenNotifierSettings_FRAMEWORKS = UIKit CoreGraphics
OpenNotifierSettings_PRIVATE_FRAMEWORKS = Preferences
OpenNotifierSettings_LIBRARIES = applist substrate

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard"
