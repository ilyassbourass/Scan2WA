import SwiftUI

public struct MainScannerView: View {
    @StateObject private var cameraManager = CameraManager()
    @AppStorage("defaultCountryPrefix") private var defaultCountryPrefix: String = "+1"

    @State private var selectedNumber: RecognizedNumber?
    @State private var showSettings = false
    @State private var showHistorySheet = false

    public init() {}

    public var body: some View {
        ZStack {
            // Camera Background
            Color.black.ignoresSafeArea()

            if cameraManager.hasCameraPermission {
                CameraPreviewView(session: cameraManager.captureSession)
                    .ignoresSafeArea()

                // Interactive Number Overlay on live camera
                ScannerOverlayView(numbers: cameraManager.detectedNumbers) { number in
                    selectedNumber = number
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Camera Access Required")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Please enable camera access in Settings to scan phone numbers.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Top Bar Overlay
            VStack {
                HStack {
                    // Torch Button
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

                    Spacer()

                    // Country Prefix Badge / Settings
                    Button(action: {
                        showSettings = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                            Text(defaultCountryPrefix.isEmpty ? "Prefix" : defaultCountryPrefix)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Pause / Freeze Frame Button
                    Button(action: {
                        cameraManager.togglePause()
                    }) {
                        Image(systemName: cameraManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(cameraManager.isPaused ? .orange : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                if cameraManager.isPaused {
                    Text("FRAME FROZEN — TAP NUMBER TO ACT")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.9))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .padding(.top, 4)
                }

                Spacer()

                // Bottom Controls for iPhone 15 Pro Max
                VStack(spacing: 16) {
                    // Zoom Presets: 0.5x (Macro), 1x, 2x, 5x
                    HStack(spacing: 16) {
                        ForEach(CameraManager.ZoomPreset.allCases) { preset in
                            Button(action: {
                                cameraManager.setZoomPreset(preset)
                            }) {
                                Text(preset.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(width: 44, height: 44)
                                    .background(cameraManager.currentZoomPreset == preset ? Color.yellow : Color.black.opacity(0.65))
                                    .foregroundColor(cameraManager.currentZoomPreset == preset ? .black : .white)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    // Scanned Numbers Quick Strip
                    if let latestNumber = cameraManager.detectedNumbers.first {
                        Button(action: {
                            selectedNumber = latestNumber
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "viewfinder")
                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                Text(latestNumber.cleanNumber)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Open Actions")
                                    .font(.caption.bold())
                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.6), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 40)
            }

            // Action Bottom Sheet
            if let number = selectedNumber {
                Color.black.opacity(0.4)
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
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedNumber != nil)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(defaultCountryPrefix: $defaultCountryPrefix)
        }
    }
}
