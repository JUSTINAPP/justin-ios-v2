import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        // Inactive icons: confident dark ink, not pale grey
        UITabBar.appearance().unselectedItemTintColor = UIColor(
            red: 0x2e / 255.0, green: 0x25 / 255.0, blue: 0x40 / 255.0, alpha: 1
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { ShelfView(switchToGiving: { selectedTab = 2 }) }
                .tabItem { Label("Shelf", systemImage: "folder") }
                .tag(0)

            NavigationStack { PeopleView() }
                .tabItem { Label("People", systemImage: "person.2") }
                .tag(1)

            NavigationStack { GivingView() }
                .tabItem { Label("Giving", systemImage: "heart") }
                .tag(2)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(3)
        }
        .tint(.brandPurple) // active tab icon + label
    }
}

#Preview {
    MainTabView()
}
