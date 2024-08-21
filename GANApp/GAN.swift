import SwiftUI
import CoreBluetooth
import Combine
import CommonCrypto

// based on https://github.com/afedotov/gan-web-bluetooth

// see also
// https://github.com/cubing/cubing.js/blob/65cb0abfe31ad5de4fc325256cfebbd42b20281c/src/cubing/bluetooth/smart-puzzle/gan.ts

enum GANConstants {}
extension GANConstants {
    static let gen2Service: BluetoothUUID = "6e400001-b5a3-f393-e0a9-e50e24dc4179"
    static let gen3Service: BluetoothUUID = "8653000a-43e6-47b7-9cb0-5fc21d4ae340"

    static let gen2CommandCharacteristic: BluetoothUUID = "28be4a4a-cd67-11e9-a32f-2a2ae2dbcce4"
    static let gen2StateCharacteristic: BluetoothUUID = "28be4cb6-cd67-11e9-a32f-2a2ae2dbcce4"

    // GAN Gen2, Gen3
    static let ganKey1: [UInt8] = [0x01, 0x02, 0x42, 0x28, 0x31, 0x91, 0x16, 0x07, 0x20, 0x05, 0x18, 0x54, 0x42, 0x11, 0x12, 0x53]
    static let ganIV1: [UInt8] = [0x11, 0x03, 0x32, 0x28, 0x21, 0x01, 0x76, 0x27, 0x20, 0x95, 0x78, 0x14, 0x32, 0x12, 0x02, 0x43]

    // MoYu AI 2023
    static let ganKey2: [UInt8] = [0x05, 0x12, 0x02, 0x45, 0x02, 0x01, 0x29, 0x56, 0x12, 0x78, 0x12, 0x76, 0x81, 0x01, 0x08, 0x03]
    static let ganIV2: [UInt8] = [0x01, 0x44, 0x28, 0x06, 0x86, 0x21, 0x22, 0x28, 0x51, 0x05, 0x08, 0x31, 0x82, 0x02, 0x21, 0x06]
}

struct GANHardware: Hashable {
    var hardwareName: String
    var softwareVersion: String
    var hardwareVersion: String
    var supportsGyroscope: Bool
}

struct GANGyroData: Hashable, Sendable {
    struct Orientation: Hashable, Sendable {
        var x: Double
        var y: Double
        var z: Double
        var w: Double
    }

    struct AngularVelocity: Hashable, Sendable {
        var x: Double
        var y: Double
        var z: Double
    }

    var orientation: Orientation
    var angularVelocity: AngularVelocity?
}

struct GANMove: Hashable, Sendable, CustomStringConvertible {
    enum Face: Int, CustomStringConvertible {
        case up = 0, right, front, down, left, back

        var description: String {
            switch self {
            case .up: "U"
            case .right: "R"
            case .front: "F"
            case .down: "D"
            case .left: "L"
            case .back: "B"
            }
        }
    }

    enum Direction: Int {
        case clockwise = 0, anticlockwise
    }

    var face: Face
    var direction: Direction

    var description: String {
        "\(face)\(direction == .clockwise ? "" : "'")"
    }
}

struct GANFacelets: Hashable, Sendable {
    var cp: [UInt8]
    var co: [UInt8]
    var ep: [UInt8]
    var eo: [UInt8]
    var serial: UInt8
}

struct BluetoothUUID: Hashable, ExpressibleByStringLiteral {
    let string: String

    init(_ string: String) {
        self.string = string.uppercased()
    }

    init(stringLiteral value: String) {
        self.init(value)
    }

    var cbUUID: CBUUID {
        CBUUID(string: string)
    }
}

extension CBUUID {
    var bluetoothUUID: BluetoothUUID {
        BluetoothUUID(uuidString)
    }
}

protocol GANCryptor {
    func encrypt(_ data: inout [UInt8]) throws
    func decrypt(_ data: inout [UInt8]) throws
}

enum GANCubeCommand {
    case requestHardware
    case requestFacelets
    case requestBattery
    case reset
}

struct GANCubeEvent {
    enum Event: Hashable {
        case gyro(GANGyroData)
        // move[0] is the move that just happened. after that is the recent history.
        case move([GANMove], serial: UInt8)
        case battery(level: Int) // 0-100
        case hardware(GANHardware)
        case facelets(GANFacelets)
    }

    var localTime: Date
    var event: Event
}

