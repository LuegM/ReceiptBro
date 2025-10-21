//
//  Logger+Extensions.swift
//  CampusPlus
//
//  Created by Michael Luegmayer on 10.02.2025.
//

import OSLog

extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like a view that appeared.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let foundationModel = Logger(subsystem: subsystem, category: "foundationModel")
    static let database = Logger(subsystem: subsystem, category: "database")

    static let userInterface = Logger(subsystem: subsystem, category: "ui")
    static let calendarManagement = Logger(subsystem: subsystem, category: "calendarManagement")

    static let authentication = Logger(subsystem: subsystem, category: "authentication")
    static let userEvents = Logger(subsystem: subsystem, category: "userevents")
    static let configuration = Logger(subsystem: subsystem, category: "configuration")

    // static let errorHandling = Logger(subsystem: subsystem, category: "errorhandling")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let fileManagement = Logger(subsystem: subsystem, category: "filemanagement")

    static let backgroundProcessing = Logger(subsystem: subsystem, category: "backgroundprocessing")
    static let fileImport = Logger(subsystem: subsystem, category: "fileImport")

    /// All logs related to tracking and analytics.
    static let statistics = Logger(subsystem: subsystem, category: "statistics")
    
    static let ocr = Logger(subsystem: subsystem, category: "OCR")
    static let extraction = Logger(subsystem: subsystem, category: "Extraction")
    static let scanning = Logger(subsystem: subsystem, category: "Scanning")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let ui = Logger(subsystem: subsystem, category: "UI")
//    static let defaults = Logger(subsystem: subsystem, category: "defaults")
}
