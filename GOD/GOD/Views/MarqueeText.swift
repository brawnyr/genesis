// GOD/GOD/Views/MarqueeText.swift
import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let shadow: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var overflows: Bool { textWidth > containerWidth && containerWidth > 0 }
    private let gap: CGFloat = 40
    private let speed: CGFloat = 30.0 // points per second

    var body: some View {
        GeometryReader { geo in
            let _ = updateContainerWidth(geo.size.width)
            if overflows {
                // TimelineView drives continuous smooth scrolling with no pop on loop
                TimelineView(.animation) { timeline in
                    let cycleWidth = textWidth + gap
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let rawOffset = elapsed * speed
                    let scrollOffset = -(rawOffset.truncatingRemainder(dividingBy: cycleWidth))

                    HStack(spacing: gap) {
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .shadow(color: shadow, radius: 6)
                            .fixedSize()
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .shadow(color: shadow, radius: 6)
                            .fixedSize()
                    }
                    .offset(x: scrollOffset)
                }
            } else {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .shadow(color: shadow, radius: 6)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .clipped()
        .background(
            Text(text)
                .font(font)
                .fixedSize()
                .background(GeometryReader { geo in
                    Color.clear.onAppear { textWidth = geo.size.width }
                        .onChange(of: text) { _, _ in textWidth = geo.size.width }
                })
                .hidden()
        )
        .frame(height: 18)
    }

    private func updateContainerWidth(_ width: CGFloat) {
        if containerWidth != width {
            DispatchQueue.main.async { containerWidth = width }
        }
    }
}
