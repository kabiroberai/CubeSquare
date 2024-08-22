//
//  Cube.swift
//  RubikSwift
//
//  Created by Javier Soto on 10/28/16.
//  Copyright © 2016 Javier Soto. All rights reserved.
//

// https://github.com/JaviSoto/RubikSwift

public enum EdgeLocation: Int, CaseIterable {
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

public struct EdgePiece: Equatable {
    public enum Orientation: Int, CaseIterable {
        case correct
        case flipped
    }

    public var location: EdgeLocation
    public var orientation: Orientation

    public init(_ location: EdgeLocation, orientation: Orientation = .correct) {
        self.location = location
        self.orientation = orientation
    }
}

public enum CornerLocation: Int, CaseIterable {
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

public struct CornerPiece: Equatable {
    public enum Orientation: Int, CaseIterable {
        case correct
        case rotatedClockwise
        case rotatedCounterClockwise
    }

    public var location: CornerLocation
    public var orientation: Orientation

    public init(_ location: CornerLocation, orientation: Orientation = .correct) {
        self.location = location
        self.orientation = orientation
    }
}

public enum Face: CaseIterable {
    case top
    case bottom
    case left
    case right
    case front
    case back
}

public struct EdgePieceCollection: Equatable {
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

    fileprivate mutating func map(_ face: Face, _ f: (EdgeLocation, EdgePiece) -> EdgePiece) {
        for location in EdgeLocation.locations(in: face) {
            let piece = self[location]
            let newPiece = f(location, piece)

            if newPiece != piece {
                self[location] = newPiece
            }
        }
    }

    public var all: [EdgePiece] {
        EdgeLocation.allCases.map { self[$0] }
    }
}

public struct CornerPieceCollection: Equatable {
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

    fileprivate mutating func map(_ face: Face, _ f: (CornerLocation, CornerPiece) -> CornerPiece) {
        for location in CornerLocation.locations(in: face) {
            let piece = self[location]
            let newPiece = f(location, piece)

            if newPiece != piece {
                self[location] = newPiece
            }
        }
    }

    public var all: [CornerPiece] {
        CornerLocation.allCases.map { self[$0] }
    }
}

public struct Cube: Equatable {
    public struct Pieces: Equatable {
        fileprivate static let numberOfEdges = EdgeLocation.allCases.count
        fileprivate static let numberOfCorners = CornerLocation.allCases.count

        public var edges: EdgePieceCollection
        public var corners: CornerPieceCollection
    }

    public var pieces: Pieces

    public static let solved = Cube()

    public init() {
        self.pieces = Pieces(
            edges: EdgePieceCollection(
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
            ),
            corners: CornerPieceCollection(
                topRightFront: CornerPiece(.topRightFront),
                topLeftFront: CornerPiece(.topLeftFront),
                topLeftBack: CornerPiece(.topLeftBack),
                topRightBack: CornerPiece(.topRightBack),
                bottomRightFront: CornerPiece(.bottomRightFront),
                bottomLeftFront: CornerPiece(.bottomLeftFront),
                bottomLeftBack: CornerPiece(.bottomLeftBack),
                bottomRightBack: CornerPiece(.bottomRightBack)
            )
        )
    }

    public init(applyingToSolvedCube moves: [Move]) {
        self = .solved.applying(moves)
    }
}

extension EdgeLocation {
    fileprivate static let all = Set(EdgeLocation.allCases)

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

extension CornerLocation {
    fileprivate static let all = Set(CornerLocation.allCases)

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

extension Face {
    fileprivate func contains(_ edgeLocation: EdgeLocation) -> Bool {
        switch (self, edgeLocation) {
        case (.top, .topRight), (.top, .topFront), (.top, .topLeft), (.top, .topBack): return true
        case (.bottom, .bottomFront), (.bottom, .bottomRight), (.bottom, .bottomBack), (.bottom, .bottomLeft): return true
        case (.left, .topLeft), (.left, .middleLeftFront), (.left, .bottomLeft), (.left, .middleLeftBack): return true
        case (.right, .topRight), (.right, .middleRightBack), (.right, .bottomRight), (.right, .middleRightFront): return true
        case (.front, .topFront), (.front, .middleRightFront), (.front, .bottomFront), (.front, .middleLeftFront): return true
        case (.back, .topBack), (.back, .middleLeftBack), (.back, .bottomBack), (.back, .middleRightBack): return true
        default: return false
        }
    }

    fileprivate func contains(_ cornerLocation: CornerLocation) -> Bool {
        switch (self, cornerLocation) {
        case (.top, .topRightFront), (.top, .topLeftFront), (.top, .topLeftBack), (.top, .topRightBack): return true
        case (.bottom, .bottomLeftFront), (.bottom, .bottomRightFront), (.bottom, .bottomRightBack), (.bottom, .bottomLeftBack): return true
        case (.left, .topLeftBack), (.left, .topLeftFront), (.left, .bottomLeftFront), (.left, .bottomLeftBack): return true
        case (.right, .topRightFront), (.right, .topRightBack), (.right, .bottomRightBack), (.right, .bottomRightFront): return true
        case (.front, .topLeftFront), (.front, .topRightFront), (.front, .bottomRightFront), (.front, .bottomLeftFront): return true
        case (.back, .topRightBack), (.back, .topLeftBack), (.back, .bottomLeftBack), (.back, .bottomRightBack): return true
        default: return false
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

// MARK: - Moves -

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

public struct Move {
    public enum Magnitude {
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

    public let face: Face
    public let magnitude: Magnitude

    public var inverse: Move {
        return Move(face: self.face, magnitude: self.magnitude.inverse)
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

    public func applying(_ moves: [Move]) -> Cube {
        var cube = self
        cube.apply(moves)
        return cube
    }
}

extension Cube {
    fileprivate mutating func flipEdges(in face: Face) {
        self.pieces.edges.map(face) { $1.flipped }
    }

    fileprivate mutating func rotateCorners(in face: Face) {
        self.pieces.corners.map(face) { (location: CornerLocation, corner: CornerPiece) -> CornerPiece in
            let rotation = face.cornerOrientationChangeAfterClockwiseTurn(in: location)

            return corner + rotation
        }
    }

    fileprivate mutating func permutatePieces(in face: Face, clockwise: Bool) {
        var rotatedPieces = self.pieces

        // This relies on the fact that the locations are returned in clockwise order
        var edgeLocations = EdgeLocation.locations(in: face)
        var cornerLocations = CornerLocation.locations(in: face)

        if !clockwise {
            edgeLocations.reverse()
            cornerLocations.reverse()
        }

        for (index, edgeLocation) in edgeLocations.enumerated() {
            let location = edgeLocations[(index + 1) % edgeLocations.count]
            rotatedPieces.edges[location] = self.pieces.edges[edgeLocation]
        }

        for (index, cornerLocation) in cornerLocations.enumerated() {
            let location = cornerLocations[(index + 1) % cornerLocations.count]
            rotatedPieces.corners[location] = self.pieces.corners[cornerLocation]
        }

        self.pieces = rotatedPieces
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

extension Move: LosslessStringConvertible {
    public init?(_ string: String) {
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

extension Collection where Iterator.Element == Move {
    public var inverse: [Move] {
        return self.reversed().map { $0.inverse }
    }
}

extension Move: CustomStringConvertible {
    public var description: String {
        return "\(self.face)\(self.magnitude)"
    }
}
