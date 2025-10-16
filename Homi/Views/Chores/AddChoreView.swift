import SwiftUI

struct AddChoreView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ChoreViewModel
    let houseMembers: [HouseMember]

    @State private var showingDatePicker = false

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Chore Details") {
                    TextField("Title", text: $viewModel.title)
                        .autocapitalization(.words)

                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Assignment
                Section("Assignment") {
                    Picker("Assigned to", selection: $viewModel.selectedAssignee) {
                        Text("Select a member").tag("")
                        ForEach(houseMembers) { member in
                            Text(member.displayName).tag(member.userId)
                        }
                    }
                }

                // Category
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(ChoreCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Schedule
                Section("Schedule") {
                    // Due Date
                    Button {
                        showingDatePicker.toggle()
                    } label: {
                        HStack {
                            Text("Due Date")
                                .foregroundColor(Constants.Colors.textPrimary)

                            Spacer()

                            Text(viewModel.selectedDate, style: .date)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }

                    if showingDatePicker {
                        DatePicker(
                            "Select Date",
                            selection: $viewModel.selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }

                    // Frequency
                    Picker("Frequency", selection: $viewModel.selectedFrequency) {
                        ForEach(ChoreFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                }

                // Rotation (only if recurring)
                if viewModel.selectedFrequency != .once {
                    Section {
                        Toggle("Enable Rotation", isOn: $viewModel.rotationEnabled)

                        if viewModel.rotationEnabled {
                            Text("Select members to rotate this chore")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)

                            ForEach(houseMembers) { member in
                                Toggle(member.displayName, isOn: Binding(
                                    get: { viewModel.selectedRotationMembers.contains(member.userId) },
                                    set: { isSelected in
                                        if isSelected {
                                            if !viewModel.selectedRotationMembers.contains(member.userId) {
                                                viewModel.selectedRotationMembers.append(member.userId)
                                            }
                                        } else {
                                            viewModel.selectedRotationMembers.removeAll { $0 == member.userId }
                                        }
                                    }
                                ))
                            }
                        }
                    } header: {
                        Text("Rotation")
                    } footer: {
                        if viewModel.rotationEnabled {
                            Text("When completed, the chore will be assigned to the next person in the rotation.")
                                .font(.caption)
                        }
                    }
                }

                // Points
                Section {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)

                        TextField("Points", text: $viewModel.points)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Points")
                } footer: {
                    Text("Reward points for completing this chore")
                        .font(.caption)
                }
            }
            .navigationTitle("Add Chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.createChore()
                            if !viewModel.showError {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.title.isEmpty || viewModel.selectedAssignee.isEmpty)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}

// MARK: - Preview

struct AddChoreView_Previews: PreviewProvider {
    static var previews: some View {
        AddChoreView(
            viewModel: ChoreViewModel(),
            houseMembers: []
        )
    }
}
