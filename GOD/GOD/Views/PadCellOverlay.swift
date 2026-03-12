// GOD/GOD/Views/PadCellOverlay.swift
import SwiftUI

struct PadCellOverlay: ViewModifier {
    let isHot: Bool
    let isCold: Bool
    let isActive: Bool
    let triggered: Bool
    let hasPending: Bool
    let pendingMute: Bool?
    let breathe: Double
    let pendingBlink: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(hotGlowStroke, lineWidth: 1)
            )
            .shadow(color: hotGlowShadow, radius: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCold ? Theme.ice.opacity(0.05) : .clear)
            )
            .shadow(color: isCold ? Theme.ice.opacity(0.2) : .clear, radius: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(triggered ? Theme.orange.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(pendingStroke, lineWidth: 2)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(topBorderColor)
                    .frame(height: 2)
            }
    }

    private var hotGlowStroke: Color {
        guard isActive else { return .clear }
        let color = isHot ? Theme.orange : Theme.ice
        return color.opacity(0.3 + 0.2 * breathe)
    }

    private var hotGlowShadow: Color {
        guard isActive else { return .clear }
        let color = isHot ? Theme.orange : Theme.ice
        return color.opacity(0.3 + 0.15 * breathe)
    }

    private var pendingStroke: Color {
        guard hasPending else { return .clear }
        let color = pendingMute == true ? Theme.ice : Theme.orange
        return color.opacity(pendingBlink ? 0.8 : 0.2)
    }

    private var topBorderColor: Color {
        if hasPending {
            let color = pendingMute == true ? Theme.ice : Theme.orange
            return color.opacity(pendingBlink ? 0.9 : 0.3)
        }
        if isActive { return isHot ? Theme.orange : Theme.ice }
        if isCold { return Theme.ice.opacity(0.6) }
        return .clear
    }
}
