private import CCubeKit
import Foundation

private actor CubeSolverCache {
    static let shared = CubeSolverCache()

    private let cacheDir = URL.cachesDirectory.appending(path: "CubeSquare/ctwophase")
    private let queue = DispatchSerialQueue(label: "com.kabiroberai.CubeSquare.solver-cache")
    private var hasCreatedCache = false

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    private init() {}

    func cache() -> URL {
        if !hasCreatedCache {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            // has to be run serially, hence the actor
            cacheDir.withUnsafeFileSystemRepresentation { initPruning($0) }
            hasCreatedCache = true
        }
        return cacheDir
    }
}

extension Cube {
    private static let solveQueue = DispatchQueue(
        label: "com.kabiroberai.CubeSquare.solve",
        attributes: .concurrent
    )

    public func solution(maxDepth: Int = 24, timeout: TimeInterval = 1000) async throws -> MoveSeries {
        let cache = await CubeSolverCache.shared.cache()

        guard let rawMoves = await withCheckedContinuation({ continuation in
            Self.solveQueue.async {
                let facelets = strdup(facelets().description)
                let result = cache.withUnsafeFileSystemRepresentation({
                    CCubeKit.solution(facelets, Int32(maxDepth), Int(timeout.rounded(.up)), 0, $0)
                })
                free(facelets)
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