protocol GANSerializer {
    func encode(_ command: GANCubeCommand) -> [UInt8]
    func decode(_ event: [UInt8]) throws -> [GANCubeEvent]
}

extension RandomAccessCollection<UInt8> {
    func readU1(bitOffset: Int) -> Bool {
        let (bigOffset, smallOffset) = bitOffset.quotientAndRemainder(dividingBy: 8)
        let byte = self[index(startIndex, offsetBy: bigOffset)]
        return byte & (1 << (7 - smallOffset)) != 0
    }

    // TODO: optimize
    // bitCount <= 8
    func readU8(bitOffset: Int, bitCount: Int = 8) -> UInt8 {
        precondition(bitCount <= 8, "\(bitCount) > 8")
        var result: UInt8 = 0
        for i in 0..<bitCount {
            let offset = bitOffset + i
            let bit = readU1(bitOffset: offset)
            result = (result << 1) | (bit ? 1 : 0)
        }
        return result
    }

    // big endian
    func readU16(bitOffset: Int) -> UInt16 {
        let byte1 = UInt16(readU8(bitOffset: bitOffset + 0))
        let byte2 = UInt16(readU8(bitOffset: bitOffset + 8))
        return (byte1 << 8) | (byte2 << 0)
    }

    // big endian
    func readU32(bitOffset: Int) -> UInt32 {
        let byte1 = UInt32(readU8(bitOffset: bitOffset +  0))
        let byte2 = UInt32(readU8(bitOffset: bitOffset +  8))
        let byte3 = UInt32(readU8(bitOffset: bitOffset + 16))
        let byte4 = UInt32(readU8(bitOffset: bitOffset + 24))
        return (byte1 << 24) | (byte2 << 16) | (byte3 << 8) | (byte4 << 0)
    }
}

struct GANGen2Serializer: GANSerializer {
    func encode(_ command: GANCubeCommand) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        switch command {
        case .requestFacelets:
            bytes[0] = 0x04
        case .requestHardware:
            bytes[0] = 0x05
        case .requestBattery:
            bytes[0] = 0x09
        case .reset:
            bytes = [0x0A, 0x05, 0x39, 0x77, 0x00, 0x00, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        }
        return bytes
    }

