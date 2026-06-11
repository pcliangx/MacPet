import Foundation

public struct FriendTicket: Codable, Equatable, Sendable {
    public let fromCard: PetCard; public let nonce: Data; public let signature: Data; public let createdAt: Date

    public static func create(from identity: PetIdentity) -> FriendTicket {
        let card = identity.card()
        let nonce = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let sig = identity.sign(card.publicKey + nonce)
        return FriendTicket(fromCard: card, nonce: nonce, signature: sig, createdAt: Date())
    }
    public func encode() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
    }
    public static func decode(_ str: String) -> FriendTicket? {
        guard let data = Data(base64Encoded: str) else { return nil }
        return try? JSONDecoder().decode(FriendTicket.self, from: data)
    }
    public func isValid() -> Bool { PetIdentity.verify(signature: signature, data: fromCard.publicKey + nonce, publicKey: fromCard.publicKey) }
}
