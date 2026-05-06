# ScreenLock — quick lock screen menu-bar app.
#
# Release pipeline delegated to the shared `release.mk` from
# PerpetualBeta/jorvik-release. SPM project, embedded Sparkle,
# dual-ship (.zip + .pkg).

BUNDLE_NAME      := ScreenLock
BUNDLE_TYPE      := app
PRODUCT_NAME     := ScreenLock.app
BUNDLE_ID        := cc.jorviksoftware.ScreenLock
BUILD_SYSTEM     := spm
SPM_PRODUCT      := ScreenLock

PACKAGE_TYPE     := zip
ALSO_SHIP_PKG    := true
EMBEDDED_FRAMEWORKS := Sparkle
ENTITLEMENTS     := ScreenLock.entitlements

include ../jorvik-release/release.mk
