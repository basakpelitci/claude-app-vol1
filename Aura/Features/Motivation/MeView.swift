import SwiftUI

@Observable
@MainActor
public final class MeViewModel {
    public private(set) var whyIStarted: MotivationArtifact?
    public private(set) var futureMe: MotivationArtifact?
    public private(set) var letters: [MotivationArtifact] = []
    public private(set) var milestones: [Milestone] = []
    public private(set) var identityStatements: [String] = []
    public private(set) var timeline: [DailySnapshot] = []

    let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public func load() async {
        do {
            whyIStarted = try await deps.store.artifacts(of: .whyIStarted).first
            futureMe = try await deps.store.artifacts(of: .futureMe).first
            letters = try await deps.store.artifacts(of: .letterToMyself)
            milestones = try await deps.store.milestones()

            guard let goal = try await deps.store.activeGoal() else { return }
            let start = Calendar.current.date(byAdding: .day, value: -90, to: .now)!
            let snapshots = try await deps.store.snapshots(in: start ... .now)
            timeline = snapshots
            let panels = try await deps.store.panels(in: start ... .now)
            identityStatements = deps.motivationEngine.identityStatements(
                .init(goal: goal, panels: panels, snapshots: snapshots,
                      wardrobeItems: [], existingMilestones: milestones)
            )

            // Deliver any letters that have come due.
            for letter in deps.motivationEngine.lettersToDeliver(letters) {
                var delivered = letter
                delivered.deliveredAt = .now
                try await deps.store.save(delivered)
            }
        } catch {
            print("Me load failed: \(error)")
        }
    }

    public func save(_ artifact: MotivationArtifact) async {
        do {
            try await deps.store.save(artifact)
            await load()
        } catch {
            print("Artifact save failed: \(error)")
        }
    }
}

/// The motivation hub: identity, artifacts, milestones, cycle, settings.
public struct MeView: View {
    @State private var viewModel: MeViewModel
    private let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
        _viewModel = State(initialValue: MeViewModel(deps: deps))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    whyCard
                    identityCard
                    NavigationLink {
                        ArtifactEditorView(
                            kind: .futureMe,
                            existing: viewModel.futureMe,
                            prompt: "Describe the person you're becoming. What does their ordinary Tuesday look like?",
                            viewModel: viewModel
                        )
                    } label: {
                        linkCard("person.crop.circle.badge.clock", "Future me",
                                 viewModel.futureMe?.text.prefix(60).description ?? "Write a picture of who you're becoming")
                    }
                    NavigationLink {
                        LetterView(viewModel: viewModel)
                    } label: {
                        linkCard("envelope.fill", "Letter to myself", letterSubtitle)
                    }
                    NavigationLink {
                        MilestonesView(milestones: viewModel.milestones)
                    } label: {
                        linkCard("trophy.fill", "Milestones", "\(viewModel.milestones.count) unlocked")
                    }
                    NavigationLink {
                        TransformationTimelineView(viewModel: viewModel)
                    } label: {
                        linkCard("chart.line.uptrend.xyaxis", "Transformation timeline", "Your journey, replayed")
                    }
                    Divider().padding(.vertical, AuraSpacing.s2)
                    NavigationLink {
                        CyclePlannerView(deps: deps)
                    } label: {
                        linkCard("moonphase.waxing.crescent", "Cycle planner", "Phase-aware targets and training")
                    }
                }
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.bottom, AuraSpacing.s6)
            }
            .background(AuraColor.background)
            .navigationTitle("Me")
            .task { await viewModel.load() }
        }
    }

    private var letterSubtitle: String {
        if let next = viewModel.letters.first(where: { $0.deliveredAt == nil }),
           let deliverAt = next.deliverAt {
            return "Opens \(deliverAt.formatted(.dateTime.month().day()))"
        }
        return "Write to the future you"
    }

    private var whyCard: some View {
        NavigationLink {
            ArtifactEditorView(
                kind: .whyIStarted,
                existing: viewModel.whyIStarted,
                prompt: "Why did you start? Your own words will carry you further than any quote.",
                viewModel: viewModel
            )
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                    CardTitle("Why I started", systemImage: "leaf.fill", tint: AuraColor.accent)
                    Text(viewModel.whyIStarted?.text ?? "Tap to capture your why — the root of everything.")
                        .font(AuraFont.body.italic())
                        .foregroundStyle(AuraColor.textPrimary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var identityCard: some View {
        if !viewModel.identityStatements.isEmpty {
            SurfaceCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                    CardTitle("Who you're becoming", systemImage: "person.fill.checkmark", tint: AuraColor.celebrate)
                    ForEach(viewModel.identityStatements, id: \.self) { statement in
                        Label(statement, systemImage: "checkmark.seal.fill")
                            .font(AuraFont.body)
                            .foregroundStyle(AuraColor.textPrimary)
                    }
                }
            }
        }
    }

    private func linkCard(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        SurfaceCard {
            HStack(spacing: AuraSpacing.s4) {
                Image(systemName: icon)
                    .foregroundStyle(AuraColor.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AuraFont.body.weight(.medium))
                        .foregroundStyle(AuraColor.textPrimary)
                    Text(subtitle)
                        .font(AuraFont.caption)
                        .foregroundStyle(AuraColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AuraColor.textSecondary)
            }
        }
    }
}

