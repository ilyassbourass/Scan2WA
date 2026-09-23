import Foundation
import UIKit
import Combine

public final class PackageManager: ObservableObject {
    public static let shared = PackageManager()

    @Published public var packages: [PackageModel] = []

    private let fileManager = FileManager.default
    private let packagesFileName = "packages.json"
    private let photosDirName = "PackagePhotos"

    private let photoCache = NSCache<NSString, UIImage>()

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var packagesFileURL: URL {
        documentsDirectory.appendingPathComponent(packagesFileName)
    }

    private var photosDirectoryURL: URL {
        documentsDirectory.appendingPathComponent(photosDirName, isDirectory: true)
    }

    private init() {
        createPhotosDirectoryIfNeeded()
        loadPackages()
    }

    private func createPhotosDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectoryURL.path) {
            try? fileManager.createDirectory(at: photosDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func loadPackages() {
        guard fileManager.fileExists(atPath: packagesFileURL.path) else {
            self.packages = []
            return
        }

        do {
            let data = try Data(contentsOf: packagesFileURL)
            let decoded = try JSONDecoder().decode([PackageModel].self, from: data)
            DispatchQueue.main.async {
                self.packages = decoded
                self.autoPurgeOldTrash()
            }
        } catch {
            print("Error loading packages: \(error)")
        }
    }

    private func persistPackages() {
        do {
            let data = try JSONEncoder().encode(packages)
            try data.write(to: packagesFileURL, options: .atomic)
        } catch {
            print("Error persisting packages: \(error)")
        }
    }

    /// Saves a new package with its photo, phone number, location link, delivery notes, and status
    @discardableResult
    public func savePackage(
        phoneNumber: String,
        cleanNumber: String,
        image: UIImage,
        locationLink: String? = nil,
        notes: String? = nil,
        status: DeliveryStatus = .confirme
    ) -> PackageModel? {
        let packageId = UUID()
        let fileName = "pkg_\(packageId.uuidString).jpg"
        let photoURL = photosDirectoryURL.appendingPathComponent(fileName)

        // Save image to disk as compressed JPEG
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        do {
            try data.write(to: photoURL)
        } catch {
            print("Error saving package photo: \(error)")
            return nil
        }

        // Cache in memory for instant high-fps display
        photoCache.setObject(image, forKey: fileName as NSString)

        let newPackage = PackageModel(
            id: packageId,
            phoneNumber: phoneNumber,
            cleanNumber: cleanNumber,
            photoFileName: fileName,
            locationLink: locationLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? locationLink : nil,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes : nil,
            createdAt: Date(),
            status: status
        )

        if Thread.isMainThread {
            self.packages.insert(newPackage, at: 0)
            self.persistPackages()
        } else {
            DispatchQueue.main.async {
                self.packages.insert(newPackage, at: 0)
                self.persistPackages()
            }
        }

        return newPackage
    }

    /// Updates an existing package (e.g. notes, location link, or status)
    public func updatePackage(_ package: PackageModel) {
        if let index = packages.firstIndex(where: { $0.id == package.id }) {
            packages[index] = package
            persistPackages()
        }
    }

    /// Quickly updates the delivery status of a package
    public func updateStatus(id: UUID, status: DeliveryStatus) {
        let action = {
            if let index = self.packages.firstIndex(where: { $0.id == id }) {
                self.objectWillChange.send()
                self.packages[index].status = status
                self.persistPackages()
            }
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Batch updates the delivery status of multiple packages
    public func batchUpdateStatus(ids: Set<UUID>, status: DeliveryStatus) {
        guard !ids.isEmpty else { return }
        let action = {
            self.objectWillChange.send()
            for index in self.packages.indices {
                if ids.contains(self.packages[index].id) {
                    self.packages[index].status = status
                }
            }
            self.persistPackages()
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    // MARK: - Trash Management (Soft-Delete & Restore)

    /// Moves a package to Trash (keeps photo file, marks as trashed)
    public func moveToTrash(id: UUID) {
        let action = {
            if let index = self.packages.firstIndex(where: { $0.id == id }) {
                self.objectWillChange.send()
                self.packages[index].isTrashed = true
                self.packages[index].trashedAt = Date()
                self.persistPackages()
            }
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Batch moves packages to Trash
    public func batchMoveToTrash(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let now = Date()
        let action = {
            self.objectWillChange.send()
            for index in self.packages.indices {
                if ids.contains(self.packages[index].id) {
                    self.packages[index].isTrashed = true
                    self.packages[index].trashedAt = now
                }
            }
            self.persistPackages()
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Restores a package from Trash back to active packages
    public func restoreFromTrash(id: UUID) {
        let action = {
            if let index = self.packages.firstIndex(where: { $0.id == id }) {
                self.objectWillChange.send()
                self.packages[index].isTrashed = false
                self.packages[index].trashedAt = nil
                self.persistPackages()
            }
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Batch restores packages from Trash
    public func batchRestoreFromTrash(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let action = {
            self.objectWillChange.send()
            for index in self.packages.indices {
                if ids.contains(self.packages[index].id) {
                    self.packages[index].isTrashed = false
                    self.packages[index].trashedAt = nil
                }
            }
            self.persistPackages()
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Permanently deletes a package from Trash and removes photo from disk
    public func permanentlyDelete(id: UUID) {
        let action = {
            if let index = self.packages.firstIndex(where: { $0.id == id }) {
                let package = self.packages[index]
                self.photoCache.removeObject(forKey: package.photoFileName as NSString)
                let photoURL = self.photosDirectoryURL.appendingPathComponent(package.photoFileName)
                try? self.fileManager.removeItem(at: photoURL)
                self.objectWillChange.send()
                self.packages.remove(at: index)
                self.persistPackages()
            }
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Batch permanently deletes packages from Trash and removes their photos from disk
    public func batchPermanentlyDelete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let action = {
            for pkg in self.packages where ids.contains(pkg.id) {
                self.photoCache.removeObject(forKey: pkg.photoFileName as NSString)
                let photoURL = self.photosDirectoryURL.appendingPathComponent(pkg.photoFileName)
                try? self.fileManager.removeItem(at: photoURL)
            }
            self.objectWillChange.send()
            self.packages.removeAll(where: { ids.contains($0.id) })
            self.persistPackages()
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Empties the entire Trash, permanently removing all trashed packages and their photos
    public func emptyTrash() {
        let action = {
            let trashed = self.packages.filter { $0.isTrashed }
            for pkg in trashed {
                self.photoCache.removeObject(forKey: pkg.photoFileName as NSString)
                let photoURL = self.photosDirectoryURL.appendingPathComponent(pkg.photoFileName)
                try? self.fileManager.removeItem(at: photoURL)
            }
            self.objectWillChange.send()
            self.packages.removeAll(where: { $0.isTrashed })
            self.persistPackages()
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    /// Automatically purges trashed packages older than 30 days
    public func autoPurgeOldTrash(olderThanDays: Int = 30) {
        guard let threshold = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) else { return }
        let oldTrashed = packages.filter { $0.isTrashed && ($0.trashedAt ?? .distantPast) < threshold }
        guard !oldTrashed.isEmpty else { return }

        for pkg in oldTrashed {
            photoCache.removeObject(forKey: pkg.photoFileName as NSString)
            let photoURL = photosDirectoryURL.appendingPathComponent(pkg.photoFileName)
            try? fileManager.removeItem(at: photoURL)
        }
        packages.removeAll(where: { pkg in
            pkg.isTrashed && (pkg.trashedAt ?? .distantPast) < threshold
        })
        persistPackages()
    }

    /// Legacy delete aliases (safely routes to soft-delete moveToTrash)
    public func deletePackage(id: UUID) {
        moveToTrash(id: id)
    }

    public func batchDeletePackages(ids: Set<UUID>) {
        batchMoveToTrash(ids: ids)
    }

    // MARK: - Duplicate Detection

    /// Finds any existing active (non-trashed) package with the same phone number
    public func findDuplicate(for phoneNumber: String, excludingId: UUID? = nil) -> PackageModel? {
        let targetNorm = PhoneNumberParser.normalizeForComparison(phoneNumber)
        guard !targetNorm.isEmpty else { return nil }

        return packages.first { pkg in
            guard !pkg.isTrashed else { return false }
            if let excl = excludingId, pkg.id == excl { return false }
            let pkgNorm = PhoneNumberParser.normalizeForComparison(pkg.cleanNumber)
            return pkgNorm == targetNorm || pkg.cleanNumber == phoneNumber
        }
    }

    /// Returns count of active packages with this phone number (for showing e.g. "2x Packages" badge)
    public func activePackageCount(for phoneNumber: String) -> Int {
        let targetNorm = PhoneNumberParser.normalizeForComparison(phoneNumber)
        guard !targetNorm.isEmpty else { return 0 }

        return packages.filter { pkg in
            guard !pkg.isTrashed else { return false }
            let pkgNorm = PhoneNumberParser.normalizeForComparison(pkg.cleanNumber)
            return pkgNorm == targetNorm || pkg.cleanNumber == phoneNumber
        }.count
    }

    // MARK: - Collections & Queries

    /// Active (non-trashed) packages
    public var activePackages: [PackageModel] {
        packages.filter { !$0.isTrashed }
    }

    /// Trashed packages sorted newest deletion first
    public var trashedPackages: [PackageModel] {
        packages.filter { $0.isTrashed }.sorted { ($0.trashedAt ?? $0.createdAt) > ($1.trashedAt ?? $1.createdAt) }
    }

    /// Count for a specific delivery status among active packages
    public func activeCount(for status: DeliveryStatus) -> Int {
        packages.filter { !$0.isTrashed && $0.status == status }.count
    }

    /// Loads the photo for a package from cache or disk
    public func loadPhoto(fileName: String) -> UIImage? {
        if let cached = photoCache.object(forKey: fileName as NSString) {
            return cached
        }
        let photoURL = photosDirectoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: photoURL.path) else { return nil }
        if let image = UIImage(contentsOfFile: photoURL.path) {
            photoCache.setObject(image, forKey: fileName as NSString)
            return image
        }
        return nil
    }

    /// Returns active packages filtered by search query and optional status tab
    public func filteredPackages(query: String, statusFilter: DeliveryStatus? = nil) -> [PackageModel] {
        var result = packages.filter { !$0.isTrashed }

        if let status = statusFilter {
            result = result.filter { $0.status == status }
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return result
        }

        let cleanQuery = trimmed.filter { $0.isNumber }

        // Sort results: exact last-digits matches first, then contains, then notes
        return result.filter { $0.matches(query: trimmed) }.sorted { a, b in
            if !cleanQuery.isEmpty {
                let aSuffix = a.cleanNumber.hasSuffix(cleanQuery)
                let bSuffix = b.cleanNumber.hasSuffix(cleanQuery)
                if aSuffix && !bSuffix { return true }
                if !aSuffix && bSuffix { return false }
            }
            return a.createdAt > b.createdAt
        }
    }
}