    func decode(_ event: [UInt8]) throws -> [GANCubeEvent] {
        let now = Date()
        let kind = event.readU8(bitOffset: 0, bitCount: 4)
        var events: [GANCubeEvent.Event] = []
        switch kind {
        case 0x01: // GYRO
            let qw = event.readU16(bitOffset: 4)
            let qx = event.readU16(bitOffset: 20)
            let qy = event.readU16(bitOffset: 36)
            let qz = event.readU16(bitOffset: 52)

            let vx = event.readU8(bitOffset: 68, bitCount: 4)
            let vy = event.readU8(bitOffset: 72, bitCount: 4)
            let vz = event.readU8(bitOffset: 76, bitCount: 4)

            func parseU16(_ value: UInt16) -> Double {
                let sign: Double = ((value >> 15) & 1) == 1 ? -1 : 1
                let magnitude = Double(value & 0x7FFF)
                return sign * magnitude / Double(0x7FFF)
            }

            func parseU4(_ value: UInt8) -> Double {
                let sign: Double = ((value >> 3) & 1) == 1 ? -1 : 1
                let magnitude = Double(value & 0x7)
                return sign * magnitude
            }

            events.append(.gyro(GANGyroData(
                orientation: .init(
                    x: parseU16(qx),
                    y: parseU16(qy),
                    z: parseU16(qz),
                    w: parseU16(qw)
                ),
                angularVelocity: .init(
                    x: parseU4(vx),
                    y: parseU4(vy),
                    z: parseU4(vz)
                )
            )))
        case 0x02: // MOVE
            /*
             let serial = msg.getBitWord(4, 8);
             let diff = this.lastSerial == -1 ? 1 : Math.min((serial - this.lastSerial) & 0xFF, 7);
             this.lastSerial = serial;

             if (diff > 0) {
                 for (let i = diff - 1; i >= 0; i--) {
                     let face = msg.getBitWord(12 + 5 * i, 4);
                     let direction = msg.getBitWord(16 + 5 * i, 1);
                     let move = "URFDLB".charAt(face) + " '".charAt(direction);
                     let elapsed = msg.getBitWord(47 + 16 * i, 16);
                     if (elapsed == 0) { // In case of 16-bit cube timestamp register overflow
                         elapsed = timestamp - this.lastMoveTimestamp;
                     }
                     this.cubeTimestamp += elapsed;
                     cubeEvents.push({
                         type: "MOVE",
                         serial: (serial - i) & 0xFF,
                         timestamp: timestamp,
                         localTimestamp: i == 0 ? timestamp : null, // Missed and recovered events has no meaningfull local timestamps
                         cubeTimestamp: this.cubeTimestamp,
                         face: face,
                         direction: direction,
                         move: move.trim()
                     });
                 }
                 this.lastMoveTimestamp = timestamp;
             }
             */

            let serial = event.readU8(bitOffset: 4)

            let moves = (0..<7).compactMap { i -> GANMove? in
                let rawFace = event.readU8(bitOffset: 12 + 5 * i, bitCount: 4)
                let rawDirection = event.readU8(bitOffset: 16 + 5 * i, bitCount: 1)
                let elapsed = event.readU16(bitOffset: 47 + 16 * i)
                // TODO: handle timestamp
                _ = elapsed
                guard let face = GANMove.Face(rawValue: Int(rawFace)) else { return nil }
                let direction = GANMove.Direction(rawValue: Int(rawDirection))!
                return GANMove(face: face, direction: direction)
            }

            events.append(.move(moves, serial: serial))
        case 0x04: // FACELETS
            let serial = event.readU8(bitOffset: 4)

            var cp: [UInt8] = []
            var co: [UInt8] = []
            var ep: [UInt8] = []
            var eo: [UInt8] = []

            // corners
            for i in 0..<7 {
                cp.append(event.readU8(bitOffset: 12 + i * 3, bitCount: 3))
                co.append(event.readU8(bitOffset: 33 + i * 2, bitCount: 2))
            }
            cp.append(28 - cp.reduce(0, +))
            co.append((3 - (co.reduce(0, +) % 3)) % 3)

            // edges
            for i in 0..<11 {
                ep.append(event.readU8(bitOffset: 47 + i * 4, bitCount: 4))
                eo.append(event.readU8(bitOffset: 91 + i * 1, bitCount: 1))
            }
            ep.append(66 - ep.reduce(0, +))
            eo.append((2 - (eo.reduce(0, +) % 2)) % 2)

            events.append(.facelets(
                .init(cp: cp, co: co, ep: ep, eo: eo, serial: serial)
            ))
        case 0x05: // HARDWARE
            let hwMajor = event.readU8(bitOffset: 8)
            let hwMinor = event.readU8(bitOffset: 16)
            let swMajor = event.readU8(bitOffset: 24)
            let swMinor = event.readU8(bitOffset: 32)
            let supportsGyroscope = event.readU8(bitOffset: 104, bitCount: 1) == 1
            let hardwareName = String(
                decoding: (0..<8).map {
                    event.readU8(bitOffset: 40 + $0 * 8)
                },
                as: UTF8.self
            )

            events.append(.hardware(.init(
                hardwareName: hardwareName,
                softwareVersion: "\(swMajor).\(swMinor)",
                hardwareVersion: "\(hwMajor).\(hwMinor)",
                supportsGyroscope: supportsGyroscope
            )))
        case 0x09: // BATTERY
            let level = event.readU8(bitOffset: 8)
            events.append(.battery(level: Int(min(level, 100))))
        default:
            break
        }
        return events.map { .init(localTime: now, event: $0) }
    }
}

struct GANCommonCryptor: GANCryptor {
    var key: [UInt8]
    var iv: [UInt8]

    init(key: [UInt8], iv: [UInt8], salt: [UInt8]) {
        assert(key.count == 16, "key.count (\(key.count)) != 16")
        assert(iv.count == 16, "iv.count (\(iv.count)) != 16")
        assert(salt.count == 6, "salt.count (\(salt.count)) != 6")

        var key = key
        var iv = iv

        for i in 0..<6 {
            let byte = UInt16(salt[i])
            key[i] = UInt8((UInt16(key[i]) + byte) % 0xFF)
            iv[i] = UInt8((UInt16(iv[i]) + byte) % 0xFF)
        }

        self.key = key
        self.iv = iv
    }

    enum Errors: Error {
        case commonCryptoError(CCCryptorStatus)
        case truncatedData
    }

