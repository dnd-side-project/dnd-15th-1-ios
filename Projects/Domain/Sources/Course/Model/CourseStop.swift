import Foundation

public struct CourseStop: Equatable, Identifiable, Sendable {
    public var id: String { place.id }
    public let place: Place

    public init(place: Place) {
        self.place = place
    }
}
