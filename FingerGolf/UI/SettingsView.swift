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
                            Text("FLICK POWER")
                                .bodyStyle(size: 12)
                            Picker("Power", selection: $settings.powerPreset) {
                                ForEach(PowerPreset.allCases, id: \.self) { preset in
                                    Text(preset.label).tag(preset)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        sliderRow("MAX SWING POWER", value: $settings.maxSwingPower, range: 5...25)

                        Toggle(isOn: Binding(
                            get: { settings.barrierMode == .barrier },
                            set: { settings.barrierMode = $0 ? .barrier : .none }
                        )) {
                            Text("COURSE BARRIERS")
                                .bodyStyle(size: 13)
                        }
                        .tint(.green)
                    }

                    settingsSection("HAND TRACKING") {
                        sliderRow("PINCH THRESHOLD", value: $settings.pinchThreshold, range: 0.03...0.15)
                        sliderRow("FLICK MIN VELOCITY", value: $settings.flickMinVelocity, range: 0.05...0.5)
                        sliderRow("SMOOTHING FACTOR", value: $settings.smoothingFactor, range: 0.1...0.9)
                        sliderRow("JUMP THRESHOLD", value: $settings.jumpThreshold, range: 0.05...0.3)
                    }

                    settingsSection("KALMAN FILTER") {
                        sliderRowDouble("PROCESS NOISE (Q)", value: $settings.kalmanProcessNoise, range: 0.001...0.1)
                        sliderRowDouble("MEASUREMENT NOISE (R)", value: $settings.kalmanMeasurementNoise, range: 0.01...0.5)
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

    private func sliderRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .bodyStyle(size: 12)
                Spacer()
                Text(String(format: "%.3f", value.wrappedValue))
                    .lightStyle(size: 11)
            }
            Slider(value: value, in: range)
                .tint(.green)
        }
    }

    private func sliderRowDouble(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .bodyStyle(size: 12)
                Spacer()
                Text(String(format: "%.4f", value.wrappedValue))
                    .lightStyle(size: 11)
            }
            Slider(value: value, in: range)
                .tint(.green)
        }
    }
}
