import Foundation

/// Shared, pure math used across engines. Kept together so formulas are
/// testable in one place and never re-derived ad hoc in features.
public enum HealthMath {

    public static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// Katch-McArdle BMR from lean body mass (preferred when BIA data exists).
    public static func katchMcArdleBMR(leanBodyMassKg: Double) -> Double {
        370 + 21.6 * leanBodyMassKg
    }

    /// Mifflin-St Jeor BMR fallback when no composition data is available.
    public static func mifflinStJeorBMR(
        weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male:        return base + 5
        case .female:      return base - 161
        case .unspecified: return base - 78 // midpoint of the sex offsets
        }
    }

    /// Rough lean-mass estimate from anthropometrics when no BIA panel exists
    /// (Boer formula). Callers must mark results low-confidence.
    public static func estimatedLeanBodyMassKg(
        weightKg: Double, heightCm: Double, sex: BiologicalSex
    ) -> Double {
        switch sex {
        case .male:
            return 0.407 * weightKg + 0.267 * heightCm - 19.2
        case .female, .unspecified:
            return 0.252 * weightKg + 0.473 * heightCm - 48.3
        }
    }

    /// Exponentially weighted moving average; `alpha` in (0…1], higher = more
    /// weight on recent values. Input ordered oldest → newest.
    public static func ewma(_ values: [Double], alpha: Double = 0.3) -> Double? {
        guard let first = values.first else { return nil }
        return values.dropFirst().reduce(first) { acc, v in alpha * v + (1 - alpha) * acc }
    }

    /// Weighted least-squares slope per day for (daysAgo, value) samples,
    /// weighting recent samples more via exponential decay. Returns nil with
    /// fewer than 3 points. `x` is days relative to any epoch, ascending.
    public static func weightedSlopePerDay(x: [Double], y: [Double], decay: Double = 0.05) -> Double? {
        guard x.count == y.count, x.count >= 3, let latest = x.last else { return nil }
        let w = x.map { exp(-decay * (latest - $0)) }
        let sw = w.reduce(0, +)
        guard sw > 0 else { return nil }
        let mx = zip(w, x).map(*).reduce(0, +) / sw
        let my = zip(w, y).map(*).reduce(0, +) / sw
        var num = 0.0, den = 0.0
        for i in x.indices {
            num += w[i] * (x[i] - mx) * (y[i] - my)
            den += w[i] * (x[i] - mx) * (x[i] - mx)
        }
        guard den > 1e-9 else { return nil }
        return num / den
    }

    /// Ratio score with partial credit: actual/target capped at 1.
    public static func attainment(_ actual: Double, target: Double) -> Double {
        guard target > 0 else { return 1 }
        return clamp(actual / target, 0, 1)
    }

    /// Score for "stay near or under target" metrics like calories: full
    /// credit up to the target, then a gentle linear falloff — 30% over
    /// target still earns a meaningful score (never a cliff, never zero for
    /// one hard day).
    public static func adherenceWithOvershoot(_ actual: Double, target: Double) -> Double {
        guard target > 0 else { return 1 }
        let ratio = actual / target
        if ratio <= 1 {
            // Under-eating far below target is also not rewarded: full credit
            // from 70% of target upward, scaling below that.
            return ratio >= 0.7 ? 1 : clamp(ratio / 0.7, 0, 1)
        }
        return clamp(1 - (ratio - 1) * 1.5, 0, 1)
    }
}

public extension Calendar {
    /// Whole-day distance between two dates (self's time zone).
    func daysBetween(_ from: Date, _ to: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: from), to: startOfDay(for: to)).day ?? 0
    }
}
