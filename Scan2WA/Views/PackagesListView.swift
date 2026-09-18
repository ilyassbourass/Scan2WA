import SwiftUI

public struct PackagesListView: View {
    @ObservedObject private var packageManager = PackageManager.shared
    @AppStorage("defaultCountryPrefix") private var defaultCountryPrefix: String = "+212"
    @Environment(\.presentationMode) private var presentationMode

    @State private var searchQuery: String = ""
    @State private var selectedStatusFilter: DeliveryStatus? = nil // nil = "Tous"
    @State private var selectedPhotoForPreview: UIImage? = nil
    @State private var packageToEdit: PackageModel? = nil
    @State private var packageToDelete: PackageModel? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showCopiedBanner: Bool = false

    @FocusState private var isSearchFocused: Bool

    public init() {}

    private var filteredPackages: [PackageModel] {
        packageManager.filteredPackages(query: searchQuery, statusFilter: selectedStatusFilter)
    }

    private func countFor(status: DeliveryStatus) -> Int {
        packageManager.packages.filter { $0.status == status }.count
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBarView

                    // Status Filter Tabs (Tous, Livré, Reporté, Annulé)
                    statusFilterTabs

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
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Phone number copied to clipboard!")
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
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFocused = false
            }
            .navigationTitle("Saved Packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(packageManager.packages.count) \(packageManager.packages.count == 1 ? "colis" : "colis")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $packageToEdit) { pkg in
                EditPackageSheet(package: pkg)
            }
            .sheet(isPresented: Binding(
                get: { selectedPhotoForPreview != nil },
                set: { if !$0 { selectedPhotoForPreview = nil } }
            )) {
                if let photo = selectedPhotoForPreview {
                    PhotoPreviewModal(image: photo) {
                        selectedPhotoForPreview = nil
                    }
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Package?"),
                    message: Text("Are you sure you want to delete the package for \(packageToDelete?.cleanNumber ?? "")? This will also remove the photo."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let id = packageToDelete?.id {
                            packageManager.deletePackage(id: id)
                        }
                    },
                    secondaryButton: .cancel()
                )
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
                // Tab: Tous
                Button(action: {
                    selectedStatusFilter = nil
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }) {
                    HStack(spacing: 6) {
                        Text("Tous")
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
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Package Card
    private func packageCard(for pkg: PackageModel) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Package photo thumbnail with tap to expand
                if let photo = packageManager.loadPhoto(fileName: pkg.photoFileName) {
                    Button(action: {
                        selectedPhotoForPreview = photo
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                                .padding(4)
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

                        // Menu button for edit/delete
                        Menu {
                            Button(action: { packageToEdit = pkg }) {
                                Label("Edit Notes, Status & Location", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                packageToDelete = pkg
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete Package", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(width: 28, height: 28)
                        }
                    }

                    // Status pill with 1-tap quick status switcher
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

                    // Date saved
                    Text(pkg.createdAt, style: .date) + Text(" at ") + Text(pkg.createdAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

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
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.6))

            if searchQuery.isEmpty && selectedStatusFilter == nil {
                Text("No Packages Saved Yet")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Scan a phone number on a package label, tap the number, then select 'Save Package & Take Photo' to save it here.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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
                            Text("STATUT")
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

// MARK: - Fullscreen Photo Preview Modal
fileprivate struct PhotoPreviewModal: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(16)
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
