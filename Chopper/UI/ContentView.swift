import SwiftUI

struct ContentView: View {
    @State private var state = AppState()

    var body: some View {
        VSplitView {
            RequestPane(state: state)
                .frame(minHeight: 120)
            ResponsePane(state: state)
                .frame(minHeight: 200)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
