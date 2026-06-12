import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.isProfileReady {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.locale, Locale(identifier: store.settings.language.localeIdentifier))
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.handleAppBecameActive()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            store.refreshSystemLanguageIfNeeded()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            JobFeedView()
                .tabItem {
                    Label(store.t("Jobs"), systemImage: "briefcase")
                }
                .tag(0)

            ProfileView()
                .tabItem {
                    Label(store.t("Profile"), systemImage: "person.crop.circle")
                }
                .tag(1)
        }
        .tint(.blue)
        .onAppear {
            if store.selectedTab > 1 {
                store.selectedTab = 0
            }
        }
    }
}
