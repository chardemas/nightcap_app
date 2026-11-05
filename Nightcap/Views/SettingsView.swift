import FamilyControls
import NightcapCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var address = ""
    @State private var savingHome = false
    @State private var homeError: String?

    var body: some View {
        @Bindable var model = model

        Form {
            if model.isLocked {
                Section {
                    Label("Locked until Nightcap ends. Nice try though.", systemImage: "lock.fill")
                        .foregroundStyle(Theme.amber)
                }
            }

            Section {
                LabeledContent("Status", value: screenTimeStatus)
                if model.authorizationStatus != .approved {
                    Button("Allow Screen Time access") { Task { await model.requestAuthorization() } }
                }
            } header: {
                Text("Screen Time")
            }

            Section {
                PickerRow(title: "Block these", selection: $model.selections.blocked)
            } header: {
                Text("Block list")
            } footer: {
                Text("Suggested: Social, Shopping, and your dating apps. To block Messages, pick it as an app on its own — category shields skip it while it's in Screen Time's Always Allowed list.")
            }

            Section {
                PickerRow(title: "Always allow", selection: $model.selections.allowed)
            } header: {
                Text("Allowlist")
            } footer: {
                Text("Add Uber, Lyft, Maps, and your transit app. These stay open even inside a blocked category. Phone can't be blocked, and Nightcap never blocks itself.")
            }

            Section {
                Picker("Food delivery", selection: $model.settings.foodDelivery) {
                    ForEach(FoodDeliveryPolicy.allCases, id: \.self) { Text($0.title) }
                }
                .pickerStyle(.segmented)
                if model.settings.foodDelivery != .allow {
                    PickerRow(title: "Food delivery apps", selection: $model.selections.foodDelivery)
                }
            } header: {
                Text("Food delivery")
            } footer: {
                Text("\"Ask first\" shows a \"you sure?\" screen. Say yes and food apps open for the rest of the night.")
            }

            Section {
                ForEach(WebDomainPack.allCases.filter { $0 != .foodDelivery }) { pack in
                    Toggle(pack.title, isOn: packBinding(pack))
                }
                Toggle("Strict mode", isOn: $model.settings.strictMode)
            } header: {
                Text("Web loophole closer")
            } footer: {
                Text("Blocks the websites of common apps so Safari isn't a back door. Strict mode blocks every website except ride and map sites.")
            }

            Section {
                Toggle("Block in-app purchases", isOn: $model.settings.denyInAppPurchases)
                Toggle("Block deleting apps", isOn: $model.settings.denyAppRemoval)
            } header: {
                Text("Purchases & loopholes")
            } footer: {
                Text("Apple Pay and cards saved in Safari can't be blocked by any app. The Pre-Game Checklist shows how to slow those down.")
            }

            Section {
                Picker("Difficulty", selection: $model.settings.challengeDifficulty) {
                    ForEach(ChallengeDifficulty.allCases) { Text($0.title).tag($0) }
                }
                Picker("Passing unlocks", selection: $model.settings.unlockScope) {
                    ForEach(UnlockScope.allCases) { Text($0.title).tag($0) }
                }
                if let baseline = model.settings.baseline {
                    LabeledContent("Sober baseline", value: "\(Int(baseline.reactionMedian * 1000)) ms · \(String(format: "%.1f", baseline.typingCharsPerSecond)) chars/s")
                }
                Button(model.settings.baseline == nil ? "Take sober baseline" : "Retake sober baseline") {
                    model.route = .challenge(.baseline)
                }
            } header: {
                Text("Sobriety Challenge")
            } footer: {
                Text("Standard means reaction time can be up to 25% slower than your sober baseline. \"Just that app\" applies when you start the challenge from a blocked app.")
            }

            Section {
                if let home = model.settings.home {
                    LabeledContent("Saved", value: home.label)
                }
                TextField("Home address", text: $address, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                Button(savingHome ? "Finding it…" : "Save home") { saveHome() }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || savingHome)
                if let homeError {
                    Text(homeError).font(.footnote).foregroundStyle(.red)
                }
                Picker("Ride app", selection: Binding(get: { model.settings.rideApp }, set: { model.setRideApp($0) })) {
                    ForEach(RideApp.allCases) { Text($0.title).tag($0) }
                }
                if !model.rideAppInstalled {
                    Text("\(model.settings.rideApp.title) isn't installed. Install it before tonight.")
                        .font(.footnote)
                        .foregroundStyle(Theme.amber)
                }
            } header: {
                Text("Ride home")
            }
        }
        .disabled(model.isLocked)
        .nightBackground()
        .navigationTitle("Settings")
    }

    private var screenTimeStatus: String {
        switch model.authorizationStatus {
        case .approved: "Allowed"
        case .denied: "Denied"
        default: "Not set up"
        }
    }

    private func packBinding(_ pack: WebDomainPack) -> Binding<Bool> {
        Binding(
            get: { model.settings.webPacks.contains(pack) },
            set: { on in
                if on { model.settings.webPacks.insert(pack) } else { model.settings.webPacks.remove(pack) }
            }
        )
    }

    private func saveHome() {
        savingHome = true
        homeError = nil
        Task {
            do {
                try await model.saveHome(address: address)
                address = ""
            } catch {
                homeError = "Couldn't find that address. Try adding the city."
            }
            savingHome = false
        }
    }
}

/// One row per picker: several `.familyActivityPicker`s on the same view fight
/// over presentation, so each row owns its own.
private struct PickerRow: View {
    @Environment(AppModel.self) private var model
    let title: String
    @Binding var selection: FamilyActivitySelection
    @State private var presented = false

    var body: some View {
        let count = selection.itemCount
        Button { presented = true } label: {
            LabeledContent(title, value: count == 0 ? "None" : "\(count) selected")
        }
        .disabled(model.authorizationStatus != .approved)
        .familyActivityPicker(isPresented: $presented, selection: $selection)
    }
}
