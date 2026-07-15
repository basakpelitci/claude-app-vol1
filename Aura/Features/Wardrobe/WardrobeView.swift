import SwiftUI
import PhotosUI
import UIKit

@Observable
@MainActor
public final class WardrobeViewModel {
    public private(set) var collections: [WardrobeCollection] = []
    public private(set) var items: [WardrobeItem] = []
    public var selectedCollectionID: UUID?
    public var wishlistOnly = false

    private let deps: AppDependencies

    public init(deps: AppDependencies) {
        self.deps = deps
    }

    public var visibleItems: [WardrobeItem] {
        items.filter { item in
            (selectedCollectionID == nil || item.collectionID == selectedCollectionID)
                && (!wishlistOnly || item.isWishlist)
        }
    }

    public func load() async {
        do {
            collections = try await deps.store.collections()
            items = try await deps.store.allItems()
        } catch {
            print("Wardrobe load failed: \(error)")
        }
    }

    public func save(_ item: WardrobeItem) async {
        do {
            try await deps.store.save(item)
            // Fit-status changes can unlock milestones.
            await deps.coordinator.recalculate()
            await load()
        } catch {
            print("Wardrobe save failed: \(error)")
        }
    }

    public func delete(_ item: WardrobeItem) async {
        do {
            try await deps.store.deleteItem(id: item.id)
            await load()
        } catch {
            print("Wardrobe delete failed: \(error)")
        }
    }

    public func addCollection(named name: String) async {
        do {
            try await deps.store.save(WardrobeCollection(name: name, sortOrder: collections.count))
            await load()
        } catch {
            print("Collection save failed: \(error)")
        }
    }
}

/// Pinterest-style motivational wardrobe — the emotional anchor of the goal.
public struct WardrobeView: View {
    @State private var viewModel: WardrobeViewModel
    @State private var addingItem = false
    @State private var addingCollection = false
    @State private var newCollectionName = ""

    public init(deps: AppDependencies) {
        _viewModel = State(initialValue: WardrobeViewModel(deps: deps))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    collectionsBar
                    if viewModel.visibleItems.isEmpty {
                        EmptyStateView(
                            systemImage: "sparkles",
                            title: "Your dream wardrobe",
                            message: "Pin the outfits you're working toward. They'll cheer you on from your dashboard."
                        )
                    } else {
                        MasonryGrid(
                            items: viewModel.visibleItems,
                            estimatedHeight: { $0.imageData == nil ? 150 : 240 }
                        ) { item in
                            NavigationLink {
                                WardrobeItemDetailView(item: item, viewModel: viewModel)
                            } label: {
                                WardrobeItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.bottom, AuraSpacing.s6)
            }
            .background(AuraColor.background)
            .navigationTitle("Wardrobe")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addingItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $addingItem) {
                WardrobeItemFormSheet(viewModel: viewModel)
            }
            .alert("New collection", isPresented: $addingCollection) {
                TextField("Name", text: $newCollectionName)
                Button("Create") {
                    let name = newCollectionName
                    newCollectionName = ""
                    Task { await viewModel.addCollection(named: name) }
                }
                Button("Cancel", role: .cancel) { newCollectionName = "" }
            }
        }
    }

    private var collectionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AuraSpacing.s2) {
                chip("All", isOn: viewModel.selectedCollectionID == nil && !viewModel.wishlistOnly) {
                    viewModel.selectedCollectionID = nil
                    viewModel.wishlistOnly = false
                }
                ForEach(viewModel.collections) { collection in
                    chip(collection.name, isOn: viewModel.selectedCollectionID == collection.id) {
                        viewModel.selectedCollectionID = collection.id
                        viewModel.wishlistOnly = false
                    }
                }
                chip("✨ Wishlist", isOn: viewModel.wishlistOnly) {
                    viewModel.wishlistOnly.toggle()
                }
                Button {
                    addingCollection = true
                } label: {
                    Image(systemName: "plus")
                        .font(AuraFont.chip)
                        .padding(.horizontal, AuraSpacing.s3)
                        .padding(.vertical, 8)
                        .background(AuraColor.accentSoft, in: .capsule)
                        .foregroundStyle(AuraColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, AuraSpacing.s2)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AuraFont.chip)
                .padding(.horizontal, AuraSpacing.s3)
                .padding(.vertical, 8)
                .background(isOn ? AuraColor.accent : AuraColor.accentSoft, in: .capsule)
                .foregroundStyle(isOn ? .white : AuraColor.accent)
        }
        .buttonStyle(.plain)
    }
}

