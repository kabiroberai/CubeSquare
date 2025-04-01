public struct Move: Sendable, Hashable {
    public enum Magnitude: Sendable, Hashable {
        case clockwiseQuarterTurn
        case halfTurn
        case counterClockwiseQuarterTurn

        fileprivate static let all: [Magnitude] = [.clockwiseQuarterTurn, .halfTurn, .counterClockwiseQuarterTurn]

        fileprivate var inverse: Magnitude {
            switch self {
            case .clockwiseQuarterTurn: return .counterClockwiseQuarterTurn
            case .counterClockwiseQuarterTurn: return .clockwiseQuarterTurn
            case .halfTurn: return .halfTurn
            }
        }
    }

    public var face: Face
    public var magnitude: Magnitude

    public init(face: Face, magnitude: Magnitude = .clockwiseQuarterTurn) {
        self.face = face
        self.magnitude = magnitude
    }

    public var inverse: Move {
        return Move(face: self.face, magnitude: self.magnitude.inverse)
    }
}

public struct MoveSeries: Sendable {
    public var values: [Move]

    public init(values: [Move]) {
        self.values = values
    }

    public func inverse() -> MoveSeries {
        MoveSeries(values: values.reversed().map(\.inverse))
    }
}

extension Cube {
    public mutating func apply(_ move: Move) {
        self.apply([move])
    }

    public mutating func apply(_ moves: [Move]) {
        // Handle half turns as 2 clockwise turns
        let effectiveMoves = moves.flatMap { move -> [Move] in
            var move = move

            if move.magnitude == .halfTurn {
                move = Move(face: move.face, magnitude: .clockwiseQuarterTurn)

                return [move, move]
            }
            else {
                return [move]
            }
        }

        for move in effectiveMoves {
            precondition(move.magnitude != .halfTurn)

            let shouldFlipEdges = move.face.quarterTurnAffectsEdgeOrientation

            // 1. Alter orientation
            if shouldFlipEdges {
                self.flipEdges(in: move.face)
            }

            let clockwiseTurn = move.magnitude == .clockwiseQuarterTurn

            self.rotateCorners(in: move.face)

            // 2. Permute
            self.permutatePieces(in: move.face, clockwise: clockwiseTurn)
        }
    }

    public mutating func apply(_ moves: MoveSeries) {
        apply(moves.values)
    }

    public func applying(_ moves: [Move]) -> Cube {
        var cube = self
        cube.apply(moves)
        return cube
    }

    public func applying(_ moves: MoveSeries) -> Cube {
        applying(moves.values)
    }
}

// These are based on Kociemba's definition of orientation
// https://web.archive.org/web/20220124065317/https://kociemba.org/math/cubielevel.htm
extension Face {
    fileprivate var quarterTurnAffectsEdgeOrientation: Bool {
        switch self {
        case .top, .bottom: return false
        case .left, .right: return false
        case .front, .back: return true
        }
    }

    fileprivate func cornerOrientationChangeAfterClockwiseTurn(in location: CornerLocation) -> CornerPiece.Orientation {
        switch self {
        case .top, .bottom: return .correct
        case .front:
            switch location {
            case .topRightFront, .bottomLeftFront: return .rotatedCounterClockwise
            case .topLeftFront, .bottomRightFront: return .rotatedClockwise
            default: fatalError("Invalid location for the front face")
            }
        case .back:
            switch location {
            case .topRightBack, .bottomLeftBack: return .rotatedClockwise
            case .topLeftBack, .bottomRightBack: return .rotatedCounterClockwise
            default: fatalError("Invalid location for the back face")
            }
        case .left:
            switch location {
            case .topLeftFront, .bottomLeftBack: return .rotatedCounterClockwise
            case .topLeftBack, .bottomLeftFront: return .rotatedClockwise
            default: fatalError("Invalid location for the left face")
            }
        case .right:
            switch location {
            case .topRightFront, .bottomRightBack: return .rotatedClockwise
            case .topRightBack, .bottomRightFront: return .rotatedCounterClockwise
            default: fatalError("Invalid location for the right face")
            }
        }
    }
}

extension Cube {
    fileprivate mutating func flipEdges(in face: Face) {
        self.edges.map(face) { $1.flipped }
    }

    fileprivate mutating func rotateCorners(in face: Face) {
        self.corners.map(face) { (location: CornerLocation, corner: CornerPiece) -> CornerPiece in
            let rotation = face.cornerOrientationChangeAfterClockwiseTurn(in: location)

            return corner + rotation
        }
    }

    fileprivate mutating func permutatePieces(in face: Face, clockwise: Bool) {
        var rotated = self

        // This relies on the fact that the locations are returned in clockwise order
        var edgeLocations = EdgeLocation.locations(in: face)
        var cornerLocations = CornerLocation.locations(in: face)

        if !clockwise {
            edgeLocations.reverse()
            cornerLocations.reverse()
        }

        for (index, edgeLocation) in edgeLocations.enumerated() {
            let location = edgeLocations[(index + 1) % edgeLocations.count]
            rotated.edges[location] = self.edges[edgeLocation]
        }

        for (index, cornerLocation) in cornerLocations.enumerated() {
            let location = cornerLocations[(index + 1) % cornerLocations.count]
            rotated.corners[location] = self.corners[cornerLocation]
        }

        self = rotated
    }
}

