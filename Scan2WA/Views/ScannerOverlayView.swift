import SwiftUI

public struct ScannerOverlayView: View {
    public let numbers: [RecognizedNumber]
    public let onSelect: (RecognizedNumber) -> Void

    public init(numbers: [RecognizedNumber], onSelect: @escaping (RecognizedNumber) -> Void) {
        self.numbers = numbers
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(numbers) { item in
                    let rect = item.screenRect
                    if rect.width > 10 && rect.height > 5 {
                        let highlightWidth = max(rect.width + 10, 50)
                        let highlightHeight = max(rect.height + 4, 16)
                        let underlineHeight: CGFloat = 3.5
                        let spacing: CGFloat = 1.0

                        // Tap target button wrapping both the highlight and underline
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onSelect(item)
                        }) {
                            VStack(spacing: spacing) {
                                // 1. Subtle translucent highlight directly over the text digits
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.40), lineWidth: 1.5)
                                    )
                                    .frame(width: highlightWidth, height: highlightHeight)

                                // 2. Solid underline bar anchored directly beneath the digits
                                Capsule()
                                    .fill(Color(red: 0.15, green: 0.78, blue: 0.35))
                                    .frame(width: highlightWidth, height: underlineHeight)
                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        // Position so the highlight box is exactly centered on rect.midX and rect.midY
                        .position(
                            x: rect.midX,
                            y: rect.midY + (underlineHeight + spacing) / 2.0
                        )
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(true)
    }
}
