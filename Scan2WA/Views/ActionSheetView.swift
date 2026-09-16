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
        VStack(spacing: 20) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // Number header
            VStack(spacing: 6) {
                Text("Detected Phone Number")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Phone Number", text: $editableNumber)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(.phonePad)
                    .padding(.horizontal)
            }
            .padding(.top, 4)

            // Action Buttons
            VStack(spacing: 12) {
                // 1. WhatsApp Business Button
                Button(action: openWhatsAppBusiness) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("WA Business")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.4), radius: 8, x: 0, y: 4)
                }

                HStack(spacing: 12) {
                    // 2. Copy Button
                    Button(action: copyToClipboard) {
                        HStack(spacing: 8) {
                            Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16, weight: .semibold))
                            Text(showCopiedAlert ? "Copied!" : "Copy")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }

                    // 3. Call Button
                    Button(action: makePhoneCall) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Call")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Country prefix notice
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Default prefix: \(defaultCountryPrefix.isEmpty ? "None" : defaultCountryPrefix)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
        .cornerRadius(24, corners: [.topLeft, .topRight])
    }

    private func openWhatsAppBusiness() {
        let parser = PhoneNumberParser.shared
        let waNumber = parser.prepareForWhatsApp(
            cleanNumber: editableNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )

        // Try standard WhatsApp scheme or universal link (opens WA Business automatically)
        let deepLinkString = "whatsapp://send?phone=\(waNumber)"
        let webLinkString = "https://wa.me/\(waNumber)"

        if let deepURL = URL(string: deepLinkString), UIApplication.shared.canOpenURL(deepURL) {
            UIApplication.shared.open(deepURL, options: [:], completionHandler: nil)
        } else if let webURL = URL(string: webLinkString) {
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onDismiss()
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = editableNumber
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

// Extension to support specific corner rounding in SwiftUI
extension View {
    public func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

public struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