/// Shared editor for Why I Started / Future Me / identity artifacts.
struct ArtifactEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: MotivationArtifactKind
    let existing: MotivationArtifact?
    let prompt: String
    let viewModel: MeViewModel

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            Text(prompt)
                .font(AuraFont.body)
                .foregroundStyle(AuraColor.textSecondary)
            TextEditor(text: $text)
                .font(AuraFont.body)
                .scrollContentBackground(.hidden)
                .padding(AuraSpacing.s3)
                .background(AuraColor.surface, in: .rect(cornerRadius: AuraRadius.card, style: .continuous))
                .frame(minHeight: 180)
            AuraButton("Save") {
                var artifact = existing ?? MotivationArtifact(kind: kind, text: "")
                artifact.text = text
                Task {
                    await viewModel.save(artifact)
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(AuraSpacing.screen)
        .background(AuraColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { text = existing?.text ?? "" }
    }
}

/// Write a letter, sealed until its delivery date.
struct LetterView: View {
    let viewModel: MeViewModel

    @State private var text = ""
    @State private var deliverAt = Calendar.current.date(byAdding: .day, value: 30, to: .now)!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                ForEach(viewModel.letters.filter { $0.deliveredAt != nil }) { letter in
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                            CardTitle("Delivered \(letter.deliveredAt!.formatted(.dateTime.month().day()))",
                                      systemImage: "envelope.open.fill", tint: AuraColor.celebrate)
                            Text(letter.text)
                                .font(AuraFont.body)
                                .foregroundStyle(AuraColor.textPrimary)
                        }
                    }
                }
                ForEach(viewModel.letters.filter { $0.deliveredAt == nil }) { letter in
                    SurfaceCard {
                        CardTitle(
                            "Sealed — opens \(letter.deliverAt?.formatted(.dateTime.month().day()) ?? "soon")",
                            systemImage: "envelope.badge.clock", tint: AuraColor.textSecondary
                        )
                    }
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                        CardTitle("New letter", systemImage: "square.and.pencil", tint: AuraColor.accent)
                        TextEditor(text: $text)
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                        DatePicker("Deliver on", selection: $deliverAt, in: Date.now..., displayedComponents: .date)
                        AuraButton("Seal letter") {
                            let letter = MotivationArtifact(kind: .letterToMyself, text: text, deliverAt: deliverAt)
                            text = ""
                            Task { await viewModel.save(letter) }
                        }
                    }
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
        }
        .background(AuraColor.background)
        .navigationTitle("Letters")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MilestonesView: View {
    let milestones: [Milestone]

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s3) {
                if milestones.isEmpty {
                    EmptyStateView(
                        systemImage: "trophy",
                        title: "Milestones ahead",
                        message: "Keep showing up — your first milestone is closer than you think."
                    )
                }
                ForEach(milestones) { milestone in
                    SurfaceCard {
                        HStack(spacing: AuraSpacing.s4) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(AuraColor.celebrate)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.title)
                                    .font(AuraFont.body.weight(.semibold))
                                    .foregroundStyle(AuraColor.textPrimary)
                                Text(milestone.detail)
                                    .font(AuraFont.caption)
                                    .foregroundStyle(AuraColor.textSecondary)
                            }
                            Spacer()
                            Text(milestone.achievedAt.formatted(.dateTime.month().day()))
                                .font(.caption2)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
        }
        .background(AuraColor.background)
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The journey replayed: momentum over time next to the user's why.
struct TransformationTimelineView: View {
    let viewModel: MeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                if let why = viewModel.whyIStarted {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                            CardTitle("Where it began", systemImage: "leaf.fill", tint: AuraColor.accent)
                            Text("“\(why.text)”")
                                .font(AuraFont.body.italic())
                                .foregroundStyle(AuraColor.textPrimary)
                        }
                    }
                }
                if viewModel.timeline.count >= 2 {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                            CardTitle("Momentum over time", systemImage: "flame.fill", tint: AuraColor.accent)
                            TrendSparkline(
                                values: viewModel.timeline.map { Double($0.momentum.overall) },
                                tint: AuraColor.accent
                            )
                            Text("\(viewModel.timeline.count) days logged on this journey")
                                .font(AuraFont.caption)
                                .foregroundStyle(AuraColor.textSecondary)
                        }
                    }
                } else {
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "Your story is just starting",
                        message: "As days accumulate, this timeline becomes the proof of how far you've come."
                    )
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
        }
        .background(AuraColor.background)
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }
}
