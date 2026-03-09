import SwiftUI

struct CommandInputView: View {
    @ObservedObject var engine: GodEngine
    @Binding var isVisible: Bool
    @State private var command = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 4) {
                Text(">")
                    .foregroundColor(Theme.blue)
                TextField("", text: $command)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.text)
                    .focused($isFocused)
                    .onSubmit {
                        engine.executeCommand(command)
                        command = ""
                        isVisible = false
                    }
                    .onKeyPress(.escape) {
                        command = ""
                        isVisible = false
                        return .handled
                    }
            }
            .font(Theme.mono)
            .onAppear { isFocused = true }
            .onChange(of: isVisible) { _, newValue in
                if newValue { isFocused = true }
            }
        }
    }
}
