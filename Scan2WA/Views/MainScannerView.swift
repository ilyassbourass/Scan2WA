import SwiftUI
import VisionKit

public struct MainScannerView: View {
    @AppStorage("defaultCountryPrefix") private var defaultCountryPrefix: String = "+212"

    @State private var detectedNumbers: [RecognizedNumber] = []
    @State private var selectedNumber: RecognizedNumber?
    @State private var isScanning: Bool = true
    @State private var isTorchOn: Bool = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var showSettings: Bool = false

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isScannerAvailable {
                // Apple's Native VisionKit Live Text Camera
                DataScannerView(
                    detectedNumbers: $detectedNumbers,
                    isScanning: $isScanning,
                    isTorchOn: $isTorchOn,
                    zoomFactor: $zoomFactor,
                    onSelectNumber: { number in
                        selectedNumber = number
                    }
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Live Text Scanner Unavailable")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Please grant camera permissions in iOS Settings.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Top Controls Bar
            VStack {
                HStack {
                    // Torch Button
                    Button(action: {
                        isTorchOn.toggle()
                    }) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isTorchOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Country Prefix Indicator
                    Button(action: {
                        showSettings = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                            Text(defaultCountryPrefix.isEmpty ? "+212" : defaultCountryPrefix)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Freeze / Resume Scanning Button
                    Button(action: {
                        isScanning.toggle()
                    }) {
                        Image(systemName: isScanning ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isScanning ? .white : .orange)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                if !isScanning {
                    Text("SCANNER PAUSED — TAP ANY NUMBER")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.95))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .padding(.top, 6)
                }

                Spacer()

                // Bottom Multi-Number Selection Carousel & Zoom Presets
                VStack(spacing: 14) {
                    // Zoom Presets
                    HStack(spacing: 16) {
                        ForEach([1.0, 2.0, 3.0], id: \.self) { factor in
                            Button(action: {
                                zoomFactor = factor
                            }) {
                                Text("\(Int(factor))x")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 42, height: 42)
                                    .background(zoomFactor == factor ? Color.yellow : Color.black.opacity(0.65))
                                    .foregroundColor(zoomFactor == factor ? .black : .white)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    // Multi-Number Cards: Display ALL detected numbers simultaneously
                    if !detectedNumbers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DETECTED NUMBERS (\(detectedNumbers.count)) — TAP TO OPEN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(detectedNumbers) { num in
                                        Button(action: {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            selectedNumber = num
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "phone.fill")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                                Text(num.cleanNumber)
                                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.white)
                                                Image(systemName: "arrow.up.right.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.black.opacity(0.85))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.8), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 36)
            }

            // Action Bottom Sheet
            if let number = selectedNumber {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedNumber = nil
                    }

                VStack {
                    Spacer()
                    ActionSheetView(
                        number: number,
                        defaultCountryPrefix: $defaultCountryPrefix,
                        onDismiss: {
                            selectedNumber = nil
                        }
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(defaultCountryPrefix: $defaultCountryPrefix)
        }
    }
}
