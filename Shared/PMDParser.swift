// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

struct BinaryReader {
    private let data: Data
    private(set) var offset: Int = 0

    init(data: Data) {
        self.data = data
    }
    
    init(url: URL) throws {
        self.data = try Data(contentsOf: url, options: .mappedIfSafe)
    }

    mutating func read<T: BinaryReadable>() -> T {
        let size = MemoryLayout<T>.size

        precondition(offset + size <= data.count)

        let value = withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { temp in
            _ = data.withUnsafeBytes { rawBuffer in
                memcpy(temp.baseAddress!, rawBuffer.baseAddress!.advanced(by: offset), size)
            }

            return temp.baseAddress!.move()
        }

        offset += size

        return value
    }

    mutating func readData(count: Int) -> Data {
        precondition(offset + count <= data.count)

        let result = data[offset ..< offset + count]
        offset += count

        return result
    }

    mutating func readString(length: Int, encoding: String.Encoding = .shiftJIS) -> String {
        let bytes = readData(count: length)
        let string = String(data: bytes.prefix { $0 != 0x00 && $0 != 0xFD }, encoding: encoding)

        return string ?? ""
    }
    
    mutating func readArray<T: BinaryDecodable>(count: Int) throws -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)

        for _ in 0..<count {
            result.append(try T(reader: &self))
        }

        return result
    }
    
    mutating func readUInt32LE() -> UInt32 {
        UInt32(littleEndian: read())
    }
    
    mutating func readFloatLE() -> Float {
        Float(bitPattern: readUInt32LE())
    }
    
    mutating func readSIMD3Float() -> SIMD3<Float> {
        return .init(readFloatLE(), readFloatLE(), readFloatLE())
    }

    mutating func skip(_ size: Int) {
        offset += size
    }
}

protocol BinaryReadable {}

extension UInt8: BinaryReadable {}
extension UInt16: BinaryReadable {}
extension UInt32: BinaryReadable {}
extension Int32: BinaryReadable {}
extension Float: BinaryReadable {}
extension SIMD2<Float>: BinaryReadable {}
extension SIMD3<Float>: BinaryReadable {}

protocol BinaryDecodable {
    init(reader: inout BinaryReader) throws
}

struct PMDHeader : BinaryDecodable {
    public let magic : String
    public let version : Float
    public let modelName : String
    public let comment : String
    
    init(reader: inout BinaryReader) throws {
        self.magic = reader.readString(length: 3)
        self.version = reader.read()
        self.modelName = reader.readString(length: 20)
        self.comment = reader.readString(length: 256)
    }
}

struct PMDVertex : BinaryDecodable {
    public let position: SIMD3<Float>
    public let normal: SIMD3<Float>
    public let uv: SIMD2<Float>
    public let bone0: UInt16
    public let bone1: UInt16
    public let weight: UInt8
    public let edgeFlag: UInt8
    
    init(reader: inout BinaryReader) throws {
        self.position = reader.readSIMD3Float()
        self.normal = reader.readSIMD3Float()
        self.uv = reader.read()
        self.bone0 = reader.read()
        self.bone1 = reader.read()
        self.weight = reader.read()
        self.edgeFlag = reader.read()
    }
}

struct PMDMaterial : BinaryDecodable {
    public let diffuse : SIMD3<Float>
    public let alpha : Float
    public let specularity : Float
    public let specular : SIMD3<Float>
    public let ambient : SIMD3<Float>
    public let toonIndex : UInt8
    public let edgeFlag: UInt8
    public let indicesNum : UInt32
    public let textureFilePath : String
    
    init(reader: inout BinaryReader) throws {
        self.diffuse = reader.readSIMD3Float()
        self.alpha = reader.read()
        self.specularity = reader.read()
        self.specular = reader.readSIMD3Float()
        self.ambient = reader.readSIMD3Float()
        self.toonIndex = reader.read()
        self.edgeFlag = reader.read()
        self.indicesNum = reader.read()
        self.textureFilePath = reader.readString(length: 20)
    }
}

extension UInt16 : BinaryDecodable {
    init(reader: inout BinaryReader) {
        self = reader.read()
    }
}
