import SwiftUI

struct TopBuddyRootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.onboardingComplete {
                DashboardView()
            } else {
                SetupExperienceView()
            }
        }
        .environmentObject(model.schedule)
    }
}
