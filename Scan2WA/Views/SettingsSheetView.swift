import SwiftUI
import UIKit

public struct SettingsSheetView: View {
    @Binding public var defaultCountryPrefix: String
    @AppStorage("autoFreezeOnDetection") private var autoFreezeOnDetection: Bool = true
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
                Section(header: Text("Scanner Behavior")) {
                    Toggle(isOn: $autoFreezeOnDetection) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Freeze on Numbers Detected")
                                .font(.body)
                            Text("Freezes the photo as soon as phone numbers are found so you can comfortably select them.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Dual SIM Calling Setup")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default SIM for Calls")
                            .font(.headline)
                        Text("On iOS, the default calling line (Primary vs Secondary) is controlled by Apple in system settings. To make calls directly without being prompted each time:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Tap the button below to open Settings")
                            Text("2. Go to **Cellular** > **Default Voice Line**")
                            Text("3. Choose your preferred SIM line (Primary or Secondary)")
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)

                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Open iPhone Settings")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Current Country Prefix")) {
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
