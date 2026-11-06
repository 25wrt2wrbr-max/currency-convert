import AppKit
import SwiftUI

@main
struct CurrencyConverterApp: App {
    init() {
        if CommandLine.arguments.contains("--self-test") {
            let box = SelfTestResult()
            let runner = DispatchSemaphore(value: 0)
            Task.detached {
                do {
                    try await SelfTest.run()
                } catch {
                    fputs("SELFTEST_FAIL \(error.localizedDescription)\n", stderr)
                    box.failed = true
                }
                runner.signal()
            }
            runner.wait()
            exit(box.failed ? 1 : 0)
        }
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 840, minHeight: 640)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = "Currency Converter"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1)
            window.minSize = NSSize(width: 840, height: 640)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
