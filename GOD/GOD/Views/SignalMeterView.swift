import SwiftUI

struct SignalMeterView: View {
    let level: Float
    private let segments = 8

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                let threshold = Float(i) / Float(segments)
                RoundedRectangle(cornerRadius: 1)
                    .fill(level > threshold ? Theme.blue : Theme.subtle)
                    .frame(width: 6, height: 10)
            }
        }
    }
}
