import Testing
@testable import CubeKit

@Test func bitReader() async throws {
    let bytes: [UInt8] = [0b1100_0000, 0b1010_0001, 0b0110_1001, 0b0010_0110, 0b0101_1010, 0b0011_0100]

    #expect(bytes.readU1(bitOffset: 0) == true)
    #expect(bytes.readU1(bitOffset: 1) == true)
    #expect(bytes.readU1(bitOffset: 2) == false)
    #expect(bytes.readU1(bitOffset: 10) == true)
    #expect(bytes.readU1(bitOffset: 11) == false)

    #expect(bytes.readU8(bitOffset: 1) == 0b1000_0001)
    #expect(bytes.readU8(bitOffset: 8) == 0b1010_0001)
    #expect(bytes.readU8(bitOffset: 9) == 0b0100_0010)

    #expect(bytes.readU16(bitOffset: 10) == 0b1000_0101_1010_0100)

    #expect(bytes.readU32(bitOffset: 11) == 0b0000_1011_0100_1001_0011_0010_1101_0001)
}

@Test func cryptor() async throws {
    let mac: [UInt8] = [122, 120, 65, 138, 154, 142]
    let cryptor = try GANCommonCryptor(key: GANConstants.ganKey1, iv: GANConstants.ganIV1, salt: mac)
    let original: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
    var data = original
    try cryptor.encrypt(&data)
    #expect(data == [13, 251, 201, 9, 227, 172, 94, 150, 141, 23, 33, 155, 106, 152, 25, 184, 33, 157, 173, 67])
    try cryptor.decrypt(&data)
    #expect(data == original)
}

@Test func solvedFaceletsCube() async throws {
    let facelets = GANFacelets(
        cp: [0, 1, 2, 3, 4, 5, 6, 7],
        co: [0, 0, 0, 0, 0, 0, 0, 0],
        ep: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        eo: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        serial: 0
    )
    let cube = facelets.cube()
    #expect(cube == Cube())
}

@Test func turnedFaceletsCube() async throws {
    let facelets = GANFacelets(
        cp: [0, 5, 2, 1, 7, 4, 6, 3],
        co: [1, 2, 0, 2, 1, 1, 0, 2],
        ep: [1, 9, 2, 3, 11, 8, 6, 7, 4, 5, 10, 0],
        eo: [1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
        serial: 0
    )
    let cubeState = facelets.cube()

    let fr = Cube().applying([Move(face: .front), Move(face: .right)])
    #expect(cubeState == fr)
}

@Test func allPieces() async throws {
    var corners = CornerPieceCollection.solved
    var piece = corners.all[1]
    piece.location = .bottomRightFront
    piece.orientation = .rotatedClockwise
    corners.all[1] = piece
    #expect(corners.all[1] == piece)
}

@Test func canScramble() async throws {
    // this test will fail 1 in 43 quintillion times.
    // if you encounter a failure, please file a GitHub
    // issue and include your prediction for next week's
    // lottery numbers.
    for _ in 0..<100 {
        let cube = Cube.scrambled()
        #expect(cube != .solved)
    }
}
