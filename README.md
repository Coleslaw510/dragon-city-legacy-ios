# Dragon City Legacy — iOS wrapper

A standalone iOS 16+ SwiftUI/WKWebView wrapper. This repository contains only the wrapper and its original dragon-egg icon; it does not include game files, server code, or credentials.

## Build

The app loads `http://132.145.159.218:8080`. The URL is intentionally hardcoded in both `DragonCityLegacy/Info.plist` (`SERVER_URL`) and `DragonCityLegacy/WebViewModel.swift`; the two values must match. The address is public because this is a public repository and it is also present in the IPA. No repository secrets or variables are needed.

Push to `main` or manually run **Build iOS wrapper** in GitHub Actions. Push a tag beginning with `v` to build the IPA and attach it to the corresponding GitHub release. The workflow needs contents-write permission for a release. It builds for a generic iOS device with signing disabled, packages the app in `Payload/`, and uploads the `DragonCityLegacy-unsigned-ipa` Actions artifact.

The IPA is **unsigned**. It must be signed and provisioned separately with an appropriate sideloading tool before it can run on a device. This workflow does not produce an App Store distribution build.

## Runtime behavior and limitations

- The app targets `com.colemcclintock.dclegacy`, supports iPhone and iPad, is landscape-only, and hides the status bar. A native launch screen, loading indicator, and offline/retry screen are included.
- The default persistent WebKit data store retains cookies and website data across launches. Actual login persistence also depends on the server's session policy and the user not clearing app data.
- Inline media and playback without a user gesture are enabled. Actual audio/video behavior can still depend on the website, iOS/WebKit, device settings, and media attributes.
- Pinch zoom and bounce are disabled. A viewport rule and document handlers suppress selection, context menus, and double-tap zoom. WKWebView and website scripts vary across iOS versions, so these restrictions are best-effort. Ordinary scrolling remains available where the website permits it.
- Web-page taps and the native Retry button produce lightweight haptics on supported hardware. Drags do not intentionally trigger feedback.
- Main-frame, subframe, redirect-response, and new-window **navigations** must match the server's scheme, hostname, and effective port. Same-origin new-window requests reuse the current view. External websites, custom schemes, files, and other origins are not opened; cross-origin login pages and iframes therefore will not work.
- This is a navigation policy, **not a network firewall**: WebKit may fetch a redirect before the response is rejected, and it can make cross-origin subresource requests as allowed by the page and WebKit. Restrict server redirects and use server-side Content Security Policy or network controls if all external traffic must be prevented. The website served from the allowed origin is trusted to run its own JavaScript.
- The server uses unencrypted HTTP. Login details and other traffic can be exposed in transit. `NSAllowsArbitraryLoads` is intentionally enabled to support HTTP and weakens transport security. Use HTTPS when possible.

## Validation

The workflow compiles and runs the real `ServerOrigin.swift` policy tests on macOS before building. Run the portable page-behavior test with `node Tests/test_web_behavior.js`. Compiling the iOS app requires Xcode and an iOS SDK.
