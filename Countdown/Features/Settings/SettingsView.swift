import CountdownShared
import SwiftUI

struct SettingsView: View {
    @Environment(CountdownStore.self) private var store

    var body: some View {
        let settings = Binding(
            get: { store.settings },
            set: { value in Task { await store.updateSettings(value) } }
        )

        Form {
            Section("Notifications") {
                Toggle("Notify when countdowns finish", isOn: settings.notificationsEnabled)
                    .accessibilityLabel("Notify when countdowns finish")
            }

            Section("Appearance") {
                Picker("Theme", selection: settings.themePreference) {
                    ForEach(CountdownThemePreference.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .accessibilityLabel("Theme")

                Picker("Countdown Precision", selection: settings.displayPrecision) {
                    ForEach(CountdownDisplayPrecision.allCases) { precision in
                        Text(precision.title).tag(precision)
                    }
                }
                .accessibilityLabel("Countdown precision")
            }

        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}
