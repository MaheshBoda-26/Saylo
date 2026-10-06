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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s6) {
            // Title row
            HStack {
                Text("Dictionary")
                    .sayloHeadline()
                Spacer(minLength: 0)
                Button("+ Add new word") {
                    showingAddSheet = true
                }
                .sayloButtonStyle(.primary)
            }

            // Tabs + tools
            HStack {
                HStack(spacing: DesignSystem.Spacing.s6) {
                    ForEach(DictionaryTab.allCases) { t in
                        Button { tab = t } label: {
                            Text(t.title)
                                .font(DesignSystem.Typography.sans(
                                    DesignSystem.Typography.sm,
                                    weight: tab == t
                                        ? DesignSystem.Typography.weightSemibold
                                        : DesignSystem.Typography.weightRegular
                                ))
                                .foregroundStyle(tab == t ? DesignSystem.Color.ink : DesignSystem.Color.muted)
                                .padding(.bottom, DesignSystem.Spacing.s2 + 2)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(tab == t ? DesignSystem.Color.ink : .clear)
                                        .frame(height: 2)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: DesignSystem.Spacing.s3) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.muted)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.muted)
                    Button { searchText = "" } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: DesignSystem.Typography.sm))
                            .foregroundStyle(DesignSystem.Color.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset search")
                }
            }
            .overlay(alignment: .bottom) {
                Divider().overlay(DesignSystem.Color.line)
            }

            // Hero with quick chips
            SayloHeroCard(
                headline: "Saylo spells the way",
                accentWord: "you",
                headlineSuffix: "do.",
                copy: "Correct a spelling once or add it here manually, so your personal terms, company jargon, or uncommon names are prioritized during Whistle search.",
                ctaTitle: "+ Add new word",
                chips: quickChips
            ) {
                showingAddSheet = true
            }

            // Search (functional, Paper keeps it as icon-only; expose on filter)
            SearchField(text: $searchText, placeholder: "Search dictionary…")
                .frame(maxWidth: 320)

            // Rows
            if filtered.isEmpty {
                VStack(spacing: DesignSystem.Spacing.s4) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 40))
                        .foregroundStyle(DesignSystem.Color.line)
                    Text(searchText.isEmpty ? "No entries yet" : "No matches")
                        .font(DesignSystem.Typography.serif(DesignSystem.Typography.serifAccent))
                        .italic()
                        .foregroundStyle(DesignSystem.Color.ink)
                    Text(searchText.isEmpty
                        ? "Add words, names, or corrections that Saylo should know"
                        : "No entries match '\(searchText)'")
                        .font(DesignSystem.Typography.sans(DesignSystem.Typography.base))
                        .lineSpacing(DesignSystem.Typography.bodyLineSpacing)
                        .foregroundStyle(DesignSystem.Color.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
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
        .padding(.vertical, DesignSystem.Spacing.s6)
        .padding(.horizontal, DesignSystem.Spacing.s8)
        .tint(DesignSystem.Color.accent)
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

/// Dictionary row: 15pt phrase + accent sparkle left,
/// mono "biasing weight X.X" right (deterministic from phrase hash).
private struct PaperDictionaryRow: View {
    let entry: DictionaryEntry
    var isUserName = false
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: DesignSystem.Spacing.s2) {
                Text(entry.phrase)
                    .font(DesignSystem.Typography.sans(
                        DesignSystem.Typography.base,
                        weight: isUserName ? DesignSystem.Typography.weightSemibold : DesignSystem.Typography.weightRegular
                    ))
                    .foregroundStyle(DesignSystem.Color.ink)
                if isUserName {
                    Text("User Name")
                        .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Color.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.sm))
                } else {
                    Text("✦")
                        .font(.system(size: DesignSystem.Typography.xs))
                        .foregroundStyle(DesignSystem.Color.accent.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
            if isUserName {
                HStack(spacing: DesignSystem.Spacing.s3) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: DesignSystem.Typography.sm))
                            .foregroundStyle(DesignSystem.Color.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(entry.phrase)")
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: DesignSystem.Typography.sm))
                            .foregroundStyle(DesignSystem.Color.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(entry.phrase)")
                    Image(systemName: "star")
                        .font(.system(size: DesignSystem.Typography.sm))
                        .foregroundStyle(DesignSystem.Color.muted)
                }
            } else {
                Text("biasing weight \(biasWeight, specifier: "%.1f")")
                    .font(DesignSystem.Typography.mono(DesignSystem.Typography.micro))
                    .foregroundStyle(DesignSystem.Color.muted)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.s3)
        .padding(.horizontal, DesignSystem.Spacing.s1)
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
                            .textFieldStyle(SayloTextFieldStyle())
                            .frame(minWidth: 250)
                    }

                    if type == .correction {
                        LabeledContent("Replacement") {
                            TextField("e.g., Claude Code", text: $replacement)
                                .textFieldStyle(SayloTextFieldStyle())
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
                                    .font(.system(size: DesignSystem.Typography.sm))
                                Text(warning)
                                    .font(DesignSystem.Typography.sans(DesignSystem.Typography.sm))
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
