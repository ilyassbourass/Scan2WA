import SwiftUI

public struct PackagesListView: View {
    @ObservedObject private var packageManager = PackageManager.shared
    @AppStorage("defaultCountryPrefix") private var defaultCountryPrefix: String = "+212"
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var navigationState: AppNavigationState

    @State private var searchQuery: String = ""
    @State private var selectedStatusFilter: DeliveryStatus? = nil // nil = "All"
    @State private var selectedPhotoForPreview: UIImage? = nil
    @State private var previewTitle: String? = nil
    @State private var packageToEdit: PackageModel? = nil
    @State private var packageToDelete: PackageModel? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showCopiedBanner: Bool = false
    @State private var copiedBannerText: String = "Phone number copied to clipboard!"
    @State private var showAddPackageSheet: Bool = false
    @State private var showShortcutSheet: Bool = false
    @State private var showTrashSheet: Bool = false
    @State private var undoTrashedIDs: Set<UUID> = []
    @State private var isSelectionMode: Bool = false
    @State private var selectedPackageIDs: Set<UUID> = []
    @State private var showBatchDeleteAlert: Bool = false

    @FocusState private var isSearchFocused: Bool

    public init() {}

    private var filteredPackages: [PackageModel] {
        packageManager.filteredPackages(query: searchQuery, statusFilter: selectedStatusFilter)
    }

    private func countFor(status: DeliveryStatus) -> Int {
        packageManager.activeCount(for: status)
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBarView

                    // Status Filter Tabs (All, Livré, Reporté, Annulé)
                    statusFilterTabs

                    // Selection Mode Subheader Bar
                    if isSelectionMode {
                        HStack {
                            Text("\(selectedPackageIDs.count) of \(filteredPackages.count) selected")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    if selectedPackageIDs.count == filteredPackages.count {
                                        selectedPackageIDs.removeAll()
                                    } else {
                                        selectedPackageIDs = Set(filteredPackages.map { $0.id })
                                    }
                                }
                                let haptic = UIImpactFeedbackGenerator(style: .light)
                                haptic.impactOccurred()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: selectedPackageIDs.count == filteredPackages.count ? "checkmark.circle.fill" : "checkmark.circle")
                                    Text(selectedPackageIDs.count == filteredPackages.count ? "Deselect All" : "Select All")
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
                    if filteredPackages.isEmpty {
                        emptyStateView
                    } else {
                        packagesScrollView
                    }
                }

