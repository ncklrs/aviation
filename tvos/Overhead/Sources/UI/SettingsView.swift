import SwiftUI

/// Opened with Play/Pause. Host is the only thing most people change.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var s = OverheadSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Receiver"), footer: Text("Host name of the Pi running readsb + tar1090, e.g. adsb.local. The app reads /tar1090/data/aircraft.json and receiver.json, and the logger's /ot/ folder.")) {
                    TextField("Host", text: $s.host).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Demo mode (fake aircraft)", isOn: $s.demo)
                }
                Section("Display") {
                    Picker("Night mode", selection: $s.night) { Text("Auto (sunset)").tag("auto"); Text("On").tag("on"); Text("Off").tag("off") }
                    Picker("Units", selection: $s.units) { Text("Aviation (kt, ft, nm)").tag("aero"); Text("Imperial").tag("imperial"); Text("Metric").tag("metric") }
                    Picker("Map radius", selection: $s.mapNm) { ForEach([10.0, 25, 50, 100], id: \.self) { Text("\(Int($0)) nm").tag($0) } }
                    Toggle("Look up routes (adsbdb.com)", isOn: $s.routes)
                    Toggle("New-card reveal animation", isOn: $s.reveal)
                    Button("Preview new-card reveal") { dismiss(); model.checkReveal(force: true) }
                }
                Section {
                    Button("Save") { model.settings = s; model.restart(); dismiss() }
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .navigationTitle("Overhead settings")
        }
        .onAppear { s = model.settings }
    }
}
