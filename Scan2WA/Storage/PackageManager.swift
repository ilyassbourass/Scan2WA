import Foundation
import UIKit
import Combine

public final class PackageManager: ObservableObject {
    public static let shared = PackageManager()

    @Published public var packages: [PackageModel] = []

    private let fileManager = FileManager.default
    private let packagesFileName = "packages.json"
    private let photosDirName = "PackagePhotos"

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

    /// Saves a new package with its photo, phone number, location link, and delivery notes
    @discardableResult
    public func savePackage(
        phoneNumber: String,
        cleanNumber: String,
        image: UIImage,
        locationLink: String? = nil,
        notes: String? = nil
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

        let newPackage = PackageModel(
            id: packageId,
            phoneNumber: phoneNumber,
            cleanNumber: cleanNumber,
            photoFileName: fileName,
            locationLink: locationLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? locationLink : nil,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes : nil,
            createdAt: Date(),
            isDelivered: false
        )

        DispatchQueue.main.async {
            self.packages.insert(newPackage, at: 0)
            self.persistPackages()
        }

        return newPackage
    }

    /// Updates an existing package (e.g. notes, location link, or delivered status)
    public func updatePackage(_ package: PackageModel) {
        if let index = packages.firstIndex(where: { $0.id == package.id }) {
            packages[index] = package
            persistPackages()
        }
    }

    /// Deletes a package and cleans up its photo from storage
    public func deletePackage(id: UUID) {
        if let index = packages.firstIndex(where: { $0.id == id }) {
            let package = packages[index]
            let photoURL = photosDirectoryURL.appendingPathComponent(package.photoFileName)
            try? fileManager.removeItem(at: photoURL)
            packages.remove(at: index)
            persistPackages()
        }
    }

    /// Loads the photo for a package from disk
    public func loadPhoto(fileName: String) -> UIImage? {
        let photoURL = photosDirectoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: photoURL.path) else { return nil }
        return UIImage(contentsOfFile: photoURL.path)
    }

    /// Returns packages filtered by search query (optimized for last 2 digits matching)
    public func filteredPackages(query: String) -> [PackageModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return packages
        }

        let cleanQuery = trimmed.filter { $0.isNumber }

        // Sort results: exact last-digits matches first, then contains, then notes
        return packages.filter { $0.matches(query: trimmed) }.sorted { a, b in
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
