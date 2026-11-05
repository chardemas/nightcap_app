import NightcapCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            HomeView()
        }
        .preferredColorScheme(.dark)
        .tint(Theme.amber)
        .fontDesign(.rounded)
        .sheet(item: $model.route) { route in
            switch route {
            case .challenge(let origin): ChallengeView(origin: origin)
            }
        }
    }
}

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showingStart = false
    @State private var showingChecklist = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.authorizationStatus != .approved {
                    ScreenTimeCard()
                }
                if let session = model.session {
                    ActiveSessionCard(session: session)
                } else {
                    startCard
                }
                ProtectionScoreCard(report: model.checklist) { showingChecklist = true }
                RideHomeButton()
            }
            .padding()
        }
        .nightBackground()
        .navigationTitle("Nightcap")
        .toolbar {
            NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
        }
        .navigationDestination(isPresented: $showingChecklist) { ChecklistView() }
        .sheet(isPresented: $showingStart) { StartSessionSheet() }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Off", systemImage: "moon.zzz")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.dusk)
            Text("Heading out tonight?")
                .font(.title2.bold())
                .foregroundStyle(Theme.moonlight)
            Text("Lock the risky stuff before the second round, not after the fifth.")
                .foregroundStyle(Theme.dusk)
            Button {
                if model.checklist.canStartAfterReconfirm { showingStart = true } else { showingChecklist = true }
            } label: {
                Label("Start Nightcap", systemImage: "moon.stars.fill")
            }
            .buttonStyle(GlowButtonStyle())
            if !model.checklist.canStartAfterReconfirm {
                Text("Finish the Pre-Game Checklist first. \(model.checklist.blockers.count) to go.")
                    .font(.footnote)
                    .foregroundStyle(Theme.amber)
            }
        }
        .card()
    }
}

private struct ScreenTimeCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("First things first")
                .font(.headline)
                .foregroundStyle(Theme.moonlight)
            Text("Nightcap uses Screen Time to put shields on apps. Nothing you do in them is ever seen or stored.")
                .font(.subheadline)
                .foregroundStyle(Theme.dusk)
            Button("Allow Screen Time access") {
                Task { await model.requestAuthorization() }
            }
            .buttonStyle(GlowButtonStyle(filled: false))
        }
        .card()
    }
}

struct ActiveSessionCard: View {
    @Environment(AppModel.self) private var model
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Nightcap is on", systemImage: "moon.stars.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.amber)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(remaining(at: context.date))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.moonlight)
            }
            Text("Ends at \(time(session.plannedEnd)). You're covered till then.")
                .foregroundStyle(Theme.dusk)
            if let unlock = session.temporaryUnlock, unlock.until > .now {
                Label("One app unlocked till \(time(unlock.until))", systemImage: "lock.open")
                    .font(.footnote)
                    .foregroundStyle(Theme.amber)
            }
            Button(endEarlyTitle) { model.route = .challenge(.endEarly) }
                .font(.footnote)
                .foregroundStyle(Theme.dusk)
        }
        .card()
    }

    private var endEarlyTitle: String {
        switch model.challengeGate {
        case .coolingDown(let until): "Next challenge at \(time(until))"
        case .lockedForNight: "Locked for the night"
        default: "Sober? End early"
        }
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    private func remaining(at date: Date) -> String {
        let minutes = max(0, Int(session.plannedEnd.timeIntervalSince(date) / 60))
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m left"
    }
}

struct ProtectionScoreCard: View {
    let report: ChecklistReport
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Theme.amber.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: report.total == 0 ? 0 : CGFloat(report.covered) / CGFloat(report.total))
                        .stroke(Theme.amber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(report.covered)/\(report.total)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.moonlight)
                }
                .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protection Score")
                        .font(.headline)
                        .foregroundStyle(Theme.moonlight)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dusk)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.dusk)
            }
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Protection Score, \(report.covered) of \(report.total) covered. \(summary)")
    }

    private var summary: String {
        if !report.blockers.isEmpty { return "\(report.blockers.count) required before you can start." }
        let missing = report.total - report.covered
        return missing == 0 ? "Fully covered. Go have fun." : "\(missing) recommended left."
    }
}

struct RideHomeButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.rideHome() } label: {
            Label("Ride home with \(model.settings.rideApp.title)", systemImage: "car.fill")
        }
        .buttonStyle(GlowButtonStyle(filled: model.session != nil))
    }
}
