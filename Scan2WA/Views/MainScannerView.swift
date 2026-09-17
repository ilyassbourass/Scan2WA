import SwiftUI
import VisionKit

public struct MainScannerView: View {
    @AppStorage("defaultCountryPrefix") private var defaultCountryPrefix: String = "+212"
    @AppStorage("autoFreezeOnDetection") private var autoFreeze: Bool = true

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
                    autoFreeze: autoFreeze,
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

                    // Freeze / Scan Again Button
                    Button(action: {
                        if !isScanning {
                            // Resume / Scan Again
                            detectedNumbers = []
                            isScanning = true
                        } else {
                            // Pause
                            isScanning = false
                        }
                    }) {
                        Image(systemName: isScanning ? "pause.fill" : "arrow.clockwise")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isScanning ? .white : .green)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                if !isScanning {
                    HStack(spacing: 8) {
                        Image(systemName: "snowflake")
                            .font(.caption.bold())
                        Text("PHOTO FROZEN — TAP A NUMBER OR SCAN AGAIN")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.95))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.top, 6)
                }

                Spacer()

                // Center "Scan Again" button when frozen
                if !isScanning {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        detectedNumbers = []
                        isScanning = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                            Text("Scan Again")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        )
                        .shadow(radius: 6)
                    }
                    .padding(.bottom, 8)
                }

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
                            Text("DETECTED NUMBERS (\(detectedNumbers.count)) — TAP TO SELECT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
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
                                                    .stroke(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.85), lineWidth: 1.5)
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
