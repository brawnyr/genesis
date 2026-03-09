import SwiftUI

struct CommandInputView: View {
    @ObservedObject var engine: GodEngine
    @State private var command = ""

    var body: some View {
        HStack(spacing: 4) {
            Text(">")
                .foregroundColor(Theme.dim)
            TextField("", text: $command)
                .textFieldStyle(.plain)
                .foregroundColor(Theme.text)
                .font(Theme.mono)
                .onSubmit {
                    engine.executeCommand(command)
                    command = ""
                }
        }
        .font(Theme.mono)
    }
}
