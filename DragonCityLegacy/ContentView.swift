import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = WebViewModel()

    var body: some View {
        ZStack {
            Color.black
            WebContentView(webView: model.webView)

            switch model.state {
            case .loading:
                statusPanel {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Loading Dragon City Legacy…")
                        .font(.headline)
                }
            case .ready:
                EmptyView()
            case .failed:
                statusPanel {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36, weight: .medium))
                    Text("Unable to load the game")
                        .font(.title3.bold())
                    Text("Check your connection and try again.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    Button("Retry") { model.retry() }
                        .buttonStyle(RetryButtonStyle())
                        .padding(.top, 4)
                }
            case .configurationError:
                statusPanel {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36, weight: .medium))
                    Text("App not configured")
                        .font(.title3.bold())
                    Text("This build needs a valid server configuration.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear { model.startIfNeeded() }
    }

    private func statusPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color(red: 0.025, green: 0.055, blue: 0.075)
            VStack(spacing: 12, content: content)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(24)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(.white, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct WebContentView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
