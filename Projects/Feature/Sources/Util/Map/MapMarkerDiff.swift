import Foundation

public struct MapMarkerChange: Equatable, Sendable {
    public var added: [MapMarker]
    public var removedIDs: [String]
    public var moved: [MapMarker]
    public var restyled: [MapMarker]

    public init(
        added: [MapMarker],
        removedIDs: [String],
        moved: [MapMarker],
        restyled: [MapMarker]
    ) {
        self.added = added
        self.removedIDs = removedIDs
        self.moved = moved
        self.restyled = restyled
    }
}

public enum MapMarkerDiff {
    public static func change(
        from applied: [MapMarker],
        to desired: [MapMarker]
    ) -> MapMarkerChange {
        let appliedByID = Dictionary(
            applied.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )
        let desiredByID = Dictionary(
            desired.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )

        var added: [MapMarker] = []
        var moved: [MapMarker] = []
        var restyled: [MapMarker] = []

        for marker in desired {
            guard let previous = appliedByID[marker.id] else {
                added.append(marker)
                continue
            }
            if previous.kind != marker.kind {
                restyled.append(marker)
            }
            if previous.coordinate != marker.coordinate {
                moved.append(marker)
            }
        }

        let removedIDs = applied
            .map(\.id)
            .filter { desiredByID[$0] == nil }

        return MapMarkerChange(
            added: added,
            removedIDs: removedIDs,
            moved: moved,
            restyled: restyled
        )
    }
}
