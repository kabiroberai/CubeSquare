import Testing
@testable import GANApp

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
    let cryptor = GANCommonCryptor(key: GANConstants.ganKey1, iv: GANConstants.ganIV1, salt: mac)
    let original: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
    var data = original
    try cryptor.encrypt(&data)
    #expect(data == [13, 251, 201, 9, 227, 172, 94, 150, 141, 23, 33, 155, 106, 152, 25, 184, 33, 157, 173, 67])
    try cryptor.decrypt(&data)
    #expect(data == original)
}
