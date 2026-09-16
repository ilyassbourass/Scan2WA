import SwiftUI

public struct ScannerOverlayView: View {
    public let numbers: [RecognizedNumber]
    public let onSelect: (RecognizedNumber) -> Void

    public init(numbers: [RecognizedNumber], onSelect: @escaping (RecognizedNumber) -> Void) {
        self.numbers = numbers
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            ForEach(numbers) { item in
                let rect = item.screenRect
                if rect.width > 10 && rect.height > 5 {
                    // Tap target button wrapping both the highlight and underline
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onSelect(item)
                    }) {
                        VStack(spacing: 0) {
                            // 1. Subtle translucent highlight directly over the text digits
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.35), lineWidth: 1)
                                )
                                .frame(width: max(rect.width + 8, 50), height: max(rect.height + 4, 16))

                            // 2. Solid underline bar anchored directly beneath the digits
                            Capsule()
                                .fill(Color(red: 0.15, green: 0.78, blue: 0.35))
                                .frame(width: max(rect.width + 8, 50), height: 3.5)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .padding(.top, 1)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .position(x: rect.midX, y: rect.midY + 2)
                }
            }
        }
        .allowsHitTesting(true)
    }
}
