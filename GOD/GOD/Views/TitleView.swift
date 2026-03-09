import SwiftUI

struct TitleView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Text("G O D")
            .font(Theme.monoTitle)
            .foregroundColor(Theme.text)
            .opacity(0.8 + 0.2 * Darwin.sin(Double(phase)))
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    phase = .pi * 2
                }
            }
    }
}
