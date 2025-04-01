// based on https://github.com/JaviSoto/RubikSwift

public struct Cube: Hashable, Sendable {
    public var edges: EdgePieceCollection
    public var corners: CornerPieceCollection

    public static let solved = Cube()

    public init(
        edges: EdgePieceCollection = .solved,
        corners: CornerPieceCollection = .solved
    ) {
        self.edges = edges
        self.corners = corners
    }
}

public enum Face: Int, CaseIterable, Sendable {
    case top
    case right
    case front
    case bottom
    case left
    case back
}

public struct EdgePiece: Hashable, Sendable {
    public enum Location: Int, CaseIterable, Sendable {
        case topRight
        case topFront
        case topLeft
        case topBack
        case bottomRight
        case bottomFront
        case bottomLeft
        case bottomBack
        case middleRightFront
        case middleLeftFront
        case middleLeftBack
        case middleRightBack

        public var keyPath: WritableKeyPath<EdgePieceCollection, EdgePiece> {
            switch self {
            case .topRight: \.topRight
            case .topFront: \.topFront
            case .topLeft: \.topLeft
            case .topBack: \.topBack
            case .middleRightFront: \.middleRightFront
            case .middleLeftFront: \.middleLeftFront
            case .middleLeftBack: \.middleLeftBack
            case .middleRightBack: \.middleRightBack
            case .bottomRight: \.bottomRight
            case .bottomFront: \.bottomFront
            case .bottomLeft: \.bottomLeft
            case .bottomBack: \.bottomBack
            }
        }
    }

    public enum Orientation: Int, CaseIterable, Sendable {
        case correct
        case flipped
    }

    public var location: Location
    public var orientation: Orientation

    public init(_ location: Location, orientation: Orientation = .correct) {
        self.location = location
        self.orientation = orientation
    }
}

public typealias EdgeLocation = EdgePiece.Location

public struct CornerPiece: Hashable, Sendable {
    public enum Location: Int, CaseIterable, Sendable {
        case topRightFront
        case topLeftFront
        case topLeftBack
        case topRightBack
        case bottomRightFront
        case bottomLeftFront
        case bottomLeftBack
        case bottomRightBack

        public var keyPath: WritableKeyPath<CornerPieceCollection, CornerPiece> {
            switch self {
            case .topRightFront: \.topRightFront
            case .topLeftFront: \.topLeftFront
            case .topLeftBack: \.topLeftBack
            case .topRightBack: \.topRightBack
            case .bottomRightFront: \.bottomRightFront
            case .bottomLeftFront: \.bottomLeftFront
            case .bottomLeftBack: \.bottomLeftBack
            case .bottomRightBack: \.bottomRightBack
            }
        }
    }

    public enum Orientation: Int, CaseIterable, Sendable {
        case correct
        case rotatedClockwise
        case rotatedCounterClockwise
    }

    public var location: Location
    public var orientation: Orientation

    public init(_ location: Location, orientation: Orientation = .correct) {
        self.location = location
        self.orientation = orientation
    }
}

public typealias CornerLocation = CornerPiece.Location

public struct EdgePieceCollection: Hashable, Sendable {
    public var topRight: EdgePiece
    public var topFront: EdgePiece
    public var topLeft: EdgePiece
    public var topBack: EdgePiece
    public var bottomRight: EdgePiece
    public var bottomFront: EdgePiece
    public var bottomLeft: EdgePiece
    public var bottomBack: EdgePiece
    public var middleRightFront: EdgePiece
    public var middleLeftFront: EdgePiece
    public var middleLeftBack: EdgePiece
    public var middleRightBack: EdgePiece

    public subscript(location: EdgeLocation) -> EdgePiece {
        get { self[keyPath: location.keyPath] }
        set { self[keyPath: location.keyPath] = newValue }
    }

    public var all: [EdgePiece] {
        get {
            EdgeLocation.allCases.map { self[$0] }
        }
        set {
            assert(EdgeLocation.allCases.count == newValue.count)
            for (location, value) in zip(EdgeLocation.allCases, newValue) {
                self[location] = value
            }
        }
    }

