import XCTest
@testable import DDEVKit

final class DDEVListParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_parse_realFixture_returnsProjects() throws {
        let projects = try DDEVListParser.parse(fixture("ddev-list.jsonl"))
        XCTAssertFalse(projects.isEmpty)
        let first = try XCTUnwrap(projects.first)
        XCTAssertFalse(first.name.isEmpty)
        XCTAssertFalse(first.approot.isEmpty)
    }

    func test_parse_sortsByNameCaseInsensitively() throws {
        let projects = try DDEVListParser.parse(fixture("ddev-list.jsonl"))
        let names = projects.map(\.name)
        XCTAssertEqual(names, names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    func test_parse_emptyRaw_returnsEmptyArray() throws {
        XCTAssertEqual(try DDEVListParser.parse(fixture("ddev-list-empty.jsonl")).count, 0)
    }

    func test_parse_garbage_throws() {
        XCTAssertThrowsError(try DDEVListParser.parse("not json at all"))
    }
}
