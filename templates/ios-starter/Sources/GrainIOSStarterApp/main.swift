import SwiftUI
import GrainIOSStarterCore

@main
struct GrainIOSStarterApp: App {
    var body: some Scene {
        WindowGroup {
            StarterScannerView(session: StarterScannerSession())
        }
    }
}
