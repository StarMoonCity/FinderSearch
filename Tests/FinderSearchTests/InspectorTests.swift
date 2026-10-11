import XCTest
@testable import FinderSearch

final class InspectorTests: XCTestCase {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("FinderSearch-inspector-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testFolderSizeSumsNestedFilesAndSkipsSymlinkCycles() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("12345".utf8).write(to: root.appendingPathComponent("a.txt"))
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
        try Data("1234567890".utf8).write(to: nested.appendingPathComponent("b.txt"))
        // A link back to the root must neither loop nor double-count.
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("loop"), withDestinationURL: root)
        XCTAssertEqual(FolderSize.total(root), 15)
        XCTAssertEqual(FolderSize.total(root.appendingPathComponent("a.txt")), 5)
        XCTAssertEqual(FolderSize.total([root.appendingPathComponent("a.txt"), nested]), 15)
    }

    @MainActor func testInvertSelectionTogglesAgainstVisibleRows() {
        let model = SearchModel()
        model.hits = ["a", "b", "c", "d"].map {
            Hit(path: "/fixture/\($0)", kind: "file", size: 0, mtime: 0, score: 0)
        }
        model.selection = ["/fixture/a", "/fixture/c"]
        model.invertSelection()
        XCTAssertEqual(model.selection, ["/fixture/b", "/fixture/d"])
        // Inverting again restores the original pair.
        model.invertSelection()
        XCTAssertEqual(model.selection, ["/fixture/a", "/fixture/c"])
    }
}
