import SwiftUI

struct InstallRequiredView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shippingbox.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Apple Container CLI Required")
                    .font(.title2.weight(.semibold))

                Text("Apple Container Desktop needs the official Apple Container CLI installed on your Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Download the signed PKG installer (v1.0.0)", systemImage: "arrow.down.circle")
                Label("Run the installer and restart this app", systemImage: "gearshape")
            }
            .font(.callout)
            .padding()
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Download PKG") {
                    NSWorkspace.shared.open(ContainerCLI.installPKGURL)
                }
                .buttonStyle(.borderedProminent)

                Button("View Releases") {
                    NSWorkspace.shared.open(ContainerCLI.releasesURL)
                }
                .buttonStyle(.bordered)

                Button("Check Again") {
                    Task { await model.recheckInstallation() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(minWidth: 520, minHeight: 380)
    }
}