    private func transform(chunk: [UInt8], encrypt: Bool) throws -> [UInt8] {
        try [UInt8](unsafeUninitializedCapacity: chunk.count) { outBuf, outLen in
            let status = CCCrypt(
                UInt32(encrypt ? kCCEncrypt : kCCDecrypt),
                UInt32(kCCAlgorithmAES128),
                /* options: */ 0,
                key, key.count,
                iv,
                chunk, chunk.count,
                outBuf.baseAddress, outBuf.count,
                &outLen
            )
            guard status == kCCSuccess else {
                throw Errors.commonCryptoError(status)
            }
        }
    }

    private func transform(chunk: inout ArraySlice<UInt8>, encrypt: Bool) throws {
        chunk = try transform(chunk: Array(chunk), encrypt: encrypt)[...]
    }

    func encrypt(_ data: inout [UInt8]) throws {
        guard data.count >= 16 else { throw Errors.truncatedData }
        try transform(chunk: &data[..<16], encrypt: true)
        if data.count > 16 {
            try transform(chunk: &data[(data.count - 16)...], encrypt: true)
        }
    }

    func decrypt(_ data: inout [UInt8]) throws {
        guard data.count >= 16 else { throw Errors.truncatedData }
        if data.count > 16 {
            try transform(chunk: &data[(data.count - 16)...], encrypt: false)
        }
        try transform(chunk: &data[..<16], encrypt: false)
    }
}

final class GANCube {
    let cubeManager: GANCubeManager
    let serializer: any GANSerializer
    let cryptor: any GANCryptor
    let service: CBService
    let commandCharacteristic: CBCharacteristic
    let stateCharacteristic: CBCharacteristic

    private let cancellable: AnyCancellable
    private let _events = PassthroughSubject<GANCubeEvent, Never>()
    private var events: some Publisher<GANCubeEvent, Never> { _events }

    init(
        cubeManager: GANCubeManager,
        serializer: any GANSerializer,
        cryptor: any GANCryptor,
        service: CBService,
        commandCharacteristic: CBCharacteristic,
        stateCharacteristic: CBCharacteristic
    ) {
        self.cubeManager = cubeManager
        self.serializer = serializer
        self.cryptor = cryptor
        self.service = service
        self.commandCharacteristic = commandCharacteristic
        self.stateCharacteristic = stateCharacteristic

        let stateUUID = stateCharacteristic.uuid.bluetoothUUID
        cancellable = cubeManager.peripheralDelegate.events
            .compactMap { [cryptor, serializer] event -> [GANCubeEvent] in
                guard case let .updatedCharacteristic(characteristic, error) = event,
                      characteristic.uuid.bluetoothUUID == stateUUID,
                      error == nil,
                      let value = characteristic.value
                      else { return [] }
                var bytes = [UInt8](value)
                guard (try? cryptor.decrypt(&bytes)) != nil else { return [] }
                guard let decoded = try? serializer.decode(bytes) else { return [] }
                return decoded
            }
            .flatMap { $0.publisher }
            .sink { [_events] in
                _events.send($0)
            }

        cubeManager.peripheral.setNotifyValue(true, for: stateCharacteristic)
    }

    private func send(_ command: GANCubeCommand) async throws {
        var bytes = serializer.encode(command)
        try cryptor.encrypt(&bytes)
        cubeManager.peripheral.writeValue(Data(bytes), for: commandCharacteristic, type: .withoutResponse)
    }

    private func request<T>(
        _ command: GANCubeCommand,
        extractResponse: @escaping (GANCubeEvent) -> T?
    ) async throws -> T {
        async let result = events
            .compactMap { extractResponse($0) }
            .values
            .first(where: { _ in true })
        try await send(command)
        return await result!
    }

    func batteryLevel() async throws -> Int {
        try await request(.requestBattery) { event in
            if case let .battery(value) = event.event { value } else { nil }
        }
    }

    func hardware() async throws -> GANHardware {
        try await request(.requestHardware) { event in
            if case let .hardware(value) = event.event { value } else { nil }
        }
    }

    func facelets() async throws -> GANFacelets {
        try await request(.requestFacelets) { event in
            if case let .facelets(value) = event.event { value } else { nil }
        }
    }

    var gyroData: some Publisher<GANGyroData, Never> {
        events.compactMap { event in
            if case let .gyro(value) = event.event { value } else { nil }
        }
    }

    var moves: some Publisher<GANMove, Never> {
        // TODO: test diff > 1
        events.scan(([], -1) as ([GANMove], Int)) { (lastMovesAndSerial, event) in
            let lastSerial = lastMovesAndSerial.1
            guard case let .move(values, serial) = event.event else { return ([], lastSerial) }
            let diff = lastSerial == -1 ? 1 : min(Int(serial &- UInt8(lastSerial)), 7)
            return (values.prefix(diff).reversed(), Int(serial))
        }.flatMap { moves, serial in
            moves.publisher
        }
    }
}

