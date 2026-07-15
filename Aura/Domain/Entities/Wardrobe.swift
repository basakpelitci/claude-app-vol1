import Foundation

public enum WardrobeCategory: String, Codable, CaseIterable, Sendable {
    case outfit
    case dress
    case jeans
    case jacket
    case shoes
    case accessory
    case top
    case skirt
    case other
}

/// How close the item is to fitting. Progresses only forward in celebration
/// copy; regression is never called out.
public enum FitStatus: String, Codable, CaseIterable, Sendable {
    case dream
    case closer
    case almostFits
    case fits

    public var displayName: String {
        switch self {
        case .dream:      return "The dream"
        case .closer:     return "Getting closer"
        case .almostFits: return "Almost fits"
        case .fits:       return "It fits!"
        }
    }
}

public struct WardrobeCollection: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var emoji: String?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        emoji: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WardrobeItem: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var collectionID: UUID?
    public var title: String
    public var category: WardrobeCategory
    public var imageData: Data?
    public var targetSize: String
    public var currentSize: String?
    public var notes: String
    public var isWishlist: Bool
    public var fitStatus: FitStatus
    public var pinnedToDashboard: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        collectionID: UUID? = nil,
        title: String,
        category: WardrobeCategory,
        imageData: Data? = nil,
        targetSize: String,
        currentSize: String? = nil,
        notes: String = "",
        isWishlist: Bool = false,
        fitStatus: FitStatus = .dream,
        pinnedToDashboard: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.category = category
        self.imageData = imageData
        self.targetSize = targetSize
        self.currentSize = currentSize
        self.notes = notes
        self.isWishlist = isWishlist
        self.fitStatus = fitStatus
        self.pinnedToDashboard = pinnedToDashboard
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