struct WardrobeItemCard: View {
    let item: WardrobeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let data = item.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipped()
            } else {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(AuraColor.celebrate)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .background(AuraColor.celebrate.opacity(0.1))
            }
            VStack(alignment: .leading, spacing: AuraSpacing.s1) {
                Text(item.title)
                    .font(AuraFont.body.weight(.medium))
                    .foregroundStyle(AuraColor.textPrimary)
                    .lineLimit(1)
                HStack {
                    Text("Size \(item.targetSize)")
                        .font(AuraFont.caption)
                        .foregroundStyle(AuraColor.textSecondary)
                    Spacer()
                    Text(item.fitStatus.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, AuraSpacing.s2)
                        .padding(.vertical, 3)
                        .background(
                            (item.fitStatus == .fits ? AuraColor.celebrate : AuraColor.accent).opacity(0.15),
                            in: .capsule
                        )
                        .foregroundStyle(item.fitStatus == .fits ? AuraColor.celebrate : AuraColor.accent)
                }
            }
            .padding(AuraSpacing.s3)
        }
        .background(AuraColor.surface)
        .clipShape(.rect(cornerRadius: AuraRadius.card - 8, style: .continuous))
    }

    private var icon: String {
        switch item.category {
        case .dress, .outfit, .top: return "tshirt.fill"
        case .jeans, .skirt:        return "figure.stand"
        case .jacket:               return "jacket"
        case .shoes:                return "shoe.2.fill"
        case .accessory, .other:    return "bag.fill"
        }
    }
}

struct WardrobeItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: WardrobeItem
    let viewModel: WardrobeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                if let data = item.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: AuraRadius.card, style: .continuous))
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                        Picker("Fit progress", selection: $item.fitStatus) {
                            ForEach(FitStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Pinned to dashboard", isOn: $item.pinnedToDashboard)
                        Toggle("Wishlist", isOn: $item.isWishlist)
                        TextField("Target size", text: $item.targetSize)
                        TextField("Notes", text: $item.notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                AuraButton("Save") {
                    Task {
                        await viewModel.save(item)
                        dismiss()
                    }
                }
                AuraButton("Remove item", style: .quiet) {
                    Task {
                        await viewModel.delete(item)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, AuraSpacing.screen)
        }
        .background(AuraColor.background)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Creation flow: photo → category → target size → notes.
struct WardrobeItemFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WardrobeViewModel

    @State private var title = ""
    @State private var category: WardrobeCategory = .dress
    @State private var targetSize = ""
    @State private var notes = ""
    @State private var isWishlist = false
    @State private var collectionID: UUID?
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(WardrobeCategory.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                    TextField("Target size", text: $targetSize)
                    Toggle("Wishlist", isOn: $isWishlist)
                    Picker("Collection", selection: $collectionID) {
                        Text("None").tag(UUID?.none)
                        ForEach(viewModel.collections) { c in
                            Text(c.name).tag(UUID?.some(c.id))
                        }
                    }
                }
                Section("Photo") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(imageData == nil ? "Choose photo" : "Change photo", systemImage: "photo")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                    }
                }
                Section("Notes") {
                    TextField("Why this piece?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(title.isEmpty || targetSize.isEmpty)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    imageData = try? await newItem?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private func save() {
        let item = WardrobeItem(
            collectionID: collectionID, title: title, category: category,
            imageData: imageData, targetSize: targetSize, notes: notes,
            isWishlist: isWishlist
        )
        Task {
            await viewModel.save(item)
            dismiss()
        }
    }
}
