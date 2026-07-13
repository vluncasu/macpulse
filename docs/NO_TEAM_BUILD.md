# No-Team Build Design

## 1. Objective

The no-team edition must compile and run locally without an Apple Developer Team ID, registered App Group, provisioning profile, or paid developer membership.

## 2. Signing model

The project uses an ad-hoc signature:

```text
CODE_SIGN_IDENTITY=-
DEVELOPMENT_TEAM=
PROVISIONING_PROFILE_SPECIFIER=
```

This signature satisfies local bundle integrity requirements. It does not establish a publisher identity.

## 3. Widget data model

App Group entitlements require provisioning. The no-team edition therefore does not use an App Group container. The WidgetKit extension performs an independent bounded telemetry sample whenever WidgetKit requests a timeline.

Consequences:

- the menu-bar dashboard remains the live surface;
- widget refresh frequency remains controlled by WidgetKit;
- widget history is extension-local;
- no cross-process shared container is required.

## 4. Distribution limitation

An ad-hoc signed application or DMG is not appropriate for unrestricted public distribution. Other systems may display Gatekeeper warnings. Developer ID signing and notarization are required for a normal public release.
