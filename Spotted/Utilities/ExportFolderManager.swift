import Foundation
import UIKit

/// Manages a user-selected default export folder using security-scoped bookmarks
@MainActor
final class ExportFolderManager: ObservableObject {
    static let shared = ExportFolderManager()
    
    private let bookmarkKey = "defaultExportFolderBookmark"
    
    @Published private(set) var selectedFolderURL: URL?
    @Published private(set) var selectedFolderName: String?
    
    private init() {
        loadSavedFolder()
    }
    
    // MARK: - Folder Selection
    
    /// Returns whether a default export folder is configured
    var hasDefaultFolder: Bool {
        selectedFolderURL != nil
    }
    
    /// Load the previously saved folder from bookmark data
    private func loadSavedFolder() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                // Bookmark is stale, try to refresh it
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    try saveBookmark(for: url)
                }
            }
            
            selectedFolderURL = url
            selectedFolderName = url.lastPathComponent
        } catch {
            print("Failed to resolve bookmark: \(error)")
            clearDefaultFolder()
        }
    }
    
    /// Save the folder URL as a security-scoped bookmark
    private func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }
    
    /// Set a new default export folder
    func setDefaultFolder(_ url: URL) {
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            try saveBookmark(for: url)
            selectedFolderURL = url
            selectedFolderName = url.lastPathComponent
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }
    
    /// Clear the default export folder
    func clearDefaultFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        selectedFolderURL = nil
        selectedFolderName = nil
    }
    
    // MARK: - File Operations
    
    /// Save data to the default export folder
    /// - Returns: The URL where the file was saved, or nil if no default folder is set
    func saveToDefaultFolder(data: Data, fileName: String) throws -> URL? {
        guard let folderURL = selectedFolderURL else {
            return nil
        }
        
        // Start accessing the security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            throw ExportFolderError.accessDenied
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }
        
        let fileURL = folderURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    /// Check if we can write to the default folder
    func canWriteToDefaultFolder() -> Bool {
        guard let folderURL = selectedFolderURL else {
            return false
        }
        
        guard folderURL.startAccessingSecurityScopedResource() else {
            return false
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }
        
        return FileManager.default.isWritableFile(atPath: folderURL.path)
    }
}

enum ExportFolderError: LocalizedError {
    case accessDenied
    case writeFailure
    case noDefaultFolder
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Unable to access the export folder. Please reselect it."
        case .writeFailure:
            return "Failed to write file to the export folder."
        case .noDefaultFolder:
            return "No default export folder is set."
        }
    }
}
