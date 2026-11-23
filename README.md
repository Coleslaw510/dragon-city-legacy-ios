# Dragon City Legacy — iOS wrapper

A standalone iOS 16+ SwiftUI/WKWebView wrapper. This repository contains the iOS wrapper only: it does not include the game, server, server address, or credentials. The supplied original app icon is included in the asset catalog.

## Configure and build

1. In the GitHub repository, go to **Settings → Secrets and variables → Actions** and create a **repository secret** named `SERVER_URL`. Its value must be the complete HTTP or HTTPS URL of the desired starting page, including any required port and path. Do not include credentials in the URL.
2. Push the source to `main` or start **Build iOS wrapper** with **Run workflow**. A push of a tag beginning with `v` also builds the IPA and attaches it to that tag's GitHub release. The workflow needs permission to write repository contents for the release. Repository or organization policy may additionally need to permit the listed Actions.
3. Download the `DragonCityLegacy-unsigned-ipa` Actions artifact. The IPA is **unsigned**: it must be appropriately signed and provisioned before installation on an iPhone or iPad. This workflow does not create an App Store distribution build.

The workflow first builds a generic iOS device app with signing disabled. Only afterward does its Python helper read the secret from the step's environment and silently write `SERVER_URL` into the built app's `Info.plist`, before packaging. The URL is not passed on a command line, sent to `xcodebuild`, or deliberately printed; errors are generic. If the secret is missing or invalid, packaging fails. Keep shell tracing disabled for the configuration step and never print the built plist.

**Important security boundary:** an Actions secret prevents publishing the URL in the source repository and is masked by GitHub in normal logs; it does **not** make the URL secret inside a distributed app. Anyone with the IPA can extract its `Info.plist` and discover the URL and any server IP embedded in it. Treat workflow artifacts and especially public tag releases accordingly. HTTP also exposes traffic in transit; use HTTPS where possible. `NSAllowsArbitraryLoads` is intentionally enabled to support HTTP and weakens transport security.

Opening the project and building it locally without the Actions injection is possible, but the app displays **App not configured**. There is intentionally no hardcoded or user-entered fallback URL. The project targets `com.colemcclintock.dclegacy`, supports iPhone and iPad, is landscape-only, and hides the status bar.

## Runtime behavior and limits

- The default persistent WebKit data store retains cookies and website data across launches. Actual login persistence also depends on the server's cookie/session policy and the user not clearing app data.
- Inline media is enabled and WebKit is configured not to require a user gesture for media playback. Actual audio/video behavior can still depend on the website, iOS/WebKit, device settings, and media attributes.
- Pinch zoom and bounce are disabled; a viewport rule and document handlers suppress selection, context menus, and double-tap zoom. WKWebView and website scripts can vary across iOS versions, so this is best-effort rather than a guarantee against every system or page interaction. Ordinary scrolling remains available.
- Web-page taps and the native Retry button produce lightweight haptics on supported hardware. Drags do not intentionally trigger feedback.
- A loading indicator covers top-level loads. Network errors, HTTP error responses, blocked redirects, unsupported main-page MIME types, and WebKit process termination show a retry screen. Retry returns to the configured starting URL; saved cookies are retained.
- Main-frame, subframe, redirect-response, and new-window **navigations** must match the configured URL's scheme, hostname, and effective port. Same-origin new-window requests reuse the current view. Links to external websites, custom schemes, files, and other origins are not opened; cross-origin login pages and iframes therefore will not work. Explicit default ports are equivalent to omitted default ports.
- This is a navigation policy, **not a network firewall**: WebKit may fetch a redirect before the response is rejected, and it can make cross-origin subresource requests (such as scripts, images, XHR, and WebSockets) as allowed by the page and WebKit. Restrict server redirects and use server-side Content Security Policy or network controls if all external network traffic must be prevented. A website served from the allowed origin is trusted to run its own JavaScript.
- WKWebView does not open a system browser, and the wrapper intentionally provides no native navigation or download UI. A web app that relies on external authentication, popups with an opener, or downloads needs separate design work.

## Validation

The workflow compiles and runs the real `ServerOrigin.swift` policy tests on macOS before building. Portable helper tests can be run with `python3 Tests/test_embed_server_url.py` and `node Tests/test_web_behavior.js`. The Xcode project requires Xcode and an iOS SDK to compile; a Linux-only structural check is not an iOS build or device test.
