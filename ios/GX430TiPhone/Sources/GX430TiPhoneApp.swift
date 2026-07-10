import SwiftUI
import GX430TKit

@main
struct GX430TiPhoneApp: App {
    @StateObject private var model = GX430TiPhoneModel()

    var body: some Scene {
        WindowGroup {
            GX430TiPhoneRootView()
                .environmentObject(model)
        }
    }
}
