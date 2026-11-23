import Foundation

func url(_ value: String) -> URL {
    guard let result = URL(string: value) else {
        fatalError("Invalid test fixture")
    }
    return result
}

func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    if !condition() {
        fatalError("Origin test failed: \(description)")
    }
}

let origin = ServerOrigin(url: url("https://game.example.invalid/play"))!
expect(origin.allows(url("https://game.example.invalid/other?level=1")), "same origin and different path")
expect(origin.allows(url("HTTPS://GAME.EXAMPLE.INVALID/")), "case-insensitive scheme and host")
expect(origin.allows(url("https://game.example.invalid:443/")), "explicit default TLS port")
expect(!origin.allows(url("http://game.example.invalid/")), "scheme change")
expect(!origin.allows(url("https://game.example.invalid:444/")), "different port")
expect(!origin.allows(url("https://sub.game.example.invalid/")), "subdomain")
expect(!origin.allows(url("https://game.example.invalid.attacker.invalid/")), "hostname suffix attack")
expect(!origin.allows(url("https://attacker.invalid/?game.example.invalid")), "hostname in query")
expect(!origin.allows(url("https://game.example.invalid@attacker.invalid/")), "userinfo spoofing")
expect(!origin.allows(url("https://user@game.example.invalid/")), "userinfo on otherwise matching host")
expect(!origin.allows(url("mailto:someone@example.invalid")), "external scheme")
expect(!origin.allows(url("javascript:alert(1)")), "javascript scheme")
expect(!origin.allows(url("about:blank")), "about scheme")
expect(!origin.allows(url("file:///private/document")), "file scheme")
expect(ServerOrigin(url: url("https://game.example.invalid:0/")) == nil, "invalid port zero")
// Some Foundation versions reject this URL before it reaches our origin parser.
if let outOfRangeURL = URL(string: "https://game.example.invalid:65536/") {
    expect(ServerOrigin(url: outOfRangeURL) == nil, "port out of range")
}
expect(ServerOrigin(url: url("https://user:pass@game.example.invalid/")) == nil, "embedded credentials")
let httpOrigin = ServerOrigin(url: url("http://game.example.invalid/"))!
expect(httpOrigin.allows(url("http://game.example.invalid:80/play")), "explicit default HTTP port")
let customPort = ServerOrigin(url: url("http://game.example.invalid:8080/"))!
expect(customPort.allows(url("http://game.example.invalid:8080/play")), "matching custom port")
expect(!customPort.allows(url("http://game.example.invalid/")), "custom port must match")
print("Origin policy tests passed.")
