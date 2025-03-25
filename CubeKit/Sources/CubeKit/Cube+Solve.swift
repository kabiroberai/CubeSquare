private import CCubeKit
import Foundation

private actor CubeSolverCache {
    static let shared = CubeSolverCache()

    private let queue = DispatchSerialQueue(label: "com.kabiroberai.CubeSquare.solver-cache")
    private var hasCreatedCache = false

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    private init() {}

    func prepare() {
        guard !hasCreatedCache else { return }
        hasCreatedCache = true
        cube_setup()
    }
}

extension Cube {
    private static let solveQueue = DispatchQueue(
        label: "com.kabiroberai.CubeSquare.solve",
        attributes: .concurrent
    )

    public func solution(maxDepth: Int = 24, timeout: TimeInterval = 1000) async throws -> MoveSeries {
        guard self != .solved else { return MoveSeries(values: []) }

        await CubeSolverCache.shared.prepare()

        guard let rawMoves = await withCheckedContinuation({ continuation in
            Self.solveQueue.async {
                var cubies = self.cubies()
                let rawCube = cube_new(&cubies.cp, &cubies.co, &cubies.ep, &cubies.eo)
                let result = cube_solve(rawCube, Int32(maxDepth), Int(timeout.rounded(.up)), 0)
                cube_free(rawCube)
                continuation.resume(returning: result)
            }
        }) else { throw CubeSolverError.solveFailed }
        let moves = String(cString: rawMoves)
        free(rawMoves)

        guard let parsed = MoveSeries(moves) else { throw CubeSolverError.invalidMoves }
        return parsed
    }
}

public enum CubeSolverError: Error {
    case solveFailed
    case invalidMoves
}
