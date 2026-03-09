import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.102, green: 0.098, blue: 0.090)
                .ignoresSafeArea()
            Text("G O D")
                .font(.custom("JetBrains Mono", size: 24))
                .foregroundColor(Color(red: 0.831, green: 0.812, blue: 0.776))
        }
    }
}
