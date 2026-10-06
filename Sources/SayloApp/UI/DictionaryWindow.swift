import SwiftUI
import DesignSystem

/// Dictionary management — matches Paper artboard 05.
/// Used both as a main-window tab (DictionaryContentView) and as a
/// standalone window (DictionaryWindow).
public struct DictionaryWindow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            SayloWindowChrome(title: "Saylo — Dictionary")
            DictionaryContentView()
                .environmentObject(dictionaryStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 640)
        .background(DesignSystem.Color.surface)
        // Paper design is light-mode only.
        .preferredColorScheme(.light)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Shared dictionary content (tab + window)

public struct DictionaryContentView: View {
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    @State private var searchText = ""
    @State private var tab: DictionaryTab = .all
    @State private var showingAddSheet = false
    @State private var editingEntry: DictionaryEntry?

    public init() {}

    private var filtered: [DictionaryEntry] {
        let searched = dictionaryStore.search(searchText)
        switch tab {
        case .all: return searched
        case .personal: return searched.filter { $0.type == .word }
        case .technical: return searched.filter { isTechnical($0) }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title row
            HStack {
                Text("Dictionary")
                    .font(.custom(DesignSystem.Typography.sans, size: 26))
                    .fontWeight(.bold)
                    .tracking(DesignSystem.Typography.trackingTight)
                    .foregroundStyle(DesignSystem.Color.ink)
                Spacer(minLength: 0)
                Button { showingAddSheet = true } label: {
                    Text("+ Add new word")
                        .font(.custom(DesignSystem.Typography.sans, size: 12))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DesignSystem.Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Tabs + tools
            HStack {
                HStack(spacing: 20) {
                    ForEach(DictionaryTab.allCases) { t in
                        Button { tab = t } label: {
                            VStack(spacing: 10) {
                                Text(t.title)
                                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                                    .fontWeight(tab == t ? .semibold : .regular)
                                    .foregroundStyle(tab == t ? DesignSystem.Color.ink : DesignSystem.Color.muted)
                                Rectangle()
                                    .fill(tab == t ? DesignSystem.Color.ink : .clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                    Button { searchText = "" } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                Divider().overlay(DesignSystem.Color.line)
            }

            // Hero with quick chips (Paper: accent CTA + dark chips inside black card)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Saylo spells the way")
                            .font(.custom(DesignSystem.Typography.sans, size: 24))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text("you")
                            .font(.custom(DesignSystem.Typography.serif, size: 26))
                            .italic()
                            .foregroundStyle(DesignSystem.Color.accent)
                        Text("do.")
                            .font(.custom(DesignSystem.Typography.sans, size: 24))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    Text("Correct a spelling once or add it here manually, so your personal terms, company jargon, or uncommon names are prioritized during Whistle search.")
                        .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.heroSub)
                }
                HStack(spacing: 8) {
                    Button { showingAddSheet = true } label: {
                        Text("+ Add new word")
                            .font(.custom(DesignSystem.Typography.sans, size: 12))
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DesignSystem.Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    ForEach(quickChips, id: \.self) { chip in
                        Text(chip)
                            .font(.custom(DesignSystem.Typography.sans, size: 12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DesignSystem.Color.chipDark)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Color.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Search (functional, Paper keeps it as icon-only; expose on filter)
            SearchField(text: $searchText, placeholder: "Search dictionary…")
                .frame(maxWidth: 320)

            // Rows
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No Entries Yet" : "No Matches", systemImage: "textformat.alt")
                } description: {
                    Text(searchText.isEmpty
                        ? "Add words, names, or corrections that Saylo should know"
                        : "No entries match '\(searchText)'")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { entry in
                            PaperDictionaryRow(
                                entry: entry,
                                isUserName: isUserName(entry),
                                onEdit: { editingEntry = entry },
                                onDelete: { dictionaryStore.deleteEntry(entry) }
                            )
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 36)
        .sheet(isPresented: $showingAddSheet) {
            AddEditEntrySheet(entry: nil, initialType: .word) { phrase, replacement, type in
                dictionaryStore.addEntry(phrase: phrase, replacement: replacement, type: type)
            }
            .environmentObject(dictionaryStore)
        }
        .sheet(item: $editingEntry) { entry in
            AddEditEntrySheet(entry: entry, initialType: entry.type) { phrase, replacement, type in
                dictionaryStore.updateEntry(entry, phrase: phrase, replacement: replacement)
                if entry.type != type {
                    dictionaryStore.deleteEntry(entry)
                    dictionaryStore.addEntry(phrase: phrase, replacement: replacement, type: type)
                }
            }
            .environmentObject(dictionaryStore)
        }
    }

    private var quickChips: [String] {
        let names = dictionaryStore.entries.prefix(5).map(\.phrase)
        if names.isEmpty { return ["Saylo", "Cactus Compute", "Mahesh", "Kubernetes", "PyTorch"] }
        return Array(names)
    }

    private func isTechnical(_ entry: DictionaryEntry) -> Bool {
        // Technical = Whistle-bias keywords: multi-word or camel/capitalized terms
        entry.phrase.contains(" ") || entry.phrase.contains(where: { $0.isUppercase })
    }

    private func isUserName(_ entry: DictionaryEntry) -> Bool {
        entry.phrase.lowercased() == "mahesh"
    }
}

private enum DictionaryTab: String, CaseIterable, Identifiable {
    case all, personal, technical
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .personal: return "Personal"
        case .technical: return "Technical (Whistle Bias)"
        }
    }
}

// MARK: - Paper dictionary row

/// Matches Paper rows: 14px phrase + accent sparkle left,
/// mono "biasing weight X.X" right (deterministic from phrase hash).
private struct PaperDictionaryRow: View {
    let entry: DictionaryEntry
    var isUserName = false
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text(entry.phrase)
                    .font(.custom(DesignSystem.Typography.sans, size: 14))
                    .fontWeight(isUserName ? .semibold : .regular)
                    .foregroundStyle(DesignSystem.Color.ink)
                if isUserName {
                    Text("User Name")
                        .font(.custom(DesignSystem.Typography.mono, size: 10))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Color.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("✦")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Color.accent.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
            if isUserName {
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                    }.buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                    }.buttonStyle(.plain)
                    Image(systemName: "star").font(.system(size: 13)).foregroundStyle(DesignSystem.Color.muted)
                }
            } else {
                Text("biasing weight \(biasWeight, specifier: "%.1f")")
                    .font(.custom(DesignSystem.Typography.mono, size: 11))
                    .foregroundStyle(DesignSystem.Color.muted)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            Divider().overlay(DesignSystem.Color.line)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") { onEdit() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    /// Deterministic 1.1–1.6 weight so rows match Paper's look.
    private var biasWeight: Double {
        let sum = entry.phrase.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return 1.1 + Double(sum % 6) / 10.0
    }
}

// MARK: - Add/Edit Entry Sheet

private struct AddEditEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dictionaryStore: DictionaryStore

    let entry: DictionaryEntry?
    let initialType: DictionaryEntryType
    let onSave: (String, String?, DictionaryEntryType) -> Void

    @State private var phrase = ""
    @State private var replacement = ""
    @State private var type: DictionaryEntryType
    @State private var warnings: [String] = []

    init(entry: DictionaryEntry?, initialType: DictionaryEntryType, onSave: @escaping (String, String?, DictionaryEntryType) -> Void) {
        self.entry = entry
        self.initialType = initialType
        self.onSave = onSave
        self._type = State(initialValue: initialType)
        if let entry {
            _phrase = State(initialValue: entry.phrase)
            _replacement = State(initialValue: entry.replacement ?? "")
            _type = State(initialValue: entry.type)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Entry Type", selection: $type) {
                        ForEach(DictionaryEntryType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Phrase") {
                        TextField("e.g., Anthropic, Kubernetes, Claude Code", text: $phrase)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 250)
                    }

                    if type == .correction {
                        LabeledContent("Replacement") {
                            TextField("e.g., Claude Code", text: $replacement)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 250)
                        }
                    }
                }

                if !warnings.isEmpty {
                    Section("Warnings") {
                        ForEach(warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.s2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(DesignSystem.Color.danger)
                                    .font(.system(size: 13))
                                Text(warning)
                                    .font(.custom(DesignSystem.Typography.sans, size: DesignSystem.Typography.sm))
                                    .foregroundStyle(DesignSystem.Color.danger)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 500)
            .navigationTitle(entry == nil ? "Add Dictionary Entry" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(phrase, type == .correction && !replacement.isEmpty ? replacement : nil, type)
                        dismiss()
                    }
                    .disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (type == .correction && replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .onChange(of: phrase) { _, _ in validate() }
            .onChange(of: replacement) { _, _ in validate() }
            .onChange(of: type) { _, _ in validate() }
            .onAppear { validate() }
        }
    }

    private func validate() {
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { warnings = []; return }
        let replacementForValidation = type == .correction && !trimmedReplacement.isEmpty ? trimmedReplacement : nil
        warnings = dictionaryStore.validateEntry(phrase: trimmedPhrase, replacement: replacementForValidation)
    }
}
