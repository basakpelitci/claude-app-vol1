import SwiftUI

public struct NutritionView: View {
    @State private var viewModel: NutritionViewModel
    @State private var addingTo: MealType?

    public init(deps: AppDependencies) {
        _viewModel = State(initialValue: NutritionViewModel(deps: deps))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    dayPager
                    summaryHeader
                    ForEach(MealType.allCases, id: \.self) { type in
                        mealSection(type)
                    }
                    waterSection
                }
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.bottom, AuraSpacing.s6)
            }
            .background(AuraColor.background)
            .navigationTitle("Nutrition")
            .task { await viewModel.load() }
            .sheet(item: $addingTo) { type in
                AddFoodSheet(viewModel: viewModel, mealType: type)
            }
        }
    }

    private var dayPager: some View {
        HStack {
            Button {
                viewModel.selectedDay = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDay)!
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(viewModel.isToday ? "Today" : viewModel.selectedDay.formatted(.dateTime.weekday(.wide).month().day()))
                .font(AuraFont.cardTitle)
                .foregroundStyle(AuraColor.textPrimary)
            Spacer()
            Button {
                viewModel.selectedDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDay)!
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(viewModel.isToday)
        }
        .foregroundStyle(AuraColor.accent)
        .padding(.top, AuraSpacing.s2)
    }

    private var summaryHeader: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                if let targets = viewModel.targets {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(max(Int(targets.calories - viewModel.caloriesConsumed), 0))")
                            .font(AuraFont.metricValue)
                            .foregroundStyle(AuraColor.textPrimary)
                            .contentTransition(.numericText())
                        Text("kcal remaining")
                            .font(AuraFont.caption)
                            .foregroundStyle(AuraColor.textSecondary)
                        Spacer()
                        if let score = viewModel.dayScore {
                            Text("Meal score \(score.grade)")
                                .font(AuraFont.chip)
                                .padding(.horizontal, AuraSpacing.s3)
                                .padding(.vertical, 6)
                                .background(AuraColor.accentSoft, in: .capsule)
                                .foregroundStyle(AuraColor.accent)
                        }
                    }
                    MetricProgressBar(
                        label: "Calories",
                        value: viewModel.caloriesConsumed, target: targets.calories,
                        unit: "kcal", tint: AuraColor.energy
                    )
                    MetricProgressBar(
                        label: "Protein",
                        value: viewModel.entries.reduce(0) { $0 + $1.proteinG },
                        target: targets.proteinG, unit: "g", tint: AuraColor.protein
                    )
                } else {
                    Text("Set up your profile to see personalized targets.")
                        .font(AuraFont.body)
                        .foregroundStyle(AuraColor.textSecondary)
                }
            }
        }
    }

    private func mealSection(_ type: MealType) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    Text(type.rawValue.capitalized)
                        .font(AuraFont.cardTitle)
                        .foregroundStyle(AuraColor.textPrimary)
                    Spacer()
                    let kcal = viewModel.entries(for: type).reduce(0) { $0 + $1.calories }
                    if kcal > 0 {
                        Text("\(Int(kcal)) kcal")
                            .font(AuraFont.caption)
                            .foregroundStyle(AuraColor.textSecondary)
                    }
                    Button {
                        addingTo = type
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AuraColor.accent)
                    }
                    .accessibilityLabel("Add food to \(type.rawValue)")
                }
                ForEach(viewModel.entries(for: type)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.foodName)
                                .font(AuraFont.body)
                                .foregroundStyle(AuraColor.textPrimary)
                            Text("P\(Int(entry.proteinG)) · C\(Int(entry.carbsG)) · F\(Int(entry.fatG))")
                                .font(AuraFont.caption)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                        Spacer()
                        Text("\(Int(entry.calories))")
                            .font(AuraFont.body.weight(.medium))
                            .foregroundStyle(AuraColor.textSecondary)
                    }
                    .contentShape(.rect)
                    .contextMenu {
                        Button {
                            Task { await viewModel.toggleFavorite(entry) }
                        } label: {
                            Label(entry.isFavorite ? "Unfavorite" : "Favorite",
                                  systemImage: entry.isFavorite ? "heart.slash" : "heart")
                        }
                        Button(role: .destructive) {
                            Task { await viewModel.delete(entry) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var waterSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                CardTitle("Water", systemImage: "drop.fill", tint: AuraColor.water)
                MetricProgressBar(
                    label: "Hydration",
                    value: viewModel.waterMl,
                    target: viewModel.targets?.waterMl ?? 2000,
                    unit: "ml", tint: AuraColor.water
                )
                HStack {
                    ForEach([250.0, 500.0, 750.0], id: \.self) { amount in
                        Button {
                            Task { await viewModel.addWater(ml: amount) }
                        } label: {
                            Text("+\(Int(amount))")
                                .font(AuraFont.chip)
                                .padding(.horizontal, AuraSpacing.s3)
                                .padding(.vertical, 6)
                                .background(AuraColor.water.opacity(0.16), in: .capsule)
                                .foregroundStyle(AuraColor.water)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

extension MealType: Identifiable {
    public var id: String { rawValue }
}

/// Add-food flow: search the catalog, pick from favorites, or enter macros
/// manually. Recipes log one serving.
struct AddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NutritionViewModel
    let mealType: MealType

    @State private var query = ""
    @State private var manualName = ""
    @State private var manualCalories = ""
    @State private var manualProtein = ""
    @State private var manualCarbs = ""
    @State private var manualFat = ""
    @State private var manualFiber = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Search") {
                    TextField("Search foods…", text: $query)
                        .onChange(of: query) { _, q in
                            Task { await viewModel.search(q) }
                        }
                    ForEach(viewModel.searchResults) { item in
                        Button {
                            log(item)
                        } label: {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("\(Int(item.per100g.kcal)) kcal / 100g")
                                    .foregroundStyle(AuraColor.textSecondary)
                            }
                        }
                    }
                }

                if !viewModel.favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(viewModel.favorites) { fav in
                            Button {
                                logFavorite(fav)
                            } label: {
                                HStack {
                                    Text(fav.foodName)
                                    Spacer()
                                    Text("\(Int(fav.calories)) kcal")
                                        .foregroundStyle(AuraColor.textSecondary)
                                }
                            }
                        }
                    }
                }

                if !viewModel.recipes.isEmpty {
                    Section("Recipes") {
                        ForEach(viewModel.recipes) { recipe in
                            Button {
                                log(recipe)
                            } label: {
                                HStack {
                                    Text(recipe.name)
                                    Spacer()
                                    Text("\(Int(recipe.perServing.kcal)) kcal / serving")
                                        .foregroundStyle(AuraColor.textSecondary)
                                }
                            }
                        }
                    }
                }

                Section("Manual entry") {
                    TextField("Name", text: $manualName)
                    TextField("Calories", text: $manualCalories).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $manualProtein).keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $manualCarbs).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $manualFat).keyboardType(.decimalPad)
                    TextField("Fiber (g)", text: $manualFiber).keyboardType(.decimalPad)
                    Button("Log \(mealType.rawValue)") {
                        logManual()
                    }
                    .disabled(manualName.isEmpty || Double(manualCalories) == nil)
                }
            }
            .navigationTitle("Add to \(mealType.rawValue.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func log(_ item: FoodItem) {
        let m = item.per100g
        save(name: item.name, serving: "100 g", kcal: m.kcal, p: m.proteinG, c: m.carbsG, f: m.fatG, fiber: m.fiberG)
    }

    private func logFavorite(_ fav: MealEntry) {
        save(name: fav.foodName, serving: fav.servingDescription,
             kcal: fav.calories, p: fav.proteinG, c: fav.carbsG, f: fav.fatG, fiber: fav.fiberG)
    }

    private func log(_ recipe: Recipe) {
        let m = recipe.perServing
        save(name: recipe.name, serving: "1 serving", kcal: m.kcal, p: m.proteinG, c: m.carbsG, f: m.fatG, fiber: m.fiberG, recipeID: recipe.id)
    }

    private func logManual() {
        save(
            name: manualName, serving: "custom",
            kcal: Double(manualCalories) ?? 0,
            p: Double(manualProtein) ?? 0,
            c: Double(manualCarbs) ?? 0,
            f: Double(manualFat) ?? 0,
            fiber: Double(manualFiber) ?? 0
        )
    }

    private func save(name: String, serving: String, kcal: Double, p: Double, c: Double, f: Double, fiber: Double, recipeID: UUID? = nil) {
        let entry = MealEntry(
            date: viewModel.isToday ? .now : viewModel.selectedDay,
            mealType: mealType, foodName: name, servingDescription: serving,
            calories: kcal, proteinG: p, carbsG: c, fatG: f, fiberG: fiber, recipeID: recipeID
        )
        Task {
            await viewModel.log(entry)
            dismiss()
        }
    }
}
