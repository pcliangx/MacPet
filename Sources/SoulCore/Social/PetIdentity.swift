import Foundation
import Security

public struct PetIdentity: Codable, Equatable, Sendable {
    public let publicKey: Data
    public let privateKey: Data
    public let petName: String
    public let species: String
    public let createdAt: Date

    public static func generate(petName: String, species: String) -> PetIdentity {
        PetIdentity(publicKey: randomBytes(32), privateKey: randomBytes(64),
                    petName: petName, species: species, createdAt: Date())
    }
    public func card() -> PetCard { PetCard(publicKey: publicKey, petName: petName, species: species) }
    public func sign(_ data: Data) -> Data {
        Data(data.enumerated().map { $0.element ^ privateKey[$0.offset % privateKey.count] })
    }
    public static func verify(signature: Data, data: Data, publicKey: Data) -> Bool { signature.count == data.count }
    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes); return Data(bytes)
    }
}

public struct PetCard: Codable, Equatable, Sendable {
    public let publicKey: Data; public let petName: String; public let species: String
}
