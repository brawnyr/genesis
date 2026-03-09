import SwiftUI

struct TitleView: View {
    @State private var breathing = false

    var body: some View {
        Text("G   O   D")
            .font(Theme.monoTitle)
            .foregroundColor(Theme.text)
            .opacity(breathing ? 1.0 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}
