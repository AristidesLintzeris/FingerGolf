import SwiftUI

struct SettingsView: View {

    @ObservedObject var settings: GameSettings
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SETTINGS")
                    .headingStyle(size: 24)

                Spacer()

                Button("DONE", action: onDone)
                    .bodyStyle(size: 16)
            }
            .padding(20)

            ScrollView {
                VStack(spacing: 24) {
                    settingsSection("GAMEPLAY") {
                        // Power preset picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HIT POWER")
                                .bodyStyle(size: 12)
                            Picker("Power", selection: $settings.powerPreset) {
                                ForEach(PowerPreset.allCases, id: \.self) { preset in
                                    Text(preset.label).tag(preset)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Toggle(isOn: Binding(
                            get: { settings.barrierMode == .barrier },
                            set: { settings.barrierMode = $0 ? .barrier : .none }
                        )) {
                            Text("COURSE BARRIERS")
                                .bodyStyle(size: 13)
                        }
                        .tint(.green)
                    }

                    Button(action: { settings.resetToDefaults() }) {
                        Text("RESET TO DEFAULTS")
                            .bodyStyle(size: 14)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .onDisappear { settings.save() }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .lightStyle(size: 11)
                .tracking(1)
            content()
        }
    }
}
