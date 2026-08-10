import Darwin
import Foundation
import Testing

@main
struct SwiftTestingBundleRunner {
    static func main() async {
        guard let bundlePath = ProcessInfo.processInfo.environment["CLEANMYSCREEN_TEST_BUNDLE"] else {
            fputs("CLEANMYSCREEN_TEST_BUNDLE is not set\n", stderr)
            exit(EXIT_FAILURE)
        }

        guard dlopen(bundlePath, RTLD_NOW | RTLD_GLOBAL) != nil else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            fputs("Could not load test bundle: \(message)\n", stderr)
            exit(EXIT_FAILURE)
        }

        await Testing.__swiftPMEntryPoint() as Never
    }
}
