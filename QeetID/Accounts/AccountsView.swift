import Qeetrix
import SwiftUI

/// The home screen: the large title, search, and each account's code.
struct AccountsView: View {
    @State private var query = ""

    var body: some View {
        List {
            Section {
                QeetrixEmptyState(
                    "No accounts yet", description: "Turn on 2-step verification on a website or app. It shows a QR code; scan it here.",
                    icon: .keyRound, size: .section
                )
                .listRowBackground(Color.clear)
            }
        }
        .qeetrixListStyle()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Route.settings) {
                    Label {
                        Text("Settings")
                    } icon: {
                        Image(qeetrix: .settings, shape: .sharp)
                    }
                }
            }
        }
    }
}
