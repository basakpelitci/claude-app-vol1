import Foundation
import SwiftData
import SwiftUI

/// Composition root. Builds the model container, the LocalStore actor, the
/// engines, and the recalculation coordinator, and hands them to features
/// through the SwiftUI environment. Previews and tests build their own
/// graph over an in-memory container.
@MainActor
@Observable
public final class AppDependencies {

    public let store: LocalStore
    public let coordinator: RecalculationCoordinator

    // Engines are stateless; shared instances avoid re-configuring calendars.
    public let goalEngine = GoalEngine()
    public let nutritionEngine = NutritionEngine()
    public let predictionEngine = PredictionEngine()
    public let cycleEngine = CycleEngine()
    public let motivationEngine = MotivationEngine()

    public init(container: ModelContainer) {
        let store = LocalStore(modelContainer: container)
        self.store = store
        self.coordinator = RecalculationCoordinator(store: store)
    }

    public static func live() -> AppDependencies {
        do {
            return AppDependencies(container: try PersistenceContainer.live())
        } catch {
            // A broken store on disk is unrecoverable in-process; fall back
            // to memory so the app still opens and can guide the user.
            let fallback = try! PersistenceContainer.ephemeral()
            return AppDependencies(container: fallback)
        }
    }

    public static func preview() -> AppDependencies {
        AppDependencies(container: try! PersistenceContainer.ephemeral())
    }
}

public extension EnvironmentValues {
    @Entry var dependencies: AppDependencies? = nil
}
