import SwiftUI
import AppKit

@main
struct PATools_Data_UpdaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: AppViewModel

    init() {
        let viewModel = AppViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        appDelegate.viewModel = viewModel
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: AppViewModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let viewModel, viewModel.hasUnsavedChanges else {
            return .terminateNow
        }
        viewModel.presentUnsavedChangesAlert()
        return .terminateCancel
    }
}
