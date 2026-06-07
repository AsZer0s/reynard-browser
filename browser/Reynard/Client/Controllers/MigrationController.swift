//
//  MigrationController.swift
//  Reynard
//
//  Created by Minh Ton on 17/5/26.
//

import Foundation

// TODO: Remove migration when out of alpha
// Since moveItem is fast, this is run on startup, before everything else

final class MigrationController {
    static let shared = MigrationController()
    
    private let fileManager: FileManager
    private let documentsDirectoryURL: URL
    private let applicationSupportDirectoryURL: URL
    
    private var documentsAppDataDirectoryURL: URL {
        documentsDirectoryURL.appendingPathComponent("AppData", isDirectory: true)
    }
    
    private var documentsDDIDirectoryURL: URL {
        documentsDirectoryURL.appendingPathComponent("DDI", isDirectory: true)
    }
    
    private var applicationSupportAppDataDirectoryURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("AppData", isDirectory: true)
    }
    
    private var applicationSupportDDIDirectoryURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("DDI", isDirectory: true)
    }
    
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("文档目录不可用")
        }
        
        guard let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("应用支持目录不可用")
        }
        
        self.documentsDirectoryURL = documentsDirectoryURL
        self.applicationSupportDirectoryURL = applicationSupportDirectoryURL
    }
    
    func run() {
        migrateAppDataToApplicationSupport()
        migrateDDIToApplicationSupport()
        removeLegacyUserAgentOverride()
    }
    
    private func migrateAppDataToApplicationSupport() {
        let sourceURL = documentsAppDataDirectoryURL
        let destinationURL = applicationSupportAppDataDirectoryURL
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }
        
        do {
            try removeLegacyStoreFolders(in: sourceURL)
            try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            fatalError("应用数据迁移失败")
        }
        
        guard !fileManager.fileExists(atPath: sourceURL.path) else {
            fatalError("应用数据迁移失败")
        }
    }
    
    private func migrateDDIToApplicationSupport() {
        let sourceURL = documentsDDIDirectoryURL
        let destinationURL = applicationSupportDDIDirectoryURL
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }
        
        do {
            try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            fatalError("DDI 迁移失败")
        }
        
        guard !fileManager.fileExists(atPath: sourceURL.path) else {
            fatalError("DDI 迁移失败")
        }
    }
    
    private func removeLegacyUserAgentOverride() {
        try? fileManager.removeItem(
            at: documentsDirectoryURL.appendingPathComponent("ua-override.json", isDirectory: false)
        )
    }

    private func removeLegacyStoreFolders(in appDataDirectoryURL: URL) throws {
        for folderName in ["TabManagement", "Favicons"] {
            let folderURL = appDataDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
            if fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.removeItem(at: folderURL)
            }
        }
    }
}
