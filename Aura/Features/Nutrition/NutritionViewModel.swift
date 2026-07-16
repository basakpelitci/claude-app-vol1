import Foundation
import Observation

@Observable
@MainActor
public final class NutritionViewModel {

    public var selectedDay: Date = .now {
        didSet { Task { await load() } }
    }
    public private(set) var entries: [MealEntry] = []
    public private(set) var waterEntries: [WaterEntry] = []
    public private(set) var targets: DailyTargets?
    public private(set) var dayScore: NutritionEngine.DayScore?
    public private(set) var favorites: [MealEntry] = []
    public private(set) var recipes: [Recipe] = []
    public private(set) var searchResults: [FoodItem] = []

    private let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public var isToday: Bool { Calendar.current.isDateInToday(selectedDay) }

    public var caloriesConsumed: Double { entries.reduce(0) { $0 + $1.calories } }
    public var waterMl: Double { waterEntries.reduce(0) { $0 + $1.amountMl } }

    public func entries(for type: MealType) -> [MealEntry] {
        entries.filter { $0.mealType == type }
    }

    public func load() async {
        do {
            entries = try await deps.store.entries(on: selectedDay)
            waterEntries = try await deps.store.entries(on: selectedDay)
            favorites = try await deps.store.favorites()
            recipes = try await deps.store.recipes()

            // Targets come from the snapshot when present (already
            // phase-adjusted); otherwise ask the Goal Engine directly.
            if let snapshot = try await deps.store.snapshot(on: selectedDay) {
                targets = snapshot.targets
            } else if let profile = try await deps.store.currentProfile(),
                      let goal = try await deps.store.activeGoal() {
                let latest = try await deps.store.latestPanel()
                let records = profile.cycleTrackingEnabled ? try await deps.store.records() : []
                let phase = deps.cycleEngine.state(on: selectedDay, records: records)?.phase
                targets = deps.goalEngine.targets(for: .init(
                    profile: profile, goal: goal, latestBIA: latest, cyclePhase: phase
                ))
            }
            if let targets {
                dayScore = deps.nutritionEngine.score(entries: entries, targets: targets)
            }
        } catch {
            print("Nutrition load failed: \(error)")
        }
    }

    public func search(_ query: String) async {
        do {
            searchResults = try await deps.store.search(query)
        } catch {
            searchResults = []
        }
    }

    public func log(_ entry: MealEntry) async {
        do {
            try await deps.store.save(entry)
            await refreshAfterWrite()
        } catch {
            print("Meal log failed: \(error)")
        }
    }

    public func delete(_ entry: MealEntry) async {
        do {
            try await deps.store.delete(id: entry.id)
            await refreshAfterWrite()
        } catch {
            print("Meal delete failed: \(error)")
        }
    }

    public func toggleFavorite(_ entry: MealEntry) async {
        var updated = entry
        updated.isFavorite.toggle()
        do {
            try await deps.store.save(updated)
            await load()
        } catch {
            print("Favorite toggle failed: \(error)")
        }
    }

    public func addWater(ml: Double) async {
        do {
            try await deps.store.save(WaterEntry(date: selectedDay, amountMl: ml))
            await refreshAfterWrite()
        } catch {
            print("Water add failed: \(error)")
        }
    }

    private func refreshAfterWrite() async {
        if isToday {
            await deps.coordinator.recalculate()
        }
        await load()
    }
}
