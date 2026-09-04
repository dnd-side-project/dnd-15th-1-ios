import Foundation

public struct MapPinChange: Equatable {
    public var added: [MapPin]
    public var removedIDs: [String]
    public var moved: [MapPin]
    public var restyled: [MapPin]

    public init(
        added: [MapPin],
        removedIDs: [String],
        moved: [MapPin],
        restyled: [MapPin]
    ) {
        self.added = added
        self.removedIDs = removedIDs
        self.moved = moved
        self.restyled = restyled
    }
}

public enum MapPinDiff {
    public static func change(
        from applied: [MapPin],
        to desired: [MapPin]
    ) -> MapPinChange {
        let appliedByID = Dictionary(
            applied.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )
        let desiredByID = Dictionary(
            desired.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )

        var added: [MapPin] = []
        var moved: [MapPin] = []
        var restyled: [MapPin] = []

        for marker in desired {
            guard let previous = appliedByID[marker.id] else {
                added.append(marker)
                continue
            }
            if previous.styleID != marker.styleID || previous.rank != marker.rank {
                restyled.append(marker)
            }
            if previous.coordinate != marker.coordinate {
                moved.append(marker)
            }
        }

        let removedIDs = applied
            .map(\.id)
            .filter { desiredByID[$0] == nil }

        return MapPinChange(
            added: added,
            removedIDs: removedIDs,
            moved: moved,
            restyled: restyled
        )
    }
}
