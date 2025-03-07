extension Cube {
    public static func scrambled() -> Self {
        var rng = SystemRandomNumberGenerator()
        return scrambled(using: &rng)
    }

    public static func scrambled(using rng: inout some RandomNumberGenerator) -> Self {
        var cube = Cube.solved
        cube.shuffleOrientations(using: &rng)
        cube.shufflePermutations(using: &rng)
        return cube
    }

    private mutating func shuffleOrientations(using rng: inout some RandomNumberGenerator) {
        edges.shuffleOrientations(using: &rng)
        corners.shuffleOrientations(using: &rng)
    }

    private mutating func shufflePermutations(using rng: inout some RandomNumberGenerator) {
        repeat {
            edges.shufflePermutation(using: &rng)
            corners.shufflePermutation(using: &rng)
        } while numberOfSwaps() % 2 != 0
        // ^ probabalistic but chances of failing halve each time
    }

    private func numberOfSwaps() -> Int {
        edges.numberOfSwaps() + corners.numberOfSwaps()
    }
}

// TODO: make these protocols public, use elsewhere too?

private protocol PieceProtocol {
    associatedtype Location: RawRepresentable<Int>, CaseIterable
    associatedtype Orientation: RawRepresentable<Int>, CaseIterable

    var location: Location { get set }
    var orientation: Orientation { get set }
}

private protocol PieceCollection {
    associatedtype Piece: PieceProtocol

    subscript(location: Piece.Location) -> Piece { get set }

    var all: [Piece] { get set }
}

extension CornerPiece: PieceProtocol {}
extension EdgePiece: PieceProtocol {}
extension CornerPieceCollection: PieceCollection {}
extension EdgePieceCollection: PieceCollection {}

extension PieceCollection {
    fileprivate mutating func shufflePermutation(using rng: inout some RandomNumberGenerator) {
        self.all.shuffle(using: &rng)
    }

    fileprivate mutating func shuffleOrientations(using rng: inout some RandomNumberGenerator) {
        for location in Piece.Location.allCases {
            self[location].orientation = Piece.Orientation.allCases.randomElement(using: &rng)!
        }
        let parity = self.orientationParity()
        if parity != 0 {
            let orientations = Self.orientations
            let location = Piece.Location.allCases.randomElement(using: &rng)!
            self[location].orientation = Piece.Orientation(
                rawValue: (self[location].orientation.rawValue + (orientations - parity)) % orientations
            )!
        }
        assert(self.orientationParity() == 0)
    }

    // https://github.com/ldez/cubejs/blob/6b3da493894d9aed54f4c8aafccadbe676e745b5/lib/cube.js#L461
    fileprivate func numberOfSwaps() -> Int {
        var numSwaps = 0

        var seen = self.all.map { _ in false }

        while var cur = seen.firstIndex(where: { !$0 }) {
            // We compute the cycle decomposition
            var cycleLength = 0
            while !seen[cur] {
                seen[cur] = true
                cycleLength += 1
                cur = self.all[cur].location.rawValue
            }
            // A cycle is equivalent to cycleLength + 1 swaps
            numSwaps += cycleLength - 1
        }

        return numSwaps
    }

    private func orientationParity() -> Int {
        let orientations = Self.orientations
        return self.all.map(\.orientation.rawValue).reduce(0) { ($0 + $1) % orientations }
    }

    private static var orientations: Int {
        Piece.Orientation.allCases.count
    }
}
