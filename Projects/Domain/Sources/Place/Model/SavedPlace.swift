import Foundation

public struct SavedPlace: Equatable, Identifiable, Sendable {
    public var id: String { place.id }
    public let place: Place
    public let ownership: PlaceOwnership
    public let alias: String?
    public let memo: String?
    public let savedAt: Date?

    public init(
        place: Place,
        ownership: PlaceOwnership,
        alias: String?,
        memo: String?,
        savedAt: Date?
    ) {
        self.place = place
        self.ownership = ownership
        self.alias = alias
        self.memo = memo
        self.savedAt = savedAt
    }
}
