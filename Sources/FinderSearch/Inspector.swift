import SwiftUI
import AppKit

/// Windows-style right-side panes: a live preview and file details.
/// Both panes are independent toggles and share one column.
struct BrowserInspector: View {
    @ObservedObject var model: SearchModel
    let showPreview: Bool
    let showDetails: Bool
    var body: some View {
        if showPreview || showDetails {
            VStack(spacing: 0) {
                Divider()
                if showPreview { PreviewPane(model: model) }
                if showPreview && showDetails { Divider() }
                if showDetails { DetailsPane(model: model) }
            }
            .frame(width: 260)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

private struct PreviewPane: View {
    @ObservedObject var model: SearchModel
    var body: some View {
        Group {
            if let hit = model.selected {
                VStack(spacing: 8) {
                    QuickLook(url: hit.url)
                        .frame(minHeight: 220)
                        .frame(maxHeight: .infinity)
                        .id(hit.path)
                    Text(hit.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                ContentUnavailableView(
                    String(localized: "No Selection"), systemImage: "eye.slash")
            }
        }.padding(10)
    }
}

struct FileDetails: Sendable {
    let size: Int64
    let created: Date?
    let tags: [String]
}

private struct DetailsPane: View {
    @ObservedObject var model: SearchModel
    @State private var details: FileDetails?
    /// Single-selection rows follow the selected item; the multi-selection
    /// summary only needs the model's cached total.
    private var hit: Hit? { model.selection.count == 1 ? model.selected : nil }
    private var identity: String { hit?.path ?? "" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.selection.isEmpty ? model.title : hit?.name ?? "")
                    .font(.headline).lineLimit(2)
                rows
                Spacer(minLength: 0)
            }.padding(10)
        }
        .task(id: identity) { await load() }
    }
    @ViewBuilder private var rows: some View {
        if let hit {
            row(String(localized: "Kind"), hit.typeName)
            row(
                String(localized: "Size"),
                details.map { ByteCountFormatter.string(fromByteCount: $0.size, countStyle: .file) }
                    ?? "—")
            row(
                String(localized: "Created"),
                details?.created?.formatted() ?? "—")
            row(String(localized: "Modified"), hit.modified.formatted())
            row(String(localized: "Where"), hit.parent)
            row(
                String(localized: "Tags"),
                details.map { $0.tags.isEmpty ? "—" : $0.tags.joined(separator: ", ") } ?? "—")
        } else if !model.selection.isEmpty {
            row(String(localized: "Items"), "\(model.selection.count)")
            row(
                String(localized: "Total Size"),
                model.selectionSize.map {
                    ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
                } ?? "—")
        } else {
            row(String(localized: "Items"), "\(model.sortedHits.count)")
            row(String(localized: "Where"), model.location.path)
        }
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).multilineTextAlignment(.trailing)
        }.font(.caption).textSelection(.enabled)
    }
    private func load() async {
        guard let hit else { details = nil; return }
        let loaded: FileDetails? = await Task.detached(priority: .userInitiated) {
            let values = try? hit.url.resourceValues(forKeys: [.creationDateKey, .tagNamesKey])
            let size =
                hit.isFolder
                ? FolderSize.total(hit.url)
                : Int64(clamping: hit.size)
            return FileDetails(
                size: size, created: values?.creationDate, tags: values?.tagNames ?? [])
        }.value
        guard !Task.isCancelled else { return }
        details = loaded
    }
}
