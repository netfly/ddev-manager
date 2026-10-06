import XCTest
@testable import DDEVKit

final class DDEVStatusSortRankTests: XCTestCase {
    func test_sortRank_isMonotonicInExpectedOrder() {
        let ordered: [DDEVStatus] = [.running, .starting, .paused, .stopped, .unknown("weird")]
        let ranks = ordered.map(\.sortRank)
        XCTAssertEqual(ranks, ranks.sorted())
        XCTAssertEqual(Set(ranks).count, ranks.count, "ranks should be distinct")
    }

    func test_sortingProjectsByStatus_putsRunningFirst() {
        let names = ["z-stopped", "a-running", "m-paused"]
        let statuses: [DDEVStatus] = [.stopped, .running, .paused]
        let pairs = zip(names, statuses).sorted {
            $0.1.sortRank != $1.1.sortRank ? $0.1.sortRank < $1.1.sortRank
                : $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending
        }
        XCTAssertEqual(pairs.map(\.0), ["a-running", "m-paused", "z-stopped"])
    }
}
