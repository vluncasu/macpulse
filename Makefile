SHELL := /bin/bash

.PHONY: doctor validate core-test build test install verify dmg preflight clean open

doctor:
	./scripts/doctor.sh

validate:
	./scripts/validate-source.sh

core-test:
	swift test

build:
	./scripts/build-local.sh

test:
	xcodebuild -project MacPulse.xcodeproj -scheme MacPulse -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

install:
	./scripts/install-local.sh dist/MacPulse.app

verify:
	./scripts/verify-release.sh dist/MacPulse.app

dmg:
	./scripts/package-dmg.sh dist/MacPulse.app

preflight:
	./scripts/release-preflight.sh

clean:
	./scripts/clean.sh

open:
	open MacPulse.xcodeproj
