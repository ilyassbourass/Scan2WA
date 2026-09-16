import SwiftUI
import UIKit

public struct ActionSheetView: View {
    public let number: RecognizedNumber
    @Binding public var defaultCountryPrefix: String
    public let onDismiss: () -> Void

    @State private var editableNumber: String
    @State private var showCopiedAlert = false

    public init(
        number: RecognizedNumber,
        defaultCountryPrefix: Binding<String>,
        onDismiss: @escaping () -> Void
    ) {
        self.number = number
        self._defaultCountryPrefix = defaultCountryPrefix
        self.onDismiss = onDismiss
        self._editableNumber = State(initialValue: number.cleanNumber)
    }

    public var body: some View {
        VStack(spacing: 18) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // Header
            VStack(spacing: 4) {
                Text("Detected Phone Number")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Phone Number", text: $editableNumber)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.phonePad)
                    .padding(.horizontal)
            }

            // Action Buttons
            VStack(spacing: 10) {
                // 1. WhatsApp Business (Direct Deep Link)
                Button(action: openWhatsAppBusiness) {
                    HStack(spacing: 12) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("WA Business")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.4), radius: 6, x: 0, y: 3)
                }

                // 2. Personal WhatsApp Button (Optional alternative)
                Button(action: openPersonalWhatsApp) {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("WhatsApp (Personal)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                HStack(spacing: 10) {
                    // 3. Copy Button
                    Button(action: copyToClipboard) {
                        HStack(spacing: 8) {
                            Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 15, weight: .semibold))
                            Text(showCopiedAlert ? "Copied!" : "Copy")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }

                    // 4. Call Button
                    Button(action: makePhoneCall) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Call")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Country prefix indication
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                let resolved = PhoneNumberParser.shared.prepareForWhatsApp(cleanNumber: editableNumber, defaultCountryPrefix: defaultCountryPrefix)
                Text("Chat ID: +\(resolved)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 14)
        }
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
        .cornerRadius(24, corners: [.topLeft, .topRight])
    }

    /// Opens WhatsApp Business directly without going through regular WhatsApp
    private func openWhatsAppBusiness() {
        let parser = PhoneNumberParser.shared
        let waNumber = parser.prepareForWhatsApp(
            cleanNumber: editableNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )

        let smbUrlString = "whatsapp-smb://send?phone=\(waNumber)"
        let businessUrlString = "whatsapp-business://send?phone=\(waNumber)"
        let webUrlString = "https://wa.me/\(waNumber)"

        // Priority 1: Direct WhatsApp Business custom URL scheme
        if let smbUrl = URL(string: smbUrlString), UIApplication.shared.canOpenURL(smbUrl) {
            UIApplication.shared.open(smbUrl, options: [:], completionHandler: nil)
        } else if let bizUrl = URL(string: businessUrlString), UIApplication.shared.canOpenURL(bizUrl) {
            UIApplication.shared.open(bizUrl, options: [:], completionHandler: nil)
        } else if let smbUrl = URL(string: smbUrlString) {
            // Attempt to open even if canOpenURL was not pre-queried
            UIApplication.shared.open(smbUrl, options: [:]) { success in
                if !success, let webUrl = URL(string: webUrlString) {
                    UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                }
            }
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onDismiss()
    }

    /// Opens personal WhatsApp
    private func openPersonalWhatsApp() {
        let parser = PhoneNumberParser.shared
        let waNumber = parser.prepareForWhatsApp(
            cleanNumber: editableNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )

        let consumerUrlString = "whatsapp-consumer://send?phone=\(waNumber)"
        let standardUrlString = "whatsapp://send?phone=\(waNumber)"

        if let consumerUrl = URL(string: consumerUrlString), UIApplication.shared.canOpenURL(consumerUrl) {
            UIApplication.shared.open(consumerUrl, options: [:], completionHandler: nil)
        } else if let stdUrl = URL(string: standardUrlString) {
            UIApplication.shared.open(stdUrl, options: [:], completionHandler: nil)
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onDismiss()
    }

    private func copyToClipboard() {
        let parser = PhoneNumberParser.shared
        let waNumber = parser.prepareForWhatsApp(
            cleanNumber: editableNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )
        UIPasteboard.general.string = "+\(waNumber)"

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedAlert = false
            }
        }
    }

    private func makePhoneCall() {
        let parser = PhoneNumberParser.shared
        let callNumber = parser.prepareForCall(
            cleanNumber: editableNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )
        if let callURL = URL(string: "tel://\(callNumber)") {
            UIApplication.shared.open(callURL, options: [:], completionHandler: nil)
        }
        onDismiss()
    }
}
