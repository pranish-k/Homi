import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    let houseMembers: [HouseMember]

    @State private var showingMemberSelection = false

    var body: some View {
        NavigationStack {
            Form {
                // Amount section
                Section("Amount") {
                    HStack {
                        Text("$")
                            .foregroundColor(Constants.Colors.textSecondary)
                        TextField("0.00", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }

                // Description section
                Section("Description") {
                    TextField("What was this expense for?", text: $viewModel.description)
                }

                // Category section
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }

                // Date section
                Section("Date") {
                    DatePicker("Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                }

                // Who paid section
                Section("Who Paid?") {
                    Picker("Payer", selection: $viewModel.selectedPayer) {
                        Text("Select person").tag("")
                        ForEach(houseMembers, id: \.userId) { member in
                            Text(member.displayName).tag(member.userId)
                        }
                    }
                }

                // Split type section
                Section("How to Split") {
                    Picker("Split Type", selection: $viewModel.splitType) {
                        ForEach(SplitType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Participants section
                Section("Split Between") {
                    ForEach(houseMembers, id: \.userId) { member in
                        Toggle(member.displayName, isOn: Binding(
                            get: { viewModel.selectedParticipants.contains(member.userId) },
                            set: { isSelected in
                                if isSelected {
                                    viewModel.selectedParticipants.insert(member.userId)
                                } else {
                                    viewModel.selectedParticipants.remove(member.userId)
                                }
                            }
                        ))
                    }

                    if viewModel.splitType == .equal && !viewModel.selectedParticipants.isEmpty,
                       let amount = Double(viewModel.amount), amount > 0 {
                        let perPerson = amount / Double(viewModel.selectedParticipants.count)
                        Text("Each person: \(String(format: "$%.2f", perPerson))")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }

                // Custom amounts (if custom split selected)
                if viewModel.splitType == .custom && !viewModel.selectedParticipants.isEmpty {
                    Section("Custom Amounts") {
                        ForEach(Array(viewModel.selectedParticipants), id: \.self) { userId in
                            if let member = houseMembers.first(where: { $0.userId == userId }) {
                                HStack {
                                    Text(member.displayName)
                                    Spacer()
                                    Text("$")
                                        .foregroundColor(Constants.Colors.textSecondary)
                                    TextField("0.00", text: Binding(
                                        get: { viewModel.customSplits[userId] ?? "" },
                                        set: { viewModel.customSplits[userId] = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                }
                            }
                        }

                        if let totalAmount = Double(viewModel.amount), totalAmount > 0 {
                            let customTotal = viewModel.customSplits.values.compactMap { Double($0) }.reduce(0, +)
                            let remaining = totalAmount - customTotal

                            HStack {
                                Text("Remaining")
                                    .foregroundColor(remaining == 0 ? Constants.Colors.success : Constants.Colors.danger)
                                Spacer()
                                Text(String(format: "$%.2f", remaining))
                                    .fontWeight(.bold)
                                    .foregroundColor(remaining == 0 ? Constants.Colors.success : Constants.Colors.danger)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.createExpense()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Preview

struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView(
            viewModel: ExpenseViewModel(),
            houseMembers: [
                HouseMember(userId: "1", displayName: "John Doe", profilePhotoUrl: nil, role: .member, joinedAt: Date(), locationSharing: false, lastLocation: nil),
                HouseMember(userId: "2", displayName: "Jane Smith", profilePhotoUrl: nil, role: .member, joinedAt: Date(), locationSharing: false, lastLocation: nil)
            ]
        )
    }
}