extension Move.Magnitude: CustomStringConvertible {
    public var description: String {
        switch self {
        case .clockwiseQuarterTurn: return ""
        case .counterClockwiseQuarterTurn: return "'"
        case .halfTurn: return "2"
        }
    }
}

extension Move: LosslessStringConvertible {
    public init?(_ string: some StringProtocol) {
        guard string.count <= 2,
              let firstCharacter = string.first,
              let face = Face("\(firstCharacter)")
              else { return nil }

        let magnitude: Magnitude

        if string.count > 1 {
            switch string.last {
            case .none: magnitude = .clockwiseQuarterTurn
            case .some("'"): magnitude = .counterClockwiseQuarterTurn
            case .some("2"): magnitude = .halfTurn
            default: return nil
            }
        } else {
            magnitude = .clockwiseQuarterTurn
        }

        self = Move(face: face, magnitude: magnitude)
    }
}

extension MoveSeries: LosslessStringConvertible {
    public init?(_ description: some StringProtocol) {
        guard let moves = description.split(separator: " ").map({ Move($0) }) as? [Move]
              else { return nil }
        self.values = moves
    }

    public var description: String {
        values.map { "\($0)" }.joined(separator: " ")
    }
}

extension Move: CustomStringConvertible {
    public var description: String {
        return "\(self.face)\(self.magnitude)"
    }
}

public prefix func !(orientation: EdgePiece.Orientation) -> EdgePiece.Orientation {
    switch orientation {
    case .correct: return .flipped
    case .flipped: return .correct
    }
}

extension EdgePiece {
    fileprivate mutating func flip() {
        self.orientation = !self.orientation
    }

    fileprivate var flipped: EdgePiece {
        var piece = self
        piece.flip()

        return piece
    }
}

public func +(lhs: CornerPiece.Orientation, rhs: CornerPiece.Orientation) -> CornerPiece.Orientation {
    switch (lhs, rhs) {
    case (.correct, .correct): return .correct
    case (.correct, .rotatedClockwise), (.rotatedClockwise, .correct): return .rotatedClockwise
    case (.correct, .rotatedCounterClockwise), (.rotatedCounterClockwise, .correct): return .rotatedCounterClockwise
    case (.rotatedClockwise, .rotatedCounterClockwise), (.rotatedCounterClockwise, .rotatedClockwise): return .correct
    case (.rotatedClockwise, .rotatedClockwise): return .rotatedCounterClockwise
    case (.rotatedCounterClockwise, .rotatedCounterClockwise): return .rotatedClockwise
    }
}

public prefix func !(orientation: CornerPiece.Orientation) -> CornerPiece.Orientation {
    switch orientation {
    case .correct: return .correct
    case .rotatedClockwise: return .rotatedCounterClockwise
    case .rotatedCounterClockwise: return .rotatedClockwise
    }
}

public func -(lhs: CornerPiece.Orientation, rhs: CornerPiece.Orientation) -> CornerPiece.Orientation {
    return lhs + !rhs
}

public func +(lhs: CornerPiece, rhs: CornerPiece.Orientation) -> CornerPiece {
    return CornerPiece(lhs.location, orientation: lhs.orientation + rhs)
}

public func -(lhs: CornerPiece, rhs: CornerPiece.Orientation) -> CornerPiece {
    return CornerPiece(lhs.location, orientation: lhs.orientation - rhs)
}

extension EdgeLocation {
    // Sorted clockwise
    fileprivate static func locations(in face: Face) -> [EdgeLocation] {
        switch face {
        case .top: [.topRight, .topFront, .topLeft, .topBack]
        case .bottom: [.bottomFront, .bottomRight, .bottomBack, .bottomLeft]
        case .left: [.topLeft, .middleLeftFront, .bottomLeft, .middleLeftBack]
        case .right: [.topRight, .middleRightBack, .bottomRight, .middleRightFront]
        case .front: [.topFront, .middleRightFront, .bottomFront, .middleLeftFront]
        case .back: [.topBack, .middleLeftBack, .bottomBack, .middleRightBack]
        }
    }
}

extension EdgePieceCollection {
    fileprivate mutating func map(_ face: Face, _ f: (EdgeLocation, EdgePiece) -> EdgePiece) {
        for location in EdgeLocation.locations(in: face) {
            let piece = self[location]
            let newPiece = f(location, piece)

            if newPiece != piece {
                self[location] = newPiece
            }
        }
    }
}

extension CornerLocation {
    // Sorted clockwise
    fileprivate static func locations(in face: Face) -> [CornerLocation] {
        switch face {
        case .top: [.topRightFront, .topLeftFront, .topLeftBack, .topRightBack]
        case .bottom: [.bottomLeftFront, .bottomRightFront, .bottomRightBack, .bottomLeftBack]
        case .left: [.topLeftBack, .topLeftFront, .bottomLeftFront, .bottomLeftBack]
        case .right: [.topRightFront, .topRightBack, .bottomRightBack, .bottomRightFront]
        case .front: [.topLeftFront, .topRightFront, .bottomRightFront, .bottomLeftFront]
        case .back: [.topRightBack, .topLeftBack, .bottomLeftBack, .bottomRightBack]
        }
    }
}

extension CornerPieceCollection {
    fileprivate mutating func map(_ face: Face, _ f: (CornerLocation, CornerPiece) -> CornerPiece) {
        for location in CornerLocation.locations(in: face) {
            let piece = self[location]
            let newPiece = f(location, piece)

            if newPiece != piece {
                self[location] = newPiece
            }
        }
    }
}