                // Copied Notification Toast
                if showCopiedBanner {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(copiedBannerText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)

                            if !undoTrashedIDs.isEmpty {
                                Button(action: {
                                    packageManager.batchRestoreFromTrash(ids: undoTrashedIDs)
                                    undoTrashedIDs.removeAll()
                                    withAnimation { showCopiedBanner = false }
                                    let haptic = UINotificationFeedbackGenerator()
                                    haptic.notificationOccurred(.success)
                                }) {
                                    Text("UNDO")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.darkGray).opacity(0.95))
                        .cornerRadius(20)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Bottom Batch Action Bar
                if isSelectionMode {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                // 1. Mark All / Selected as... Menu
                                Menu {
                                    ForEach(DeliveryStatus.allCases) { status in
                                        Button(action: {
                                            let count = selectedPackageIDs.count
                                            packageManager.batchUpdateStatus(ids: selectedPackageIDs, status: status)
                                            let haptic = UINotificationFeedbackGenerator()
                                            haptic.notificationOccurred(.success)
                                            copiedBannerText = "Marked \(count) package\(count == 1 ? "" : "s") as \(status.rawValue)!"
                                            withAnimation { showCopiedBanner = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                                withAnimation { showCopiedBanner = false }
                                            }
                                            selectedPackageIDs.removeAll()
                                            isSelectionMode = false
                                        }) {
                                            Label("Mark as \(status.rawValue)", systemImage: status.iconName)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 15, weight: .bold))
                                        Text(selectedPackageIDs.isEmpty ? "Mark Status" : "Mark as (\(selectedPackageIDs.count))")
                                            .font(.system(size: 14, weight: .bold))
                                        Image(systemName: "chevron.up")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(selectedPackageIDs.isEmpty ? Color.white.opacity(0.12) : Color(red: 0.15, green: 0.78, blue: 0.35))
                                    .foregroundColor(selectedPackageIDs.isEmpty ? .gray : .black)
                                    .cornerRadius(14)
                                }
                                .disabled(selectedPackageIDs.isEmpty)

                                // 2. Delete Selected Packages Button
                                Button(action: {
                                    showBatchDeleteAlert = true
                                }) {
                                    HStack(spacing: 8) {
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFocused = false
            }
            .navigationTitle("")
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
                    } else {
                        HStack(spacing: 12) {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }

                            // Trash Button with live count badge
                            Button(action: {
                                showTrashSheet = true
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18))
                                        .foregroundColor(packageManager.trashedPackages.isEmpty ? .gray : .red.opacity(0.9))

                                    if !packageManager.trashedPackages.isEmpty {
                                        Text("\(packageManager.trashedPackages.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: 8, y: -6)
                                    }
                                }
                            }
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    if isSelectionMode {
                        Text("Select Items")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        HStack(spacing: 6) {
                            Text("Packages")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Text("\(packageManager.packages.count)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        Button(action: {
                            withAnimation {
                                if selectedPackageIDs.count == filteredPackages.count {
                                    selectedPackageIDs.removeAll()
                                } else {
                                    selectedPackageIDs = Set(filteredPackages.map { $0.id })
                                }
                            }
                            let haptic = UIImpactFeedbackGenerator(style: .light)
                            haptic.impactOccurred()
                        }) {
                            Text(selectedPackageIDs.count == filteredPackages.count ? "Deselect All" : "Select All")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                        }
                    } else {
                        HStack(spacing: 10) {
                            if !filteredPackages.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        isSelectionMode = true
                                    }
                                }) {
                                    Text("Select")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                }
                            }

