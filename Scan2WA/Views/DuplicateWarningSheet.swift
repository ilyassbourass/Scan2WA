import SwiftUI

public struct DuplicateWarningSheet: View {
    public let existingPackage: PackageModel
    public let newNumber: String
    public let newImage: UIImage?
    public let onSaveAnyway: () -> Void
    public let onDelete: () -> Void
    public let onCancel: () -> Void

    @ObservedObject private var packageManager = PackageManager.shared

    public init(
        existingPackage: PackageModel,
        newNumber: String,
        newImage: UIImage? = nil,
        onSaveAnyway: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingPackage = existingPackage
        self.newNumber = newNumber
        self.newImage = newImage
        self.onSaveAnyway = onSaveAnyway
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Header Indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                // Warning Header
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)

                    Text("Duplicate Number Detected!")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundColor(.white)

                    Text("A package for ")
                        .foregroundColor(.gray)
                    + Text(newNumber)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    + Text(" already exists in your active deliveries.")
                        .foregroundColor(.gray)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

                // Existing Package Card Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXISTING ACTIVE PACKAGE:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)

                    HStack(spacing: 12) {
                        if let img = packageManager.loadPhoto(fileName: existingPackage.photoFileName) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(10)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .overlay(Image(systemName: "shippingbox").foregroundColor(.gray))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(existingPackage.cleanNumber)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)

                                Spacer()

                                Text(existingPackage.lastTwoDigits)
                                    .font(.system(size: 11, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }

                            HStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    Image(systemName: existingPackage.status.iconName)
                                        .font(.system(size: 9))
                                    Text(existingPackage.status.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(existingPackage.status.backgroundColor)
                                .foregroundColor(existingPackage.status.color)
                                .cornerRadius(6)

                                Text(existingPackage.createdAt, style: .time)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }

                            if let notes = existingPackage.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 10)

                // Actions: Save Anyway, Delete / Discard, Cancel
                VStack(spacing: 10) {
                    // 1. Save Anyway Button
                    Button(action: {
                        let haptic = UIImpactFeedbackGenerator(style: .medium)
                        haptic.impactOccurred()
                        onSaveAnyway()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Save Anyway")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Add as an additional package for this customer")
                                    .font(.system(size: 11))
                                    .opacity(0.8)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                        .foregroundColor(.black)
                        .cornerRadius(14)
                    }

                    // 2. Delete / Discard Button
                    Button(action: {
                        let haptic = UINotificationFeedbackGenerator()
                        haptic.notificationOccurred(.warning)
                        onDelete()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15, weight: .bold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Delete & Discard")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Discard this photo and don't save duplicate")
                                    .font(.system(size: 11))
                                    .opacity(0.8)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.88))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    // 3. Cancel / Keep Editing
                    Button(action: onCancel) {
                        Text("Cancel & Edit Number")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}
