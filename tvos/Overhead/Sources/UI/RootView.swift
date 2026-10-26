import SwiftUI
import UIKit

/// Swipe left/right (Siri Remote) cycles Live → Hangar → Poster. Up/down moves within a view.
/// Play/Pause opens Settings. Keeps the screen awake and drifts slowly to avoid burn-in.
struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var emptySince: Date? = nil

    var body: some View {
        let th = model.night ? Theme.night : Theme.day
        TimelineView(.periodic(from: .now, by: 5)) { tl in
            let d = drift(tl.date)
            ZStack {
                th.paper.ignoresSafeArea()
                Group {
                    switch model.screen {
                    case .live: LiveView()
                    case .cards: CardsView()
                    case .poster: PosterView()
                    }
                }
                .padding(.horizontal, 60).padding(.vertical, 40)
                .offset(x: d.width, y: d.height)
                .opacity(dimmed(tl.date) ? 0.35 : 1)
                .animation(.easeInOut(duration: 4), value: d)
            }
        }
        .focusable()
        .onMoveCommand { dir in
            switch dir {
            case .left: model.cycle(-1)
            case .right: model.cycle(1)
            case .up: step(-1)
            case .down: step(1)
            @unknown default: break
            }
        }
        .onPlayPauseCommand { model.showSettings = true }
        .onOpenURL { _ in model.screen = .live }
        .sheet(isPresented: $model.showSettings) { SettingsView().environmentObject(model) }
        .onChange(of: phase) { _, p in UIApplication.shared.isIdleTimerDisabled = (p == .active) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: model.aircraft.count) { _, n in emptySince = n == 0 ? (emptySince ?? Date()) : nil }
        .preferredColorScheme(model.night ? .dark : .light)
    }

    private func step(_ d: Int) {
        switch model.screen {
        case .live: model.focusIndex = max(0, min(model.focusIndex + d, max(0, model.aircraft.count - 1)))
        case .cards: model.cardsPage = max(0, model.cardsPage + d)
        case .poster: model.posterIndex = max(0, min(model.posterIndex - d, max(0, model.posters.count - 1)))
            Task { await model.loadPoster() }
        }
    }

    /// Slow Lissajous drift, max ±14 × ±10 pt, one loop every ~17 minutes. Invisible at 10 feet.
    private func drift(_ t: Date) -> CGSize {
        let s = t.timeIntervalSince1970
        return CGSize(width: (14 * sin(s / 163)).rounded(), height: (10 * sin(s / 211 + 1)).rounded())
    }
    /// Dim after 2 minutes with nothing in range (live view only).
    private func dimmed(_ t: Date) -> Bool {
        guard model.screen == .live, let e = emptySince else { return false }
        return t.timeIntervalSince(e) > 120
    }
}
