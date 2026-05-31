import CountdownShared
import SwiftUI

struct SettingsView: View {
    @Environment(CountdownStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section("Notifications") {
                Toggle("Notify when countdowns finish", isOn: $store.settings.notificationsEnabled)
            }

            Section("Appearance") {
                Picker("Theme", selection: $store.settings.themePreference) {
                    ForEach(CountdownThemePreference.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }

                Picker("Countdown Precision", selection: $store.settings.displayPrecision) {
                    ForEach(CountdownDisplayPrecision.allCases) { precision in
                        Text(precision.title).tag(precision)
                    }
                }
            }

            Section("Quick Access") {
                Toggle("Show menu bar countdown", isOn: $store.settings.showsMenuBarExtra)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .onChange(of: store.settings) {
            store.updateSettings(store.settings)
        }
    }
}
