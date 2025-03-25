extension Cube {
    public struct Cubies: Sendable, Hashable {
        public var cp: [UInt8]
        public var co: [UInt8]
        public var ep: [UInt8]
        public var eo: [UInt8]

        public init(cp: [UInt8], co: [UInt8], ep: [UInt8], eo: [UInt8]) {
            self.cp = cp
            self.co = co
            self.ep = ep
            self.eo = eo
        }
    }

    public func cubies() -> Cubies {
        Cubies(
            cp: corners.all.map { UInt8($0.location.rawValue) },
            co: corners.all.map { UInt8($0.orientation.rawValue) },
            ep: edges.all.map { UInt8($0.location.rawValue) },
            eo: edges.all.map { UInt8($0.orientation.rawValue) }
        )
    }

    public init?(cubies: Cubies) {
        self.init()

        for (corner, (permutation, orientation)) in zip(CornerLocation.allCases, zip(cubies.cp, cubies.co)) {
            guard let cornerLocation = CornerLocation(rawValue: Int(permutation)),
                  let cornerOrientation = CornerPiece.Orientation(rawValue: Int(orientation))
                  else { return nil }
            corners[corner] = CornerPiece(cornerLocation, orientation: cornerOrientation)
        }

        for (edge, (permutation, orientation)) in zip(EdgeLocation.allCases, zip(cubies.ep, cubies.eo)) {
            guard let edgeLocation = EdgeLocation(rawValue: Int(permutation)),
                  let edgeOrientation = EdgePiece.Orientation(rawValue: Int(orientation))
                  else { return nil }
            edges[edge] = EdgePiece(edgeLocation, orientation: edgeOrientation)
        }
    }

}
