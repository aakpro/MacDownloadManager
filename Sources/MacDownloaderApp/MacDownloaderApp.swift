import SwiftUI
import MacDownloaderCore

@main
struct MacDownloaderApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("MacDownloader")
                    .font(.largeTitle)
                Text("Native macOS Download Manager")
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}