    public static let solved = EdgePieceCollection(
        topRight: EdgePiece(.topRight),
        topFront: EdgePiece(.topFront),
        topLeft: EdgePiece(.topLeft),
        topBack: EdgePiece(.topBack),
        bottomRight: EdgePiece(.bottomRight),
        bottomFront: EdgePiece(.bottomFront),
        bottomLeft: EdgePiece(.bottomLeft),
        bottomBack: EdgePiece(.bottomBack),
        middleRightFront: EdgePiece(.middleRightFront),
        middleLeftFront: EdgePiece(.middleLeftFront),
        middleLeftBack: EdgePiece(.middleLeftBack),
        middleRightBack: EdgePiece(.middleRightBack)
    )
}

public struct CornerPieceCollection: Hashable, Sendable {
    public var topRightFront: CornerPiece
    public var topLeftFront: CornerPiece
    public var topLeftBack: CornerPiece
    public var topRightBack: CornerPiece
    public var bottomRightFront: CornerPiece
    public var bottomLeftFront: CornerPiece
    public var bottomLeftBack: CornerPiece
    public var bottomRightBack: CornerPiece

    public subscript(location: CornerLocation) -> CornerPiece {
        get { self[keyPath: location.keyPath] }
        set { self[keyPath: location.keyPath] = newValue }
    }

    public var all: [CornerPiece] {
        get {
            CornerLocation.allCases.map { self[$0] }
        }
        set {
            assert(CornerLocation.allCases.count == newValue.count)
            for (location, value) in zip(CornerLocation.allCases, newValue) {
                self[location] = value
            }
        }
    }

    public static let solved = CornerPieceCollection(
        topRightFront: CornerPiece(.topRightFront),
        topLeftFront: CornerPiece(.topLeftFront),
        topLeftBack: CornerPiece(.topLeftBack),
        topRightBack: CornerPiece(.topRightBack),
        bottomRightFront: CornerPiece(.bottomRightFront),
        bottomLeftFront: CornerPiece(.bottomLeftFront),
        bottomLeftBack: CornerPiece(.bottomLeftBack),
        bottomRightBack: CornerPiece(.bottomRightBack)
    )
}

extension EdgeLocation {
    // reference facelet first, then other
    public var faces: [Face] {
        switch self {
        case .topRight: [.top, .right]
        case .topFront: [.top, .front]
        case .topLeft: [.top, .left]
        case .topBack: [.top, .back]
        case .bottomRight: [.bottom, .right]
        case .bottomFront: [.bottom, .front]
        case .bottomLeft: [.bottom, .left]
        case .bottomBack: [.bottom, .back]
        case .middleRightFront: [.front, .right]
        case .middleLeftFront: [.front, .left]
        case .middleLeftBack: [.back, .left]
        case .middleRightBack: [.back, .right]
        }
    }
}

extension CornerLocation {
    // reference facelet first, then clockwise
    public var faces: [Face] {
        switch self {
        case .topRightFront: [.top, .right, .front]
        case .topLeftFront: [.top, .front, .left]
        case .topLeftBack: [.top, .left, .back]
        case .topRightBack: [.top, .back, .right]
        case .bottomRightFront: [.bottom, .front, .right]
        case .bottomLeftFront: [.bottom, .left, .front]
        case .bottomLeftBack: [.bottom, .back, .left]
        case .bottomRightBack: [.bottom, .right, .back]
        }
    }
}

extension Face: CustomStringConvertible {
    public var description: String {
        switch self {
        case .top: return "U"
        case .bottom: return "D"
        case .left: return "L"
        case .right: return "R"
        case .front: return "F"
        case .back: return "B"
        }
    }
}

extension Face: LosslessStringConvertible {
    public init?(_ string: String) {
        switch string {
        case "U": self = .top
        case "D": self = .bottom
        case "L": self = .left
        case "R": self = .right
        case "F": self = .front
        case "B": self = .back
        default: return nil
        }
    }
}
