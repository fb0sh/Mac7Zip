import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarLocation?

    var body: some View {
        List(SidebarLocation.allCases, selection: $selection) { location in
            Label(location.title, systemImage: location.systemImage)
                .tag(location)
        }
        .listStyle(.sidebar)
        .navigationTitle("Mac7Zip")
        .frame(minWidth: 180)
    }
}
