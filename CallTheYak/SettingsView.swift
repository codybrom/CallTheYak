import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager = YakManager.shared

    private let presets: [(String, Double)] = [
        ("5 minutes", 5),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bruce Appearance Interval")
                .font(.headline)

            Picker("Appear every:", selection: $manager.appearanceIntervalMinutes) {
                ForEach(presets, id: \.1) { name, value in
                    Text(name).tag(value)
                }
            }
            .pickerStyle(.radioGroup)

            HStack {
                Text("Custom (minutes):")
                TextField("", value: $manager.appearanceIntervalMinutes, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Bruce will appear randomly within ±25% of this interval.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Call the Yak v1.0 by Cody Bromley (https://github.com/codybrom)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Bruce the Wonder Yak was created by the Final Cut Pro team at Apple.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(width: 350)
    }
}
