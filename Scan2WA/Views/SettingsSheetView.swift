import SwiftUI

public struct SettingsSheetView: View {
    @Binding public var defaultCountryPrefix: String
    @Environment(\.dismiss) private var dismiss

    private let commonCountries = [
        ("Morocco", "+212"),
        ("United States / Canada", "+1"),
        ("United Kingdom", "+44"),
        ("France", "+33"),
        ("Spain", "+34"),
        ("Germany", "+49"),
        ("Saudi Arabia", "+966"),
        ("United Arab Emirates", "+971"),
        ("Egypt", "+20"),
        ("Algeria", "+213"),
        ("Tunisia", "+216"),
        ("Turkey", "+90"),
        ("India", "+91")
    ]

    public init(defaultCountryPrefix: Binding<String>) {
        self._defaultCountryPrefix = defaultCountryPrefix
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Prefix")) {
                    HStack {
                        Text("Default Country Code")
                        Spacer()
                        TextField("+XXX", text: $defaultCountryPrefix)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section(header: Text("Quick Select Country")) {
                    ForEach(commonCountries, id: \.1) { name, code in
                        Button(action: {
                            defaultCountryPrefix = code
                            dismiss()
                        }) {
                            HStack {
                                Text(name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(code)
                                    .foregroundColor(.secondary)
                                if defaultCountryPrefix == code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                Section(footer: Text("If a scanned number starts with local digits (e.g. 06...), this prefix will be automatically prepended so WhatsApp can start the chat directly.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Scanner Settings")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}
