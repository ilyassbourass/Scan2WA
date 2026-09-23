import SwiftUI

public struct ZoomablePhotoPreviewModal: View {
    public let image: UIImage
    public let title: String?
    public let onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    public init(image: UIImage, title: String? = nil, onClose: @escaping () -> Void) {
        self.image = image
        self.title = title
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = max(1.0, min(scale * delta, 6.0))
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale <= 1.0 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            scale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            } else {
                                                if value.translation.height > 0 {
                                                    offset = CGSize(width: 0, height: value.translation.height)
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            if scale > 1.0 {
                                                let maxOffsetX = max(0, (size.width * (scale - 1)) / 2)
                                                let maxOffsetY = max(0, (size.height * (scale - 1)) / 2)

                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    offset.width = min(maxOffsetX, max(-maxOffsetX, offset.width))
                                                    offset.height = min(maxOffsetY, max(-maxOffsetY, offset.height))
                                                    lastOffset = offset
                                                }
                                            } else {
                                                if value.translation.height > 100 {
                                                    onClose()
                                                } else {
                                                    withAnimation(.spring()) {
                                                        offset = .zero
                                                        lastOffset = .zero
                                                    }
                                                }
                                            }
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if scale > 1.2 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 3.0
                                }
                            }
                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                            haptic.impactOccurred()
                        }
                }
                .frame(width: size.width, height: size.height)
            }

            // Top Bar Controls
            VStack {
                HStack(spacing: 12) {
                    if let title = title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(12)
                    }

                    Spacer()

                    // Zoom indicator / Reset pill
                    if scale > 1.05 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11, weight: .bold))
                                Text(String(format: "%.1fx", scale))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                            .foregroundColor(.black)
                            .cornerRadius(14)
                        }
                    }

                    // Close Button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Bottom Hint
                if scale <= 1.05 {
                    Text("Pinch to zoom • Double-tap to magnify • Drag down to close")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.bottom, 24)
                }
            }
        }
    }
}
