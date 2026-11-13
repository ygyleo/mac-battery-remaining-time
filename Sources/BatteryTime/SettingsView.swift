import BatteryCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Picker(preferences.text.languageLabel, selection: $preferences.language) {
                Text("中文").tag(AppLanguage.chinese)
                Text("English").tag(AppLanguage.english)
            }
            .pickerStyle(.menu)

            Toggle(preferences.text.showTimeInMenuBarLabel, isOn: $preferences.showTimeInMenuBar)

            Toggle(preferences.text.launchAtLoginLabel, isOn: Binding(
                get: { preferences.loginEnabled },
                set: { preferences.setLoginEnabled($0) }
            ))
            if preferences.needsApproval {
                Button(preferences.text.loginApprovalMessage) {
                    SMAppService.openSystemSettingsLoginItems()
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding(4)
        .frame(width: 360, height: preferences.needsApproval ? 232 : 188)
        .fixedSize()
        .environment(\.locale, Locale(identifier: preferences.language.rawValue))
        .alert(preferences.text.loginErrorTitle, isPresented: Binding(
            get: { preferences.loginError != nil },
            set: { if !$0 { preferences.loginError = nil } }
        )) {
            Button(preferences.language == .chinese ? "好" : "OK") { preferences.loginError = nil }
        } message: {
            Text(preferences.loginError ?? "")
        }
    }
}
