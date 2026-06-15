import SwiftUI

struct MainTabView: View {

    init() {
        // Inactive icons: confident dark ink, not pale grey
        UITabBar.appearance().unselectedItemTintColor = UIColor(
            red: 0x2e / 255.0, green: 0x25 / 255.0, blue: 0x40 / 255.0, alpha: 1
        )
    }

    var body: some View {
        TabView {
            NavigationStack { ShelfView() }
                .tabItem { Label("Shelf", systemImage: "folder") }

            NavigationStack { PeopleView() }
                .tabItem { Label("People", systemImage: "person.2") }

            NavigationStack { GivingView() }
                .tabItem { Label("Giving", systemImage: "heart") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .tint(.brandPurple) // active tab icon + label
    }
}

#Preview {
    MainTabView()
}
