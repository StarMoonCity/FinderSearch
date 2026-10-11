import SwiftUI
import AppKit

enum SidebarTags {
    static let values: [(String, Color)] = [
        ("Red", .red), ("Orange", .orange), ("Yellow", .yellow), ("Green", .green),
        ("Blue", .blue), ("Purple", .purple), ("Gray", .gray),
    ]
}

/// Folder results and loading phases have no bearing on sidebar content.
struct SidebarState: Equatable {
    let selection: String?
    let favorites: [String]
    let volumes: [MountedVolume]
    let ejectingVolumes: Set<String>
    let showDiskAccessHint: Bool

    init(
        route: String, favorites: [String], volumes: [MountedVolume], ejectingVolumes: Set<String>,
        showDiskAccessHint: Bool
    ) {
        let home = NSHomeDirectory()
        let special = ["recents"] + SidebarTags.values.map { "tag:" + $0.0 }
        let folderRoutes =
            [
                "/Applications", home,
                home + "/Library/Mobile Documents/com~apple~CloudDocs",
            ]
            + ["Documents", "Downloads", "Desktop", "Pictures", "Music", "Movies"].map {
                home + "/" + $0
            }
            + favorites + volumes.map(\.id)
        if special.contains(route) {
            selection = route
        } else if folderRoutes.contains(route) {
            selection = route
        } else {
            // A child of a sidebar folder highlights its nearest sidebar
            // ancestor, so navigation never loses the sidebar's place.
            selection = folderRoutes.filter { route.hasPrefix($0 + "/") }
                .max(by: { $0.count < $1.count })
        }
        self.favorites = favorites
        self.volumes = volumes
        self.ejectingVolumes = ejectingVolumes
        self.showDiskAccessHint = showDiskAccessHint
    }
}

struct BrowserSidebar: View, Equatable {
    let state: SidebarState
    let select: (String) -> Void
    let removeFavorite: (String) -> Void
    let eject: (MountedVolume) -> Void
    private let home = NSHomeDirectory()

    static func == (lhs: Self, rhs: Self) -> Bool {
        // Callbacks target the same browser and workspace for this view's lifetime;
        // the browser's identity changes when switching tabs.
        lhs.state == rhs.state
    }

    var body: some View {
        List(
            selection: Binding<String?>(
                get: { state.selection },
                set: { if let route = $0 { select(route) } }
            )
        ) {
            Label("Recents", systemImage: "clock").tag("recents")
            Section("Favorites") {
                row(String(localized: "Applications"), "a.square", "/Applications")
                row(String(localized: "Documents"), "doc", home + "/Documents")
                row(String(localized: "Downloads"), "arrow.down.circle", home + "/Downloads")
                row(String(localized: "Desktop"), "menubar.dock.rectangle", home + "/Desktop")
                row(String(localized: "Pictures"), "photo", home + "/Pictures")
                row(String(localized: "Music"), "music.note", home + "/Music")
                row(String(localized: "Movies"), "film", home + "/Movies")
                ForEach(state.favorites, id: \.self) { path in
                    row((path as NSString).lastPathComponent, "folder", path)
                        .contextMenu {
                            Button("Remove from Sidebar") { removeFavorite(path) }
                        }
                }
            }
            Section("Locations") {
                row(
                    String(localized: "iCloud Drive"), "icloud",
                    home + "/Library/Mobile Documents/com~apple~CloudDocs"
                )
                row((home as NSString).lastPathComponent, "house", home)
                ForEach(state.volumes) { volume in
                    HStack {
                        Label(volume.name, systemImage: "externaldrive")
                        Spacer(minLength: 4)
                        if volume.canEject {
                            Button {
                                eject(volume)
                            } label: {
                                Image(systemName: "eject.fill").font(.system(size: 11))
                                    .foregroundStyle(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.borderless)
                            .disabled(state.ejectingVolumes.contains(volume.id))
                            .help("Eject \(volume.name)")
                            .accessibilityLabel(String(localized: "Eject \(volume.name)"))
                        }
                    }.tag(volume.id)
                }
            }
            Section("Tags") {
                ForEach(SidebarTags.values, id: \.0) { name, color in
                    Label {
                        Text(name)
                    } icon: {
                        Image(systemName: "circle.fill").font(.system(size: 10))
                            .foregroundStyle(color)
                    }.tag("tag:" + name)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 208, max: 280)
        .safeAreaInset(edge: .bottom) {
            if state.showDiskAccessHint {
                Button("Enable Full Disk Access…") {
                    NSWorkspace.shared.open(
                        URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
                        )!)
                }.font(.caption).padding(12)
            }
        }
    }

    private func row(_ name: String, _ symbol: String, _ path: String) -> some View {
        Label(name, systemImage: symbol).tag(path)
    }
}
