import Foundation

public enum FuelProcessor {
    public static func process(raw: Double) -> Int {
        guard raw > 0 else { return 0 }
        return Int(log(1 + raw) * 3)
    }
    public static func processMultiple(rawValues: [Double]) -> Int {
        min(process(raw: rawValues.reduce(0.0, +)), EconomyEngine.fuelXPCap)
    }
}
