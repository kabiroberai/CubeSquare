extension Cube {
    public struct Facelets: LosslessStringConvertible {
        public var values: [Face]

        public init(values: [Face]) {
            self.values = values
        }

        public init?(_ description: String) {
            guard description.count == 54,
                  let values = description.map({ Face("\($0)") }) as? [Face]
                  else { return nil }
            self.values = values
        }

        public var description: String {
            values.map { "\($0)" }.joined()
        }
    }

    public func facelets() -> Facelets {
        var facelets = [Face](repeating: .top, count: 54)

        for center in Face.allCases {
            facelets[9 * center.rawValue + 4] = center
        }

        for location in CornerLocation.allCases {
            let corner = corners[location]
            for orientation in CornerPiece.Orientation.allCases {
                let oriIdx = (corner.orientation.rawValue + orientation.rawValue)
                    % CornerPiece.Orientation.allCases.count
                facelets[location.facelets[oriIdx]] = corner.location.faces[orientation.rawValue]
            }
        }

        for location in EdgeLocation.allCases {
            let edge = edges[location]
            for orientation in EdgePiece.Orientation.allCases {
                let oriIdx = (edge.orientation.rawValue + orientation.rawValue)
                    % EdgePiece.Orientation.allCases.count
                facelets[location.facelets[oriIdx]] = edge.location.faces[orientation.rawValue]
            }
        }

        return Facelets(values: facelets)
    }

    public init(facelets: Facelets) throws {
        let values = facelets.values
        guard values.count == 54 else {
            throw FaceletConversionError.invalidFaceletCount
        }
        self = .solved

        for source in CornerLocation.allCases {
            guard let orientation = CornerPiece.Orientation.allCases.first(where: {
                [.top, .bottom].contains(values[source.facelets[$0.rawValue]])
            }) else {
                throw FaceletConversionError.invalidCorner
            }

            let col1 = values[source.facelets[(orientation.rawValue + 1) % 3]]
            let col2 = values[source.facelets[(orientation.rawValue + 2) % 3]]
            guard let dest = CornerLocation.allCases.first(where: {
                $0.faces[1] == col1 && $0.faces[2] == col2
            }) else {
                throw FaceletConversionError.invalidCorner
            }

            self.corners[source] = CornerPiece(dest, orientation: orientation)
        }

        for source in EdgeLocation.allCases {
            for dest in EdgeLocation.allCases {
                if values[source.facelets[0]] == dest.faces[0],
                   values[source.facelets[1]] == dest.faces[1] {
                    self.edges[source] = EdgePiece(dest, orientation: .correct)
                } else if values[source.facelets[0]] == dest.faces[1],
                          values[source.facelets[1]] == dest.faces[0] {
                    self.edges[source] = EdgePiece(dest, orientation: .flipped)
                }
            }
        }
    }

    public enum FaceletConversionError: Error {
        case invalidFaceletCount
        case invalidCorner
    }
}

extension CornerLocation {
    // indices into facelet repr, in clockwise order
    fileprivate var facelets: [Int] {
        switch self {
        case .topRightFront: [8, 9, 20]
        case .topLeftFront: [6, 18, 38]
        case .topLeftBack: [0, 36, 47]
        case .topRightBack: [2, 45, 11]
        case .bottomRightFront: [29, 26, 15]
        case .bottomLeftFront: [27, 44, 24]
        case .bottomLeftBack: [33, 53, 42]
        case .bottomRightBack: [35, 17, 51]
        }
    }
}

extension EdgeLocation {
    fileprivate var facelets: [Int] {
        switch self {
        case .topRight: [5, 10]
        case .topFront: [7, 19]
        case .topLeft: [3, 37]
        case .topBack: [1, 46]
        case .bottomRight: [32, 16]
        case .bottomFront: [28, 25]
        case .bottomLeft: [30, 43]
        case .bottomBack: [34, 52]
        case .middleRightFront: [23, 12]
        case .middleLeftFront: [21, 41]
        case .middleLeftBack: [50, 39]
        case .middleRightBack: [48, 14]
        }
    }
}