final class GANCubeManager {
    let centralManager: CBCentralManager
    let bluetoothDelegate: GANManager.BluetoothDelegate

    let peripheral: CBPeripheral
    let peripheralDelegate: PeripheralDelegate
    // 6 bytes
    let macAddress: [UInt8]

    init?(
        centralManager: CBCentralManager,
        bluetoothDelegate: GANManager.BluetoothDelegate,
        peripheral: CBPeripheral,
        advertisementData: [String: Any]
    ) {
        guard let name = peripheral.name, name.hasPrefix("GAN"),
              let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              manufacturerData.count >= 6
              else { return nil }

        self.centralManager = centralManager
        self.bluetoothDelegate = bluetoothDelegate
        self.peripheral = peripheral
        self.macAddress = Array(manufacturerData.reversed().prefix(6))
        self.peripheralDelegate = PeripheralDelegate()

        peripheral.delegate = peripheralDelegate
    }

    func connect() async throws -> GANCube {
        try await _connect()
        let services = try await self.services()
        let serviceByUUID = [BluetoothUUID: CBService](
            services.map { ($0.uuid.bluetoothUUID, $0) },
            uniquingKeysWith: { $1 }
        )
        if let gen3Service = serviceByUUID[GANConstants.gen3Service] {
            _ = gen3Service
            // FIXME: support gen3
            throw Errors.gen3Unsupported
        } else if let gen2Service = serviceByUUID[GANConstants.gen2Service] {
            async let commandCharacteristic = characteristic(
                uuid: GANConstants.gen2CommandCharacteristic,
                for: gen2Service
            )
            async let stateCharacteristic = characteristic(
                uuid: GANConstants.gen2StateCharacteristic,
                for: gen2Service
            )
            return try await GANCube(
                cubeManager: self,
                serializer: GANGen2Serializer(),
                cryptor: GANCommonCryptor(
                    key: GANConstants.ganKey1,
                    iv: GANConstants.ganIV1,
                    salt: macAddress.reversed()
                ),
                service: gen2Service,
                commandCharacteristic: commandCharacteristic,
                stateCharacteristic: stateCharacteristic
            )
        } else {
            throw Errors.unknownProtocol
        }
    }

    private func _connect() async throws {
        async let completion = bluetoothDelegate.peripherals.values.compactMap { event -> Result<Void, Error>? in
            guard case let .connectFinished(peripheral, error: error) = event,
                  peripheral.identifier == self.peripheral.identifier
                  else { return nil }
            if let error {
                return .failure(error)
            } else {
                return .success(())
            }
        }.first { _ in true }

        centralManager.connect(peripheral)
        let result = await completion
        try result!.get()
    }

    private func services() async throws -> [CBService] {
        async let discoverResult = peripheralDelegate.events.values.compactMap { event -> Result<Void, Error>? in
            guard case let .discoveredServices(error) = event else { return nil }
            if let error {
                return .failure(error)
            } else {
                return .success(())
            }
        }.first(where: { _ in true })
        peripheral.discoverServices(nil)
        try await discoverResult?.get()
        return peripheral.services ?? []
    }

    private func characteristic(
        uuid: BluetoothUUID,
        for service: CBService
    ) async throws -> CBCharacteristic {
        async let characteristic = peripheralDelegate.events.compactMap { event -> Result<CBCharacteristic, Error>? in
            guard case let .discoveredCharacteristics(foundService, error) = event,
                  foundService.uuid.bluetoothUUID == service.uuid.bluetoothUUID
                  else { return nil }
            if let error {
                return .failure(error)
            }
            guard let characteristic = foundService.characteristics?.first(where: { $0.uuid.bluetoothUUID == uuid }) else {
                return nil // .failure(Errors.characteristicNotFound(uuid))
            }
            return .success(characteristic)
        }.values.first(where: { _ in true })
        peripheral.discoverCharacteristics([uuid.cbUUID], for: service)
        guard let characteristic = try await characteristic?.get() else {
            throw Errors.characteristicNotFound(uuid)
        }
        return characteristic
    }

    enum Errors: Error {
        case characteristicNotFound(BluetoothUUID)
        case gen3Unsupported
        case unknownProtocol
    }

