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
            ZStack {
                // Subtle scanning target frame in center
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [8, 8]))
                    .frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.45)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)

                // Render dynamic clickable pill badges over detected phone numbers
                ForEach(numbers) { item in
                    let rect = convertVisionRect(item.boundingBox, in: geometry.size)
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onSelect(item)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(item.rawText)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.92))
                                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(.white)
                    }
                    .position(x: rect.midX, y: max(rect.midY, 50))
                    .animation(.easeInOut(duration: 0.2), value: numbers)
                }
            }
        }
    }

    /// Convert Vision bottom-left origin normalized coordinates to view coordinates
    private func convertVisionRect(_ box: CGRect, in size: CGSize) -> CGRect {
        let x = box.origin.x * size.width
        let y = (1.0 - box.origin.y - box.height) * size.height
        let width = max(box.width * size.width, 100)
        let height = max(box.height * size.height, 32)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
