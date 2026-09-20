import Foundation

#if os(macOS)
import AppKit
#endif

let options = ArgumentParser.parse(CommandLine.arguments)
let runtime = BridgeRuntime(options: options)

enum ProcessTraps {
    static var sources: [AnyObject] = []
}

func installTerminationTraps() {
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    for unixSignal in [SIGINT, SIGTERM] {
        let source = DispatchSource.makeSignalSource(signal: unixSignal, queue: .main)
        source.setEventHandler {
            runtime.stop()
            #if os(macOS)
            NSApplication.shared.terminate(nil)
            #else
            exit(0)
            #endif
        }
        source.resume()
        ProcessTraps.sources.append(source)
    }
}

installTerminationTraps()

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        runtime.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
#else
runtime.start()
RunLoop.main.run()
#endif
