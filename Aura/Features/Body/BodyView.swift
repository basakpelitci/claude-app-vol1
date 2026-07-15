import SwiftUI
import Charts

@Observable
@MainActor
public final class BodyViewModel {
    public private(set) var panels: [BIAPanel] = []
    public private(set) var prediction: Prediction?

    private let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public var latest: BIAPanel? { panels.last }

    public func load() async {
        do {
            let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
            panels = try await deps.store.panels(in: yearAgo ... .now)
            if let goal = try await deps.store.activeGoal() {
                let window = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
                let recent = panels.filter { $0.date >= window }
                prediction = deps.predictionEngine.predict(panels: recent, goal: goal)
            }
        } catch {
            print("Body load failed: \(error)")
        }
    }

    public func save(_ panel: BIAPanel) async {
        do {
            try await deps.store.save(panel)
            // New composition data changes targets and health score.
            await deps.coordinator.recalculate()
            await load()
        } catch {
            print("BIA save failed: \(error)")
        }
    }
}

public struct BodyView: View {
    @State private var viewModel: BodyViewModel
    @State private var showingAddEntry = false

    public init(deps: AppDependencies) {
        _viewModel = State(initialValue: BodyViewModel(deps: deps))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    if let latest = viewModel.latest {
                        latestPanelCard(latest)
                        trendsSection
                        predictionCard
                    } else {
                        EmptyStateView(
                            systemImage: "scalemass",
                            title: "No measurements yet",
                            message: "Add your first measurement — even weight alone — and Aura starts learning your trends."
                        )
                    }
                    AuraButton("Add measurement") { showingAddEntry = true }
                }
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.bottom, AuraSpacing.s6)
            }
            .background(AuraColor.background)
            .navigationTitle("Body")
            .task { await viewModel.load() }
            .sheet(isPresented: $showingAddEntry) {
                AddBIAEntrySheet { panel in
                    Task { await viewModel.save(panel) }
                }
            }
        }
    }

    private func latestPanelCard(_ panel: BIAPanel) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                CardTitle("Latest panel · \(panel.date.formatted(.dateTime.month().day()))",
                          systemImage: "person.crop.rectangle", tint: AuraColor.health)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: AuraSpacing.s4) {
                    panelStat("Weight", String(format: "%.1f", panel.weightKg), "kg")
                    if let v = panel.bodyFatPercent { panelStat("Body fat", String(format: "%.1f", v), "%") }
                    if let v = panel.resolvedLeanBodyMassKg { panelStat("Lean mass", String(format: "%.1f", v), "kg") }
                    if let v = panel.muscleMassKg { panelStat("Muscle", String(format: "%.1f", v), "kg") }
                    if let v = panel.bodyWaterPercent { panelStat("Water", String(format: "%.1f", v), "%") }
                    if let v = panel.visceralFatRating { panelStat("Visceral", String(format: "%.0f", v), "") }
                    if let v = panel.boneMassKg { panelStat("Bone", String(format: "%.1f", v), "kg") }
                    if let v = panel.proteinPercent { panelStat("Protein", String(format: "%.1f", v), "%") }
                    if let v = panel.bmi { panelStat("BMI", String(format: "%.1f", v), "") }
                    if let v = panel.basalMetabolismKcal { panelStat("BMR", String(format: "%.0f", v), "kcal") }
                    if let v = panel.metabolicAge { panelStat("Meta. age", "\(v)", "yr") }
                    if let v = panel.subcutaneousFatPercent { panelStat("Subcut.", String(format: "%.1f", v), "%") }
                }
            }
        }
    }

    private func panelStat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(AuraColor.textPrimary)
            Text(unit.isEmpty ? label : "\(label) (\(unit))")
                .font(.caption2)
                .foregroundStyle(AuraColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendsSection: some View {
        VStack(spacing: AuraSpacing.s4) {
            trendCard("Weight", unit: "kg", tint: AuraColor.health) { $0.weightKg }
            trendCard("Body fat", unit: "%", tint: AuraColor.energy) { $0.bodyFatPercent }
            trendCard("Muscle", unit: "kg", tint: AuraColor.protein) { $0.muscleMassKg ?? $0.resolvedLeanBodyMassKg }
        }
    }

    @ViewBuilder
    private func trendCard(_ title: String, unit: String, tint: Color, value: @escaping (BIAPanel) -> Double?) -> some View {
        let points = viewModel.panels.compactMap { p in value(p).map { (p.date, $0) } }
        if points.count >= 2 {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    HStack {
                        CardTitle(title, systemImage: "chart.xyaxis.line", tint: tint)
                        Spacer()
                        if let last = points.last, let first = points.first {
                            StatDelta(delta: last.1 - first.1, unit: unit, period: "overall")
                        }
                    }
                    Chart(points, id: \.0) { point in
                        LineMark(x: .value("Date", point.0), y: .value(title, point.1))
                            .foregroundStyle(tint)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Date", point.0), y: .value(title, point.1))
                            .foregroundStyle(tint.opacity(0.1))
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                    .accessibilityLabel("\(title) trend chart")
                }
            }
        }
    }

    @ViewBuilder
    private var predictionCard: some View {
        if let prediction = viewModel.prediction {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    CardTitle("Prediction", systemImage: "scope", tint: AuraColor.accent)
                    if let goalDate = prediction.estimatedGoalDate {
                        Text("Goal around \(goalDate.formatted(.dateTime.month(.wide).day()))")
                            .font(AuraFont.cardTitle)
                            .foregroundStyle(AuraColor.textPrimary)
                    }
                    HStack(spacing: AuraSpacing.s5) {
                        VStack(alignment: .leading) {
                            Text(String(format: "%.1f kg", prediction.projectedWeightKg))
                                .font(AuraFont.body.weight(.semibold))
                                .foregroundStyle(AuraColor.textPrimary)
                            Text("projected weight")
                                .font(.caption2)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                        if let bf = prediction.projectedBodyFatPercent {
                            VStack(alignment: .leading) {
                                Text(String(format: "%.1f %%", bf))
                                    .font(AuraFont.body.weight(.semibold))
                                    .foregroundStyle(AuraColor.textPrimary)
                                Text("projected body fat")
                                    .font(.caption2)
                                    .foregroundStyle(AuraColor.textSecondary)
                            }
                        }
                    }
                    if !prediction.weeklySeries.isEmpty {
                        Chart(prediction.weeklySeries, id: \.date) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Weight", point.weightKg))
                                .foregroundStyle(AuraColor.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 120)
                    }
                    Text("Confidence: \(prediction.confidence.rawValue) · based on your recent trend")
                        .font(AuraFont.caption)
                        .foregroundStyle(AuraColor.textSecondary)
                }
            }
        }
    }
}

