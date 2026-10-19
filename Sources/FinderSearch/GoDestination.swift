import SwiftUI

enum GoDestination: String, CaseIterable, Identifiable {
    case recents, documents, desktop, downloads, home, library, applications, utilities
    var id: Self { self }
    var title: String {
        switch self {
        case .recents: String(localized: "Recents")
        case .documents: String(localized: "Documents")
        case .desktop: String(localized: "Desktop")
        case .downloads: String(localized: "Downloads")
        case .home: String(localized: "Home")
        case .library: String(localized: "Library")
        case .applications: String(localized: "Applications")
        case .utilities: String(localized: "Utilities")
        }
    }
    var key: Character {
        switch self {
        case .recents: "f"
        case .documents: "o"
        case .desktop: "d"
        case .downloads, .library: "l"
        case .home: "h"
        case .applications: "a"
        case .utilities: "u"
        }
    }
    var modifiers: EventModifiers {
        self == .downloads ? [.command, .option] : [.command, .shift]
    }
    var route: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .recents: return "recents"
        case .documents: return home + "/Documents"
        case .desktop: return home + "/Desktop"
        case .downloads: return home + "/Downloads"
        case .home: return home
        case .library: return home + "/Library"
        case .applications: return "/Applications"
        case .utilities: return "/Applications/Utilities"
        }
    }
}
