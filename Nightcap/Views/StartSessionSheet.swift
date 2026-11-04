import NightcapCore
import SwiftUI

/// The pre-session "Still set up?" screen: pick an end time, then one
/// hold-to-confirm re-confirms every self-confirmed item and starts the session.
struct StartSessionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var end = Session.defaultEnd(after: .now)
    @State private var error: String?

    var body: some View {
        let now = Date.now
        let items = model.checklist.reconfirmable

        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Lock until",
                        selection: $end,
                        in: now.addingTimeInterval(Session.minimumDuration)...now.addingTimeInterval(Session.maximumDuration)
                    )
                } footer: {
                    Text("Ride apps, Maps, and Phone stay open the whole time.")
                }

                if !items.isEmpty {
                    Section("Still set up?") {
                        ForEach(items) { item in
                            Label(item.title, systemImage: "checkmark")
                                .foregroundStyle(Theme.moonlight)
                        }
                    }
                }

                Section {
                    HoldToConfirmButton(title: items.isEmpty ? "Hold to start" : "All still set — hold to start") {
                        start(reconfirming: items)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .nightBackground()
            .navigationTitle("Start Nightcap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func start(reconfirming items: [ChecklistItem]) {
        model.confirm(items)
        Task {
            do {
                try await model.startSession(until: end)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
