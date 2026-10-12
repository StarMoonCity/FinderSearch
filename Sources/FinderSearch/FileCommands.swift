import AppKit

/// User commands collect intent on the main actor; filesystem preparation runs in the background.
extension SearchModel {
    func reveal() { NSWorkspace.shared.activateFileViewerSelecting(selectedItems.map(\.url)) }
    func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false;
        panel.prompt = String(localized: "Open")
        if panel.runModal() == .OK, let url = panel.url { navigate(url) }
    }
    func goToFolder() {
        let alert = NSAlert(); alert.messageText = String(localized: "Go to Folder");
        alert.addButton(withTitle: String(localized: "Go"));
        alert.addButton(withTitle: String(localized: "Cancel"))
        let field = EditingTextField(string: location.path);
        field.frame = NSRect(x: 0, y: 0, width: 420, height: 24); alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            navigate(
                URL(
                    fileURLWithPath: (field.stringValue as NSString).expandingTildeInPath,
                    isDirectory: true))
        }
    }
    func invertSelection() {
        selection = Set(sortedHits.map(\.path)).subtracting(selection)
    }
    func openEnclosingFolder() {
        guard isBrowsing, location.path != "/" else { return }
        navigate(location.deletingLastPathComponent())
    }
    func rename() {
        guard !busy, let hit = selected, selection.count == 1 else { return }
        beginRename(hit)
    }
    func newFolder() {
        guard canWriteHere else { return }
        let folder = location
        prepareOperations(name: String(localized: "New Folder"), renameCreated: true) {
            [.folder(LocalFiles.availableName(in: folder, name: "untitled folder"))]
        }
    }
    func newTextFile() {
        guard canWriteHere else { return }
        let folder = location
        prepareOperations(name: String(localized: "New Text File"), renameCreated: true) {
            [.textFile(LocalFiles.availableName(in: folder, name: "untitled.txt"))]
        }
    }
    func duplicate() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        prepareOperations(name: String(localized: "Duplicate")) {
            try items.map {
                try Task.checkCancellation()
                return .copy(
                    $0.url,
                    LocalFiles.availableName(
                        in: $0.url.deletingLastPathComponent(), name: $0.name, suffix: " copy"))
            }
        }
    }
    func trash() {
        perform(selectedItems.map { .trash($0.url) }, name: String(localized: "Move to Trash"))
    }
    func copy(clipboard: FileClipboard? = nil) {
        (clipboard ?? .shared).write(selectedItems.map(\.url), cut: false)
    }
    func cut(clipboard: FileClipboard? = nil) {
        guard !busy else { return }
        (clipboard ?? .shared).write(selectedItems.map(\.url), cut: true)
    }
    func copyPath() {
        NSPasteboard.general.clearContents();
        NSPasteboard.general.setString(
            selectedItems.map(\.path).joined(separator: "\n"), forType: .string)
        FileClipboard.shared.refresh()
    }
    func copyFileName() {
        NSPasteboard.general.clearContents();
        NSPasteboard.general.setString(
            selectedItems.map(\.name).joined(separator: "\n"), forType: .string)
    }
    func paste(move: Bool = false, clipboard: FileClipboard? = nil) {
        guard canWriteHere, !busy else { return }
        let clipboard = clipboard ?? .shared
        let changeCount = clipboard.pasteboard.changeCount
        transfer(clipboard.urls, to: location, move: move || clipboard.isCut) { successful in
            clipboard.finish(successful, changeCount: changeCount)
        }
    }
    func info() {
        guard let hit = selected else { return }
        let folder = location
        Task {
            do {
                let details = try await BackgroundWork.run {
                    let item = try Hit.read(hit.url)
                    let tags = (try? hit.url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
                    return (item, tags)
                }
                guard location == folder else { return }
                let item = details.0
                let alert = NSAlert(); alert.messageText = item.name
                alert.informativeText =
                    String(
                        localized:
                            "Kind: \(item.typeName)\nSize: \(ByteCountFormatter.string(fromByteCount: Int64(clamping: item.size), countStyle: .file))\nModified: \(item.modified.formatted())\nWhere: \(item.parent)\nTags: \(details.1.joined(separator: ", "))"
                    )
                alert.addButton(withTitle: String(localized: "OK")); alert.runModal()
            } catch {
                if location == folder { self.error = error.localizedDescription }
            }
        }
    }
    func tag(_ name: String) {
        let items = selectedItems
        guard !items.isEmpty else { return }
        prepareOperations(name: String(localized: "Tags")) {
            try items.map { hit in
                try Task.checkCancellation()
                var tags = FileTag.read(hit.url)
                if tags.contains(where: { $0.name == name }) {
                    tags.removeAll { $0.name == name }
                } else {
                    tags.append(FileTag(name: name, color: FileTag.color(for: name)))
                }
                return .tags(hit.url, tags.map(\.storageValue))
            }
        }
    }
}

/// Recursive byte totals for the details pane and selection summary.
/// Symlinks are not followed, so directory cycles cannot loop.
/// Large trees are slow — callers must run this off the main actor.
enum FolderSize {
    static func total(_ urls: [URL]) -> Int64 { urls.reduce(0) { $0 + total($1) } }
    static func total(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        // Enumerators reject plain files, and a symlink root is never followed.
        if values.isDirectory != true || values.isSymbolicLink == true {
            return Int64(values.fileSize ?? 0)
        }
        var total: Int64 = 0
        guard
            let walker = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: Array(keys))
        else { return 0 }
        for case let item as URL in walker {
            // A cancelled walk still returns what it counted; callers only need a total.
            if Task.isCancelled { return total }
            guard let values = try? item.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true { walker.skipDescendants(); continue }
            if values.isDirectory != true { total += Int64(values.fileSize ?? 0) }
        }
        return total
    }
}
