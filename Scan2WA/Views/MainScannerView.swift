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
    @State private var capturedImage: UIImage? = nil
    @State private var triggerManualCapture: (() -> Void)? = nil

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Viewport: Frozen still photo OR Live DataScanner camera feed
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else if isScannerAvailable {
                DataScannerView(
                    detectedNumbers: $detectedNumbers,
                    isScanning: $isScanning,
                    isTorchOn: $isTorchOn,
                    zoomFactor: $zoomFactor,
                    capturedImage: $capturedImage,
                    autoFreeze: autoFreeze,
                    triggerCapture: $triggerManualCapture,
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

            // Controls & Overlays
            VStack {
                // Top Navigation / Controls Bar
                HStack {
                    // Flashlight Button (active during live scan)
                    if capturedImage == nil {
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
                    } else {
                        // Spacer placeholder to balance layout
                        Color.clear.frame(width: 44, height: 44)
                    }

                    Spacer()

                    // Country Prefix Indicator & Settings
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

                    // Freeze / Scan Again Top Button
                    Button(action: {
                        if capturedImage != nil || !isScanning {
                            resetToLiveScan()
                        } else {
                            triggerManualCapture?()
                        }
                    }) {
                        Image(systemName: (capturedImage != nil || !isScanning) ? "arrow.clockwise" : "camera.metering.spot")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor((capturedImage != nil || !isScanning) ? .green : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                // Frozen Photo Badge
                if capturedImage != nil || !isScanning {
                    HStack(spacing: 8) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 12, weight: .bold))
                        Text("PHOTO FROZEN — SELECT A NUMBER BELOW")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.95))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.top, 6)
                }

                Spacer()

                // Center "Scan Another Label" Button when frozen
                if capturedImage != nil || !isScanning {
                    Button(action: resetToLiveScan) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                            Text("Scan Another Label")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    }
                    .padding(.bottom, 12)
                }

                // Bottom Controls & Detected Numbers Section
                VStack(spacing: 14) {
                    // Zoom Presets & Manual Shutter Button (only shown during live scan)
                    if capturedImage == nil {
                        HStack(spacing: 24) {
                            // Zoom Presets (1x, 2x, 3x)
                            HStack(spacing: 12) {
                                ForEach([1.0, 2.0, 3.0], id: \.self) { factor in
                                    Button(action: {
                                        zoomFactor = factor
                                    }) {
                                        Text("\(Int(factor))x")
                                            .font(.system(size: 13, weight: .bold))
                                            .frame(width: 38, height: 38)
                                            .background(zoomFactor == factor ? Color.yellow : Color.black.opacity(0.65))
                                            .foregroundColor(zoomFactor == factor ? .black : .white)
                                            .clipShape(Circle())
                                    }
                                }
                            }

                            // Manual Shutter Button: freeze whenever ready
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                triggerManualCapture?()
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3.5)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 48, height: 48)
                                }
                            }
                        }
                    }

                    // Multi-Number Cards: Displays ALL detected numbers for easy selection
                    if !detectedNumbers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("DETECTED NUMBERS (\(detectedNumbers.count)) — TAP TO SELECT")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                Spacer()
                            }
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
                    } else if capturedImage != nil {
                        Text("No phone numbers found. Tap 'Scan Another Label' to retry.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(10)
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

    private func resetToLiveScan() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            capturedImage = nil
            detectedNumbers = []
            isScanning = true
        }
    }
}