    final class PeripheralDelegate: NSObject, CBPeripheralDelegate {
        enum PeripheralEvent {
            case discoveredServices(error: Error?)
            case discoveredCharacteristics(service: CBService, error: Error?)
            case updatedCharacteristic(characteristic: CBCharacteristic, error: Error?)
        }

        private let _events = PassthroughSubject<PeripheralEvent, Never>()
        var events: some Publisher<PeripheralEvent, Never> { _events }

        func peripheral(
            _ peripheral: CBPeripheral,
            didDiscoverServices error: (any Error)?
        ) {
            _events.send(.discoveredServices(error: error))
        }

        func peripheral(
            _ peripheral: CBPeripheral,
            didDiscoverCharacteristicsFor service: CBService,
            error: (any Error)?
        ) {
            _events.send(.discoveredCharacteristics(service: service, error: error))
        }

        func peripheral(
            _ peripheral: CBPeripheral,
            didUpdateValueFor characteristic: CBCharacteristic,
            error: (any Error)?
        ) {
            _events.send(.updatedCharacteristic(characteristic: characteristic, error: error))
        }
    }
}

@MainActor
final class GANManager {
    private let bluetoothDelegate: BluetoothDelegate
    private let centralManager: CBCentralManager

    init() {
        self.bluetoothDelegate = BluetoothDelegate()
        self.centralManager = CBCentralManager(
            delegate: bluetoothDelegate,
            queue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    private var activeScans = 0

    private func startScan() {
        activeScans += 1
        if activeScans == 1 {
            centralManager.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true,
            ])
        }
    }

    private func stopScan() {
        activeScans -= 1
        if activeScans == 0 {
            centralManager.stopScan()
        }
    }

    var cubes: some Publisher<GANCubeManager, Never> {
        bluetoothDelegate.peripherals
            .handleEvents(
                receiveSubscription: { _ in
                    Task {
                        _ = await self.bluetoothDelegate.managerState.values.first(where: \.isDetermined)
                        self.startScan()
                    }
                },
                receiveCancel: {
                    Task { @MainActor in self.stopScan() }
                }
            )
            .compactMap { event -> GANCubeManager? in
                guard case let .discovered(peripheral, advertisementData) = event else { return nil }
                return GANCubeManager(
                    centralManager: self.centralManager,
                    bluetoothDelegate: self.bluetoothDelegate,
                    peripheral: peripheral,
                    advertisementData: advertisementData
                )
            }
    }

    final class BluetoothDelegate: NSObject, CBCentralManagerDelegate {
        enum PeripheralEvent {
            case discovered(CBPeripheral, advertisementData: [String: Any])
            case connectFinished(CBPeripheral, error: Error?)
            case disconnected(CBPeripheral)
        }

        private let _managerState = CurrentValueSubject<CBManagerState, Never>(.unknown)
        var managerState: some Publisher<CBManagerState, Never> { _managerState }
        private let _peripherals = PassthroughSubject<PeripheralEvent, Never>()
        var peripherals: some Publisher<PeripheralEvent, Never> { _peripherals }

        func centralManagerDidUpdateState(_ central: CBCentralManager) {
            _managerState.value = central.state
        }

        func centralManager(
            _ central: CBCentralManager,
            didDiscover peripheral: CBPeripheral,
            advertisementData: [String : Any],
            rssi RSSI: NSNumber
        ) {
            _peripherals.send(.discovered(peripheral, advertisementData: advertisementData))
        }

        func centralManager(
            _ central: CBCentralManager,
            didConnect peripheral: CBPeripheral
        ) {
            _peripherals.send(.connectFinished(peripheral, error: nil))
        }

        func centralManager(
            _ central: CBCentralManager,
            didFailToConnect peripheral: CBPeripheral,
            error: (any Error)?
        ) {
            _peripherals.send(.connectFinished(peripheral, error: error))
        }

        func centralManager(
            _ central: CBCentralManager,
            didDisconnectPeripheral peripheral: CBPeripheral,
            timestamp: CFAbsoluteTime,
            isReconnecting: Bool,
            error: (any Error)?
        ) {
            _peripherals.send(.disconnected(peripheral))
        }
    }
}

extension CBManagerState {
    fileprivate var isDetermined: Bool {
        switch self {
        case .unknown, .resetting: false
        case .unauthorized, .unsupported, .poweredOn, .poweredOff: true
        @unknown default: true
        }
    }
}