/// Manual BIA entry. Only weight is required — everything else is optional.
struct AddBIAEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (BIAPanel) -> Void

    @State private var date: Date = .now
    @State private var fields: [String: String] = [:]

    private let optionalFields: [(key: String, label: String)] = [
        ("bodyFat", "Body fat %"), ("lbm", "Lean body mass (kg)"),
        ("muscle", "Muscle mass (kg)"), ("water", "Body water %"),
        ("visceral", "Visceral fat"), ("bone", "Bone mass (kg)"),
        ("protein", "Protein %"), ("bmi", "BMI"),
        ("bmr", "Basal metabolism (kcal)"), ("metaAge", "Metabolic age"),
        ("subcut", "Subcutaneous fat %"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    numericField("weight", "Weight (kg) — required")
                }
                Section("Body composition (optional)") {
                    ForEach(optionalFields, id: \.key) { field in
                        numericField(field.key, field.label)
                    }
                }
            }
            .navigationTitle("Add measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(value("weight") == nil)
                }
            }
        }
    }

    private func numericField(_ key: String, _ label: String) -> some View {
        TextField(label, text: Binding(
            get: { fields[key] ?? "" },
            set: { fields[key] = $0 }
        ))
        .keyboardType(.decimalPad)
    }

    private func value(_ key: String) -> Double? {
        fields[key].flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
    }

    private func save() {
        guard let weight = value("weight") else { return }
        onSave(BIAPanel(
            date: date,
            weightKg: weight,
            bodyFatPercent: value("bodyFat"),
            leanBodyMassKg: value("lbm"),
            muscleMassKg: value("muscle"),
            bodyWaterPercent: value("water"),
            visceralFatRating: value("visceral"),
            boneMassKg: value("bone"),
            proteinPercent: value("protein"),
            bmi: value("bmi"),
            basalMetabolismKcal: value("bmr"),
            metabolicAge: value("metaAge").map(Int.init),
            subcutaneousFatPercent: value("subcut")
        ))
        dismiss()
    }
}
