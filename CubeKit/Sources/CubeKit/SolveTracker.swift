public struct SolveTracker: Sendable {
    private var stack: [Move]

    public var moves: some BidirectionalCollection<Move> {
        stack.reversed()
    }

    public init(moves: some Collection<Move>) {
        self.stack = moves.reversed()
    }

    public mutating func apply(_ move: Move) {
        guard let nextStep = stack.popLast() else {
            stack.append(move.inverse)
            return
        }

        if nextStep == move {
            return
        } else if nextStep.face == move.face {
            if nextStep.magnitude == .halfTurn {
                // need another move in the same direction to
                // complete the half turn
                stack.append(move)
            } else {
                // we moved in the opposite direction (since nextStep != move)
                // so we'll need a half turn to fix
                stack.append(Move(face: move.face, magnitude: .halfTurn))
            }
        } else {
            stack.append(nextStep)
            stack.append(move.inverse)
        }
    }
}
