import Foundation
import JavaScriptCore

extension Cube {
    // this has to be created on the MainActor
    @MainActor private static let jsVM = JSVirtualMachine()

    private static let cube: Task<JSValue, Error> = Task(priority: .high) {
        let context = JSContext(virtualMachine: jsVM)!
        let scriptFile = Bundle.module.url(forResource: "cube", withExtension: "js")!
        let scriptData = try! Data(contentsOf: scriptFile)
        let scriptText = String(decoding: scriptData, as: UTF8.self)
        context.evaluateScript(scriptText)
        let cube = context.globalObject.objectForKeyedSubscript("Cube")!
        cube.invokeMethod("initSolver", withArguments: [])
        return cube
    }

    public func solution(maxDepth: Int = 24) async throws -> MoveSeries {
        guard self != .solved else { return MoveSeries(values: []) }

        let cubeJS = try await Self.cube.value
        let cube = cubeJS.invokeMethod("fromString", withArguments: [facelets().description])!
        let moves = cube.invokeMethod("solve", withArguments: [maxDepth]).toString()!

        guard let parsed = MoveSeries(moves) else { throw CubeSolverError.invalidMoves }
        return parsed
    }
}

public enum CubeSolverError: Error {
    case solveFailed
    case invalidMoves
}
