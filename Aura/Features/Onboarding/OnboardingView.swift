import SwiftUI

/// Onboarding captures the "why" BEFORE any number — emotion first, then
/// profile, goal, activity, cycle opt-in, and a targets reveal computed live
/// by the Goal Engine (never a crash promise).
public struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome, why, profile, goal, activity, cycle, reveal
    }

    @State private var step: Step = .welcome

    // Why
    @State private var whyText = ""
    // Profile
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now)!
    @State private var heightCm = 165.0
    @State private var sex: BiologicalSex = .female
    // Goal
    @State private var currentWeight = 70.0
    @State private var targetWeight = 62.0
    @State private var weeklyRate = 0.5
    // Activity + cycle
    @State private var activityLevel: ActivityLevel = .light
    @State private var cycleOptIn = false

    @State private var revealedTargets: DailyTargets?
    @State private var revealedPrediction: Prediction?

    private let deps: AppDependencies
    private let onComplete: () -> Void

    public init(deps: AppDependencies, onComplete: @escaping () -> Void) {
        self.deps = deps
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: AuraSpacing.s5) {
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .tint(AuraColor.accent)
                .padding(.horizontal, AuraSpacing.screen)
            ScrollView {
                Group {
                    switch step {
                    case .welcome: welcome
                    case .why: why
                    case .profile: profile
                    case .goal: goalStep
                    case .activity: activity
                    case .cycle: cycle
                    case .reveal: reveal
                    }
                }
                .padding(.horizontal, AuraSpacing.screen)
            }
            footer
        }
        .padding(.vertical, AuraSpacing.s5)
        .background(AuraColor.background)
    }

    private var welcome: some View {
        VStack(spacing: AuraSpacing.s5) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(AuraColor.accent)
                .padding(.top, AuraSpacing.s7)
            Text("Welcome to Aura")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AuraColor.textPrimary)
            Text("This isn't a diet app. It's a system for staying connected to your goal — on strong days and soft days alike. No shame, no streaks to break. Just momentum.")
                .font(AuraFont.body)
                .foregroundStyle(AuraColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var why: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            stepTitle("Before any numbers…", subtitle: "Why did you start? Your own words will matter more than any target we compute.")
            TextEditor(text: $whyText)
                .font(AuraFont.body)
                .scrollContentBackground(.hidden)
                .padding(AuraSpacing.s3)
                .background(AuraColor.surface, in: .rect(cornerRadius: AuraRadius.card, style: .continuous))
                .frame(minHeight: 160)
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            stepTitle("About you", subtitle: "Used only to personalize your targets.")
            SurfaceCard {
                VStack(spacing: AuraSpacing.s4) {
                    TextField("Name", text: $name)
                    DatePicker("Birthday", selection: $birthDate, displayedComponents: .date)
                    Stepper("Height: \(Int(heightCm)) cm", value: $heightCm, in: 120...220)
                    Picker("Biological sex", selection: $sex) {
                        Text("Female").tag(BiologicalSex.female)
                        Text("Male").tag(BiologicalSex.male)
                        Text("Prefer not to say").tag(BiologicalSex.unspecified)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            stepTitle("Your goal", subtitle: "Aura keeps the pace sustainable — that's how you'll actually get there.")
            SurfaceCard {
                VStack(spacing: AuraSpacing.s4) {
                    Stepper(String(format: "Current weight: %.1f kg", currentWeight),
                            value: $currentWeight, in: 35...250, step: 0.5)
                    Stepper(String(format: "Target weight: %.1f kg", targetWeight),
                            value: $targetWeight, in: 35...250, step: 0.5)
                    VStack(alignment: .leading) {
                        Text(String(format: "Pace: %.2f kg / week", weeklyRate))
                        Slider(value: $weeklyRate, in: Goal.minWeeklyRateKg...Goal.maxWeeklyRateKg, step: 0.05)
                            .tint(AuraColor.accent)
                        Text("Gentler paces preserve muscle and are far easier to sustain.")
                            .font(AuraFont.caption)
                            .foregroundStyle(AuraColor.textSecondary)
                    }
                }
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            stepTitle("How active are you?", subtitle: "Be honest — targets adjust automatically as your data comes in.")
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                Button {
                    activityLevel = level
                } label: {
                    SurfaceCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label(for: level))
                                    .font(AuraFont.body.weight(.medium))
                                    .foregroundStyle(AuraColor.textPrimary)
                                Text(detail(for: level))
                                    .font(AuraFont.caption)
                                    .foregroundStyle(AuraColor.textSecondary)
                            }
                            Spacer()
                            Image(systemName: activityLevel == level ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(AuraColor.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cycle: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            stepTitle("Cycle-aware targets", subtitle: "Optional and private. Aura can adapt calories, protein, hydration, and training to your menstrual phase — so a luteal week never feels like failure.")
            SurfaceCard {
                Toggle("Enable cycle tracking", isOn: $cycleOptIn)
                    .tint(AuraColor.cycle)
            }
            Text("Cycle data stays on this device and can be deleted at any time.")
                .font(AuraFont.caption)
                .foregroundStyle(AuraColor.textSecondary)
        }
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            stepTitle("Your plan", subtitle: "Computed for your body — and recomputed automatically as it changes.")
            if let t = revealedTargets {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                        targetRow("bolt.fill", "Calories", "\(Int(t.calories)) kcal", AuraColor.energy)
                        targetRow("fork.knife", "Protein", "\(Int(t.proteinG)) g — based on your lean mass", AuraColor.protein)
                        targetRow("drop.fill", "Water", String(format: "%.1f L", t.waterMl / 1000), AuraColor.water)
                        targetRow("figure.walk", "Steps", "\(t.steps)", AuraColor.accent)
                        targetRow("moon.zzz.fill", "Sleep", String(format: "%.1f h", t.sleepHours), AuraColor.health)
                    }
                }
                if let prediction = revealedPrediction, let date = prediction.estimatedGoalDate {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                            CardTitle("Sustainable estimate", systemImage: "scope", tint: AuraColor.accent)
                            Text("Around \(date.formatted(.dateTime.month(.wide).day().year()))")
                                .font(AuraFont.cardTitle)
                                .foregroundStyle(AuraColor.textPrimary)
                            Text("At your chosen pace. Real data will refine this every week.")
                                .font(AuraFont.caption)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                    }
                }
            }
        }
        .onAppear { computeReveal() }
    }

    private var footer: some View {
        HStack {
            if step != .welcome {
                AuraButton("Back", style: .quiet) {
                    withAnimation(AuraMotion.gentle) {
                        step = Step(rawValue: step.rawValue - 1) ?? .welcome
                    }
                }
            }
            AuraButton(step == .reveal ? "Start my journey" : "Continue") {
                if step == .reveal {
                    complete()
                } else {
                    withAnimation(AuraMotion.gentle) {
                        step = Step(rawValue: step.rawValue + 1) ?? .reveal
                    }
                }
            }
            .disabled(step == .profile && name.isEmpty)
        }
        .padding(.horizontal, AuraSpacing.screen)
    }

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(AuraColor.textPrimary)
            Text(subtitle)
                .font(AuraFont.body)
                .foregroundStyle(AuraColor.textSecondary)
        }
        .padding(.top, AuraSpacing.s4)
    }

    private func targetRow(_ icon: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
            Text(label).font(AuraFont.body).foregroundStyle(AuraColor.textPrimary)
            Spacer()
            Text(value).font(AuraFont.body.weight(.semibold)).foregroundStyle(AuraColor.textPrimary)
        }
    }

    private func label(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Mostly seated"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .active: return "Active"
        case .veryActive: return "Very active"
        }
    }

    private func detail(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Desk days, little planned exercise"
        case .light: return "Walks and 1–2 workouts a week"
        case .moderate: return "3–4 workouts a week"
        case .active: return "Training most days"
        case .veryActive: return "Physical job or twice-daily training"
        }
    }

    private func makeProfileAndGoal() -> (UserProfile, Goal) {
        let profile = UserProfile(
            name: name, birthDate: birthDate, heightCm: heightCm,
            biologicalSex: sex, activityLevel: activityLevel,
            cycleTrackingEnabled: cycleOptIn && sex == .female
        )
        let goal = Goal(
            kind: .fatLoss, targetWeightKg: targetWeight,
            weeklyRateKg: weeklyRate, startWeightKg: currentWeight
        )
        return (profile, goal)
    }

    private func computeReveal() {
        let (profile, goal) = makeProfileAndGoal()
        let seedPanel = BIAPanel(date: .now, weightKg: currentWeight)
        revealedTargets = deps.goalEngine.targets(for: .init(profile: profile, goal: goal, latestBIA: seedPanel))
        revealedPrediction = deps.predictionEngine.predict(panels: [seedPanel], goal: goal)
    }

    private func complete() {
        let (profile, goal) = makeProfileAndGoal()
        Task {
            do {
                try await deps.store.save(profile)
                try await deps.store.save(goal)
                try await deps.store.save(BIAPanel(date: .now, weightKg: currentWeight))
                if !whyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try await deps.store.save(MotivationArtifact(kind: .whyIStarted, text: whyText))
                }
                await deps.coordinator.recalculate()
                onComplete()
            } catch {
                print("Onboarding save failed: \(error)")
            }
        }
    }
}