                            // Prominent "+ Add" button
                            Button(action: {
                                showAddPackageSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Add")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                                .cornerRadius(14)
                            }
                        }
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFocused = false
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                }
            }
            .sheet(item: $packageToEdit) { pkg in
                EditPackageSheet(package: pkg)
            }
            .sheet(isPresented: $showTrashSheet) {
                TrashView()
            }
            .sheet(isPresented: $showShortcutSheet) {
                ShortcutGuideSheetView(onCopyURL: {
                    UIPasteboard.general.string = "scan2wa://search"
                    let haptic = UINotificationFeedbackGenerator()
                    haptic.notificationOccurred(.success)
                    copiedBannerText = "URL 'scan2wa://search' copied!"
                    withAnimation {
                        showCopiedBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation {
                            showCopiedBanner = false
                        }
                    }
                })
            }
            .sheet(isPresented: Binding(
                get: { selectedPhotoForPreview != nil },
                set: { if !$0 { selectedPhotoForPreview = nil } }
            )) {
                if let photo = selectedPhotoForPreview {
                    ZoomablePhotoPreviewModal(image: photo, title: previewTitle) {
                        selectedPhotoForPreview = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddPackageSheet) {
                PackagePhotoCaptureView(
                    phoneNumber: "",
                    cleanNumber: "",
                    onDismiss: {
                        showAddPackageSheet = false
                    }
                )
            }
            .alert(isPresented: $showBatchDeleteAlert) {
                Alert(
                    title: Text("Move \(selectedPackageIDs.count) Packages to Trash?"),
                    message: Text("Are you sure you want to move the \(selectedPackageIDs.count) selected package\(selectedPackageIDs.count == 1 ? "" : "s") to Trash? You can restore them anytime within 30 days."),
                    primaryButton: .destructive(Text("Move to Trash")) {
                        let count = selectedPackageIDs.count
                        let idsToTrash = selectedPackageIDs
                        packageManager.batchMoveToTrash(ids: idsToTrash)
                        selectedPackageIDs.removeAll()
                        isSelectionMode = false
                        undoTrashedIDs = idsToTrash
                        let haptic = UINotificationFeedbackGenerator()
                        haptic.notificationOccurred(.success)
                        copiedBannerText = "Moved \(count) package\(count == 1 ? "" : "s") to Trash"
                        withAnimation { showCopiedBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation { showCopiedBanner = false }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                if navigationState.autoFocusSearch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        self.isSearchFocused = true
                        navigationState.autoFocusSearch = false
                    }
                }
            }
        }
    }

    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                .font(.system(size: 16, weight: .bold))

            TextField("Search by last 2 digits (e.g. 73) or phone number...", text: $searchQuery)
                .focused($isSearchFocused)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .keyboardType(.numbersAndPunctuation)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            } else {
                Button(action: { showShortcutSheet = true }) {
                    Image(systemName: "bolt.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Status Filter Tabs (Tous, Livré, Reporté, Annulé)
    private var statusFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Tab: All
                Button(action: {
                    selectedStatusFilter = nil
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Text("All")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(packageManager.packages.count)")
                            .font(.system(size: 11, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(selectedStatusFilter == nil ? Color.white : Color.white.opacity(0.15))
                            .foregroundColor(selectedStatusFilter == nil ? .black : .white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(selectedStatusFilter == nil ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }

                // Tabs: Livré, Reporté, Annulé
                ForEach(DeliveryStatus.allCases) { status in
                    let isSelected = selectedStatusFilter == status
                    let count = countFor(status: status)

                    Button(action: {
                        if selectedStatusFilter == status {
                            selectedStatusFilter = nil
                        } else {
                            selectedStatusFilter = status
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: status.iconName)
                                .font(.system(size: 11, weight: .bold))
                            Text(status.rawValue)
                                .font(.system(size: 13, weight: .bold))

                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .black))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? (status.textColorOnStatus == .white ? Color.black.opacity(0.4) : Color.black) : status.color)
                                    .foregroundColor(isSelected ? (status.textColorOnStatus == .white ? .white : status.color) : status.textColorOnStatus)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? status.color : status.color.opacity(0.12))
                        .foregroundColor(isSelected ? status.textColorOnStatus : status.color)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(status.color.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Package List
    private var packagesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(filteredPackages) { pkg in
                    packageCard(for: pkg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, isSelectionMode ? 90 : 10)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Package Card
    private func packageCard(for pkg: PackageModel) -> some View {
        let isSelected = selectedPackageIDs.contains(pkg.id)

        return HStack(spacing: 12) {
            // Selection Checkbox
            if isSelectionMode {
                Button(action: {
                    toggleSelection(for: pkg.id)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35) : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    // Package photo thumbnail with tap to expand
                    if let photo = packageManager.loadPhoto(fileName: pkg.photoFileName) {
                        Button(action: {
                            if isSelectionMode {
                                toggleSelection(for: pkg.id)
                            } else {
                                previewTitle = "\(pkg.cleanNumber) (#\(pkg.lastTwoDigits))"
                                selectedPhotoForPreview = photo
                            }
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                if !isSelectionMode {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.black.opacity(0.65))
                                        .clipShape(Circle())
                                        .padding(4)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray)
                            )
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            // Big Last 2 Digits Badge
                            Text("#\(pkg.lastTwoDigits)")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(pkg.status.color)
                                .foregroundColor(pkg.status.textColorOnStatus)
                                .cornerRadius(6)

                            // Phone Number
                            Text(pkg.cleanNumber)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            if !isSelectionMode {
                                // Menu button for edit/delete
                                Menu {
                                    Button(action: { packageToEdit = pkg }) {
                                        Label("Edit Notes, Status & Location", systemImage: "pencil")
                                    }

                                    Button(role: .destructive, action: {
                                        let id = pkg.id
                                        packageManager.moveToTrash(id: id)
                                        undoTrashedIDs = [id]
                                        let haptic = UINotificationFeedbackGenerator()
                                        haptic.notificationOccurred(.success)
                                        copiedBannerText = "Package moved to Trash"
                                        withAnimation { showCopiedBanner = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                            withAnimation { showCopiedBanner = false }
                                        }
                                    }) {
                                        Label("Move to Trash", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.gray)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            // Status pill with 1-tap quick status switcher
                            if !isSelectionMode {
                                Menu {
                                    ForEach(DeliveryStatus.allCases) { st in
                                        Button(action: {
                                            packageManager.updateStatus(id: pkg.id, status: st)
                                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                                            haptic.impactOccurred()
                                        }) {
                                            Label(st.rawValue, systemImage: st.iconName)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: pkg.status.iconName)
                                            .font(.system(size: 11, weight: .bold))
                                        Text(pkg.status.rawValue)
                                            .font(.system(size: 12, weight: .bold))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(pkg.status.backgroundColor)
                                    .foregroundColor(pkg.status.color)
                                    .cornerRadius(8)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: pkg.status.iconName)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(pkg.status.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(pkg.status.backgroundColor)
                                .foregroundColor(pkg.status.color)
                                .cornerRadius(8)
                            }

                            // Duplicate count badge (if > 1 package for this number)
                            let activeCount = packageManager.activePackageCount(for: pkg.cleanNumber)
                            if activeCount > 1 {
                                HStack(spacing: 3) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.system(size: 9))
                                    Text("\(activeCount)x")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.18))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                            }
                        }

                        // Notes (if any)
                        if let notes = pkg.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                        }

                        // Location link button (if any)
                        if let link = pkg.locationLink, !link.isEmpty {
                            Button(action: {
                                openLocationLink(link)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 11))
                                    Text("Open Location Map")
                                        .font(.system(size: 12, weight: .semibold))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.blue)
                            }
                        }

                        // Time saved (only time, no big date)
                        Text(pkg.createdAt, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if !isSelectionMode {
                    Divider().background(Color.white.opacity(0.12))

                    // Action Shortcuts Bar
                    HStack(spacing: 8) {
                        // 1. WhatsApp Business Button
                        Button(action: {
                            openWABusiness(for: pkg.cleanNumber)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("WA Business")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }

                        // 2. Call Button
                        Button(action: {
                            callNumber(pkg.cleanNumber)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Call")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }

                        // 3. Copy Button
                        Button(action: {
                            copyNumber(pkg.cleanNumber)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(14)
            .background(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.12) : Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(red: 0.15, green: 0.78, blue: 0.35) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
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

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.6))

            if searchQuery.isEmpty && selectedStatusFilter == nil {
                Text("No Packages Saved Yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Scan a phone number on a package label, or tap below to capture or select a photo from your gallery.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: {
                    showAddPackageSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add Package")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .foregroundColor(.black)
                    .cornerRadius(22)
                }
                .padding(.top, 6)
            } else {
                Text("No matching packages")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Text("Try adjusting your search query or status filter.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Helper Actions
    private func openWABusiness(for cleanNumber: String) {
        let waNumber = PhoneNumberParser.shared.prepareForWhatsApp(
            cleanNumber: cleanNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )
        let smbUrlString = "whatsapp-smb://send?phone=\(waNumber)"
        let fallbackUrlString = "https://wa.me/\(waNumber)"

        if let smbUrl = URL(string: smbUrlString) {
            UIApplication.shared.open(smbUrl, options: [:]) { success in
                if !success, let webUrl = URL(string: fallbackUrlString) {
                    UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                }
            }
        }
    }

    private func callNumber(_ cleanNumber: String) {
        let callNumber = PhoneNumberParser.shared.prepareForCall(
            cleanNumber: cleanNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )
        if let callURL = URL(string: "tel://\(callNumber)") {
            UIApplication.shared.open(callURL, options: [:], completionHandler: nil)
        }
    }

    private func copyNumber(_ cleanNumber: String) {
        let waNumber = PhoneNumberParser.shared.prepareForWhatsApp(
            cleanNumber: cleanNumber,
            defaultCountryPrefix: defaultCountryPrefix
        )
        UIPasteboard.general.string = "+\(waNumber)"
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        withAnimation {
            showCopiedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopiedBanner = false
            }
        }
    }

    private func openLocationLink(_ linkString: String) {
        var trimmed = linkString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }
        if let url = URL(string: trimmed) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - Edit Package Sheet
fileprivate struct EditPackageSheet: View {
    @State var package: PackageModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var notesText: String = ""
    @State private var locationLinkText: String = ""
    @State private var selectedStatus: DeliveryStatus = .livre

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Status Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STATUS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 6) {
                                ForEach(DeliveryStatus.allCases) { status in
                                    Button(action: {
                                        selectedStatus = status
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: status.iconName)
                                                .font(.system(size: 11, weight: .bold))
                                            Text(status.rawValue)
                                                .font(.system(size: 12, weight: .bold))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedStatus == status ? status.color : Color.white.opacity(0.08))
                                        .foregroundColor(selectedStatus == status ? status.textColorOnStatus : .white)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        // Notes Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("Delivery instructions...", text: $notesText)
                                .focused($isFieldFocused)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }

                        // Location Link Field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("LOCATION LINK")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Paste") {
                                    if let paste = UIPasteboard.general.string {
                                        locationLinkText = paste
                                    }
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            }

                            TextField("Google Maps or Apple Maps URL...", text: $locationLinkText)
                                .focused($isFieldFocused)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .keyboardType(.URL)
                        }

                        // Move to Trash Button
                        Button(role: .destructive, action: {
                            PackageManager.shared.moveToTrash(id: package.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Move to Trash")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                        }
                        .padding(.top, 12)

                        Spacer()
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFieldFocused = false
            }
            .navigationTitle("Edit Package Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        package.notes = notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesText
                        package.locationLink = locationLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : locationLinkText
                        package.status = selectedStatus
                        PackageManager.shared.updatePackage(package)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .font(.headline)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFieldFocused = false
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                }
            }
            .onAppear {
                self.notesText = package.notes ?? ""
                self.locationLinkText = package.locationLink ?? ""
                self.selectedStatus = package.status
            }
        }
    }
}

// MARK: - Shortcut & Quick Actions Guide Sheet
fileprivate struct ShortcutGuideSheetView: View {
    let onCopyURL: () -> Void
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quick Access & Shortcuts")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.white)
                            Text("Instantly access package search and parcel intake in a single tap.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        // Method 1: 3D Touch / Long-press on Home Screen Icon
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16, weight: .bold))
                                Text("1. Long-press App Icon (Home Screen)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("On your iPhone home screen, press and hold the Scan2WA icon to access quick actions:")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                    Text("🔍 Search Packages (opens search directly)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.cyan)
                                    Text("📦 Add Package (opens camera intake)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(10)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)

                        // Method 2: iOS Shortcuts App Deep Link
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 16, weight: .bold))
                                Text("2. Custom iOS Shortcut")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Create a 1-tap home screen icon or widget using Apple's Shortcuts app:")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("1. Open the **Shortcuts** app on your iPhone.")
                                Text("2. Tap **+** to create a new shortcut.")
                                Text("3. Add the **Open URL** action.")
                                Text("4. Paste: **scan2wa://search**")
                                Text("5. Tap **Add to Home Screen**.")
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                            Button(action: {
                                onCopyURL()
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Copy URL: scan2wa://search")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .font(.headline)
                }
            }
        }
    }
}

