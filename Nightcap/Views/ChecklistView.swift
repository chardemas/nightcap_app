import NightcapCore
import SwiftUI

struct ChecklistView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let report = model.checklist
        List {
            Section {
                Text("Nightcap can block apps for you, but a few iOS settings only you can change. Here's exactly how.")
                    .foregroundStyle(Theme.dusk)
                    .listRowBackground(Color.clear)
            }
            section("Required", report.entries.filter { $0.level == .required })
            section("Recommended", report.entries.filter { $0.level == .recommended })
        }
        .nightBackground()
        .navigationTitle("Pre-Game Checklist")
    }

    private func section(_ title: String, _ entries: [ChecklistEntry]) -> some View {
        Section(title) {
            ForEach(entries) { entry in
                NavigationLink { destination(for: entry.item) } label: { ChecklistRow(entry: entry) }
            }
        }
    }

    @ViewBuilder
    private func destination(for item: ChecklistItem) -> some View {
        if item.walkthrough != nil {
            WalkthroughView(item: item)
        } else {
            // Every auto-verified Phase 1 item is fixed from Settings.
            SettingsView()
        }
    }
}

private struct ChecklistRow: View {
    let entry: ChecklistEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.item.title).foregroundStyle(Theme.moonlight)
                Text(detail).font(.footnote).foregroundStyle(Theme.dusk)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch entry.status {
        case .done: entry.item.kind == .auto ? "checkmark.seal.fill" : "checkmark.circle.fill"
        case .expired: "clock.arrow.circlepath"
        case .missing: "circle"
        }
    }

    private var color: Color {
        switch entry.status {
        case .done: Theme.good
        case .expired: Theme.amber
        case .missing: Theme.dusk
        }
    }

    private var detail: String {
        switch entry.status {
        case .done where entry.item.kind == .auto: "Verified by Nightcap"
        case .done: "Confirmed by you"
        case .expired(let date): "Last confirmed \(date.formatted(.relative(presentation: .named))). Worth a re-check."
        case .missing: entry.item.blurb
        }
    }
}

struct WalkthroughView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: ChecklistItem

    var body: some View {
        if let walkthrough = item.walkthrough {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(walkthrough.why)
                        .foregroundStyle(Theme.dusk)

                    if let name = walkthrough.screenshot, let image = UIImage(named: name) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(walkthrough.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.midnight)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.amber, in: Circle())
                                Text(step).foregroundStyle(Theme.moonlight)
                            }
                        }
                    }
                    .card()

                    if let caveat = walkthrough.caveat {
                        Label(caveat, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Theme.dusk)
                    }

                    HoldToConfirmButton(title: "I did this — hold to confirm") {
                        model.confirm([item])
                        dismiss()
                    }
                }
                .padding()
            }
            .nightBackground()
            .navigationTitle(item.title)
        }
    }
}
