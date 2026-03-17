import SwiftUI

struct CategoryRulesView: View {
    @State private var searchText = ""
    @State private var rules: [CategoryRule] = []
    @State private var showingAddRule = false
    @State private var editingRule: CategoryRule?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            rulesList
        }
        .frame(width: 500, height: 450)
        .onAppear { loadRules() }
        .sheet(isPresented: $showingAddRule) {
            RuleEditorView(rule: nil) { newRule in
                CategoryEngine.shared.addUserRule(newRule)
                loadRules()
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(rule: rule) { updated in
                CategoryEngine.shared.updateUserRule(updated)
                loadRules()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Category Rules")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(CategoryEngine.shared.defaultRuleCount) defaults, \(CategoryEngine.shared.userRuleCount) custom")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Button(action: { showingAddRule = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var filteredRules: [CategoryRule] {
        if searchText.isEmpty { return rules }
        let query = searchText.lowercased()
        return rules.filter {
            $0.pattern.lowercased().contains(query) ||
            $0.category.lowercased().contains(query)
        }
    }

    private var rulesList: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("Search rules...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.05))

            List(filteredRules) { rule in
                ruleRow(rule)
                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
            }
            .listStyle(.plain)
        }
    }

    private func ruleRow(_ rule: CategoryRule) -> some View {
        HStack(spacing: 8) {
            productivityDot(rule.productivityLevel)

            VStack(alignment: .leading, spacing: 1) {
                Text(rule.pattern)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(rule.category)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(rule.matchField.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if rule.isRegex {
                        Text("regex")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            Text(rule.productivityLevel.shortLabel)
                .font(.system(size: 9))
                .foregroundStyle(colorForLevel(rule.productivityLevel))

            if !rule.isDefault {
                HStack(spacing: 4) {
                    Button(action: { editingRule = rule }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        CategoryEngine.shared.removeUserRule(id: rule.id)
                        loadRules()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func productivityDot(_ level: ProductivityLevel) -> some View {
        Circle()
            .fill(colorForLevel(level))
            .frame(width: 8, height: 8)
    }

    private func loadRules() {
        rules = CategoryEngine.shared.allRules
    }
}

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existingRule: CategoryRule?
    let onSave: (CategoryRule) -> Void

    @State private var category: String
    @State private var pattern: String
    @State private var matchField: MatchField
    @State private var productivityLevel: ProductivityLevel
    @State private var isRegex: Bool

    init(rule: CategoryRule?, onSave: @escaping (CategoryRule) -> Void) {
        self.existingRule = rule
        self.onSave = onSave
        _category = State(initialValue: rule?.category ?? "")
        _pattern = State(initialValue: rule?.pattern ?? "")
        _matchField = State(initialValue: rule?.matchField ?? .bundleID)
        _productivityLevel = State(initialValue: rule?.productivityLevel ?? .neutral)
        _isRegex = State(initialValue: rule?.isRegex ?? false)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(existingRule == nil ? "Add Rule" : "Edit Rule")
                .font(.system(size: 13, weight: .semibold))

            Form {
                TextField("Pattern", text: $pattern)
                    .font(.system(size: 11))

                Picker("Match Field", selection: $matchField) {
                    ForEach(MatchField.allCases, id: \.self) { field in
                        Text(field.rawValue).tag(field)
                    }
                }
                .font(.system(size: 11))

                TextField("Category", text: $category)
                    .font(.system(size: 11))

                Picker("Productivity", selection: $productivityLevel) {
                    ForEach(ProductivityLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .font(.system(size: 11))

                Toggle("Regex pattern", isOn: $isRegex)
                    .font(.system(size: 11))
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    let rule = CategoryRule(
                        id: existingRule?.id ?? UUID(),
                        category: category,
                        productivityLevel: productivityLevel,
                        matchField: matchField,
                        pattern: pattern,
                        isRegex: isRegex,
                        isDefault: false,
                        priority: existingRule?.priority ?? 1000
                    )
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pattern.isEmpty || category.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 350, height: 320)
    }
}

func colorForLevel(_ level: ProductivityLevel) -> Color {
    switch level {
    case .veryDistracting: return .red
    case .distracting: return .orange
    case .neutral: return .gray
    case .productive: return .blue
    case .veryProductive: return .green
    }
}
