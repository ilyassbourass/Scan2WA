import SwiftUI
import AVFoundation

public struct MainScannerView: View {
    @StateObject private var cameraManager = CameraManager()
    @ObservedObject private var packageManager = PackageManager.shared
    @AppStorage("defaultCountryPrefix") private var defaultCountryPrefix: String = "+212"
    @AppStorage("autoFreezeOnDetection") private var autoFreeze: Bool = true

    @State private var selectedNumber: RecognizedNumber?
    @State private var showSettings: Bool = false
    @State private var showPackagesList: Bool = false
    @State private var packageNumberToCapture: String? = nil
    @State private var showPackageCapture: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !cameraManager.hasCameraPermission {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Camera Access Required")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Please grant camera permissions in iOS Settings.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                // Viewport: Camera Preview always mounted underneath
                CameraPreviewView(session: cameraManager.captureSession) { layer in
                    cameraManager.previewLayer = layer
                }
                .ignoresSafeArea()

                // Frozen photo overlay (when frozen)
                if let image = cameraManager.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                }

                // On-screen bounding box & underline overlays
                ScannerOverlayView(numbers: cameraManager.detectedNumbers) { num in
                    selectedNumber = num
                }
                .ignoresSafeArea()

                // Top Controls & Indicators Bar
                VStack {
                    HStack {
                        // Torch Button (only active during live scan)
                        if cameraManager.capturedImage == nil {
                            Button(action: {
                                cameraManager.toggleTorch()
                            }) {
                                Image(systemName: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(cameraManager.isTorchOn ? .yellow : .white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        } else {
                            Color.clear.frame(width: 44, height: 44)
                        }

                        Spacer()

                        // Packages Inventory Button
                        Button(action: {
                            showPackagesList = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))

                                Text("Packages")
                                    .font(.system(size: 13, weight: .bold))

                                if packageManager.packages.count > 0 {
                                    Text("\(packageManager.packages.count)")
                                        .font(.system(size: 11, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                                        .foregroundColor(.black)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.65))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }

                        Spacer()

                        // Country Code Prefix & Settings Button
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

                        // Right Top Button: "Scan Again" when frozen, or Manual Freeze when live
                        Button(action: {
                            if cameraManager.capturedImage != nil {
                                cameraManager.resetScan()
                            } else {
                                cameraManager.triggerManualFreeze()
                            }
                        }) {
                            Image(systemName: cameraManager.capturedImage != nil ? "arrow.clockwise" : "camera.metering.spot")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(cameraManager.capturedImage != nil ? .green : .white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)

                    // Frozen Photo Status Badge
                    if cameraManager.capturedImage != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 12, weight: .bold))
                            Text("PHOTO FROZEN — TAP A NUMBER OR SCAN AGAIN")
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

                    // Center Floating "Scan Again" Button (Prominently displayed when frozen)
                    if cameraManager.capturedImage != nil {
                        Button(action: {
                            cameraManager.resetScan()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Scan Again")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                        }
                        .padding(.bottom, 14)
                    }

                    // Bottom Section: Zoom Presets, Shutter & Multi-Number Cards
                    VStack(spacing: 14) {
                        // Live Scanning Controls: Zoom Presets & Silent Shutter
                        if cameraManager.capturedImage == nil {
                            HStack(spacing: 24) {
                                // Zoom Presets (0.5x Macro, 1x, 2x, 5x)
                                HStack(spacing: 10) {
                                    ForEach(CameraManager.ZoomPreset.allCases) { preset in
                                        Button(action: {
                                            cameraManager.setZoomPreset(preset)
                                        }) {
                                            Text(preset.rawValue)
                                                .font(.system(size: 12, weight: .bold))
                                                .frame(width: 40, height: 40)
                                                .background(cameraManager.currentZoomPreset == preset ? Color.yellow : Color.black.opacity(0.65))
                                                .foregroundColor(cameraManager.currentZoomPreset == preset ? .black : .white)
                                                .clipShape(Circle())
                                        }
                                    }
                                }

                                // Manual Silent Shutter Button
                                Button(action: {
                                    cameraManager.triggerManualFreeze()
                                }) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3.5)
                                            .frame(width: 58, height: 58)
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 46, height: 46)
                                    }
                                }
                            }
                        }

                        // Multi-Number Cards: Displays ALL detected numbers simultaneously
                        if !cameraManager.detectedNumbers.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("DETECTED NUMBERS (\(cameraManager.detectedNumbers.count)) — TAP TO SELECT")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(cameraManager.detectedNumbers) { num in
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
                        } else if cameraManager.capturedImage != nil {
                            Text("No phone numbers found. Tap 'Scan Again' to retry.")
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
                        },
                        onSavePackage: { cleanNum in
                            selectedNumber = nil
                            packageNumberToCapture = cleanNum
                            showPackageCapture = true
                        }
                    )
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            cameraManager.autoFreeze = autoFreeze
        }
        .onChange(of: autoFreeze) { newValue in
            cameraManager.autoFreeze = newValue
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(defaultCountryPrefix: $defaultCountryPrefix)
        }
        .sheet(isPresented: $showPackagesList) {
            PackagesListView()
        }
        .fullScreenCover(isPresented: $showPackageCapture) {
            if let num = packageNumberToCapture {
                PackagePhotoCaptureView(
                    phoneNumber: num,
                    cleanNumber: num,
                    onDismiss: {
                        showPackageCapture = false
                        packageNumberToCapture = nil
                    }
                )
            }
        }
    }
}
