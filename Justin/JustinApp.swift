import SwiftUI

@main
struct JustinApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // TODO: remove or gate behind DEBUG before shipping
                    await SupabaseManager.testConnection()
                }
        }
    }
}
