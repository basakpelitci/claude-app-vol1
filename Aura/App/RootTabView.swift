import SwiftUI

/// Five-tab shell. Onboarding replaces the tabs until a profile exists;
/// milestone celebrations overlay everything.
public struct RootTabView: View {
    private let deps: AppDependencies
    @State private var onboardingComplete = false
    @State private var checkedProfile = false

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public var body: some View {
        ZStack {
            if !checkedProfile {
                ProgressView()
            } else if onboardingComplete {
                tabs
            } else {
                OnboardingView(deps: deps) {
                    withAnimation(AuraMotion.gentle) { onboardingComplete = true }
                }
            }

            if let milestone = deps.coordinator.pendingCelebrations.first {
                CelebrationOverlay(title: milestone.title, message: milestone.detail) {
                    deps.coordinator.dismissCelebration()
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(\.dependencies, deps)
        .task {
            // try? on an optional-returning call double-wraps; flatten first.
            let profile = (try? await deps.store.currentProfile()) ?? nil
            onboardingComplete = profile != nil
            checkedProfile = true
        }
    }

    private var tabs: some View {
        TabView {
            TodayView(deps: deps)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            NutritionView(deps: deps)
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }
            BodyView(deps: deps)
                .tabItem { Label("Body", systemImage: "chart.xyaxis.line") }
            WardrobeView(deps: deps)
                .tabItem { Label("Wardrobe", systemImage: "hanger") }
            MeView(deps: deps)
                .tabItem { Label("Me", systemImage: "person.fill") }
        }
        .tint(AuraColor.accent)
    }
}
