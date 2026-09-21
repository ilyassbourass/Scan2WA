import SwiftUI

public struct TrashView: View {
    @ObservedObject private var packageManager = PackageManager.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var isSelectionMode: Bool = false
    @State private var selectedPackageIDs: Set<UUID> = []
    @State private var showEmptyTrashAlert: Bool = false
    @State private var showBatchDeleteAlert: Bool = false
    @State private var packageToPermanentlyDelete: PackageModel? = nil
    @State private var showSingleDeleteAlert: Bool = false
    @State private var selectedPhotoForPreview: UIImage? = nil
    @State private var toastBannerText: String = ""
    @State private var showToastBanner: Bool = false

    public init() {}

    private var trashedPackages: [PackageModel] {
        packageManager.trashedPackages
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Retention Notice Banner (Google Photos style)
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)

                        Text("Items in Trash are permanently deleted after 30 days.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.orange.opacity(0.3)),
                        alignment: .bottom
                    )

                    // Selection Mode Subheader Bar
                    if isSelectionMode && !trashedPackages.isEmpty {
                        HStack {
                            Text("\(selectedPackageIDs.count) of \(trashedPackages.count) selected")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    if selectedPackageIDs.count == trashedPackages.count {
                                        selectedPackageIDs.removeAll()
                                    } else {
                                        selectedPackageIDs = Set(trashedPackages.map { $0.id })
                                    }
                                }
                                let haptic = UIImpactFeedbackGenerator(style: .light)
                                haptic.impactOccurred()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: selectedPackageIDs.count == trashedPackages.count ? "checkmark.circle.fill" : "checkmark.circle")
                                    Text(selectedPackageIDs.count == trashedPackages.count ? "Deselect All" : "Select All")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .transition(.opacity)
                    }

                    // Content
                    if trashedPackages.isEmpty {
                        emptyTrashView
                    } else {
                        trashedPackagesScrollView
                    }
                }

                // Toast Notification
                if showToastBanner {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toastBannerText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.darkGray).opacity(0.95))
                        .cornerRadius(20)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Floating Batch Actions Bar (when in selection mode)
                if isSelectionMode && !trashedPackages.isEmpty {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            // 1. Restore Selected
                            Button(action: {
                                let count = selectedPackageIDs.count
                                packageManager.batchRestoreFromTrash(ids: selectedPackageIDs)
                                selectedPackageIDs.removeAll()
                                isSelectionMode = false
                                showToast("Restored \(count) package\(count == 1 ? "" : "s")!")
                                let haptic = UINotificationFeedbackGenerator()
                                haptic.notificationOccurred(.success)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(selectedPackageIDs.isEmpty ? "Restore" : "Restore (\(selectedPackageIDs.count))")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(selectedPackageIDs.isEmpty ? Color.white.opacity(0.12) : Color(red: 0.15, green: 0.78, blue: 0.35))
                                .foregroundColor(selectedPackageIDs.isEmpty ? .gray : .black)
                                .cornerRadius(14)
                            }
                            .disabled(selectedPackageIDs.isEmpty)

                            // 2. Delete Selected Permanently
                            Button(action: {
                                showBatchDeleteAlert = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(selectedPackageIDs.isEmpty ? "Delete" : "Delete (\(selectedPackageIDs.count))")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(selectedPackageIDs.isEmpty ? Color.white.opacity(0.12) : Color.red.opacity(0.9))
                                .foregroundColor(selectedPackageIDs.isEmpty ? .gray : .white)
                                .cornerRadius(14)
                            }
                            .disabled(selectedPackageIDs.isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.darkGray).opacity(0.96))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: -2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Trash (\(trashedPackages.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Done") {
                            withAnimation {
                                isSelectionMode = false
                                selectedPackageIDs.removeAll()
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                    } else if !trashedPackages.isEmpty {
                        Button("Empty Trash") {
                            showEmptyTrashAlert = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        if !isSelectionMode && !trashedPackages.isEmpty {
                            Button("Select") {
                                withAnimation {
                                    isSelectionMode = true
                                }
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                        }

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .alert(isPresented: $showEmptyTrashAlert) {
                Alert(
                    title: Text("Empty Trash?"),
                    message: Text("Are you sure you want to permanently delete all \(trashedPackages.count) package\(trashedPackages.count == 1 ? "" : "s") and their photos? This action cannot be undone."),
                    primaryButton: .destructive(Text("Empty Trash")) {
                        packageManager.emptyTrash()
                        showToast("Trash emptied permanently")
                        let haptic = UINotificationFeedbackGenerator()
                        haptic.notificationOccurred(.success)
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showBatchDeleteAlert) {
                Alert(
                    title: Text("Delete \(selectedPackageIDs.count) Packages?"),
                    message: Text("Are you sure you want to permanently delete the selected \(selectedPackageIDs.count) package\(selectedPackageIDs.count == 1 ? "" : "s") and their photos? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete Permanently")) {
                        let count = selectedPackageIDs.count
                        packageManager.batchPermanentlyDelete(ids: selectedPackageIDs)
                        selectedPackageIDs.removeAll()
                        isSelectionMode = false
                        showToast("Permanently deleted \(count) package\(count == 1 ? "" : "s")")
                        let haptic = UINotificationFeedbackGenerator()
                        haptic.notificationOccurred(.success)
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showSingleDeleteAlert) {
                Alert(
                    title: Text("Delete Permanently?"),
                    message: Text("Are you sure you want to permanently delete the package for \(packageToPermanentlyDelete?.cleanNumber ?? "")? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let id = packageToPermanentlyDelete?.id {
                            packageManager.permanentlyDelete(id: id)
                            packageToPermanentlyDelete = nil
                            showToast("Package permanently deleted")
                            let haptic = UINotificationFeedbackGenerator()
                            haptic.notificationOccurred(.success)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: Binding(
                get: { selectedPhotoForPreview != nil },
                set: { if !$0 { selectedPhotoForPreview = nil } }
            )) {
                if let photo = selectedPhotoForPreview {
                    TrashPhotoPreviewModal(image: photo) {
                        selectedPhotoForPreview = nil
                    }
                }
            }
        }
    }

    // MARK: - Trashed Packages ScrollView
    private var trashedPackagesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(trashedPackages) { pkg in
                    trashedPackageCard(for: pkg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, isSelectionMode ? 100 : 24)
        }
    }

    // MARK: - Trashed Package Card
    private func trashedPackageCard(for pkg: PackageModel) -> some View {
        let isSelected = selectedPackageIDs.contains(pkg.id)

        return HStack(spacing: 12) {
            // Selection Checkbox
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35) : .gray)
            }

            // Thumbnail
            Button(action: {
                if isSelectionMode {
                    toggleSelection(for: pkg.id)
                } else if let img = packageManager.loadPhoto(fileName: pkg.photoFileName) {
                    selectedPhotoForPreview = img
                }
            }) {
                if let img = packageManager.loadPhoto(fileName: pkg.photoFileName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }

            // Details
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(pkg.cleanNumber)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Last 2 digits badge
                    Text(pkg.lastTwoDigits)
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                HStack(spacing: 8) {
                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: pkg.status.iconName)
                            .font(.system(size: 10))
                        Text(pkg.status.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(pkg.status.backgroundColor)
                    .foregroundColor(pkg.status.color)
                    .cornerRadius(6)

                    // Deletion timestamp
                    if let trashedAt = pkg.trashedAt {
                        Text("Deleted ") + Text(trashedAt, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    } else {
                        Text(pkg.createdAt, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }

                // Card actions (when not in select mode)
                if !isSelectionMode {
                    HStack(spacing: 8) {
                        // Restore Button
                        Button(action: {
                            packageManager.restoreFromTrash(id: pkg.id)
                            showToast("Package restored to active list!")
                            let haptic = UINotificationFeedbackGenerator()
                            haptic.notificationOccurred(.success)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Restore")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.2))
                            .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            .cornerRadius(8)
                        }

                        // Permanently Delete Button
                        Button(action: {
                            packageToPermanentlyDelete = pkg
                            showSingleDeleteAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Delete")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .frame(width: 80, height: 32)
                            .background(Color.red.opacity(0.18))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.12) : Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                toggleSelection(for: pkg.id)
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedPackageIDs.contains(id) {
            selectedPackageIDs.remove(id)
        } else {
            selectedPackageIDs.insert(id)
        }
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
    }

    private func showToast(_ message: String) {
        toastBannerText = message
        withAnimation {
            showToastBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showToastBanner = false
            }
        }
    }

    // MARK: - Empty Trash View
    private var emptyTrashView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "trash.slash")
                .font(.system(size: 56))
                .foregroundColor(.gray.opacity(0.6))

            Text("Trash is Empty")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Packages you delete will be moved here and kept safely for 30 days before being permanently removed.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Trash Photo Preview Modal
fileprivate struct TrashPhotoPreviewModal: View {
    let image: UIImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            }
        }
    }
}
