#if os(macOS)
import MixPilotSystem
import SwiftUI

struct MixPilotCloudAccountView: View {
    @ObservedObject var cloud: MixPilotCloudCoordinator
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Compte MixPilot", systemImage: "person.crop.circle.badge.checkmark")
                .font(.title2.bold())

            Text("Le compte sert uniquement aux mises à jour, correctifs de compatibilité et diagnostics facultatifs. Le Live reste entièrement local.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            switch cloud.identityState {
            case .checking:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Vérification de la session…")
                }

            case .signedOut:
                signInForm

            case .linkSent(let address):
                Label("Lien envoyé à \(address)", systemImage: "envelope.badge")
                    .font(.headline)
                Text("Ouvre le message sur ce Mac puis clique sur le lien. MixPilot terminera la connexion automatiquement.")
                    .foregroundStyle(.secondary)
                Button("Envoyer un nouveau lien") {
                    email = address
                    cloud.requestMagicLink(email: email)
                }

            case .signedIn(let account):
                Label("Compte connecté", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(account.email ?? account.userID.uuidString)
                    .textSelection(.enabled)
                Button("Se déconnecter", role: .destructive) {
                    cloud.signOut()
                }

            case .failed(let message):
                Label("Connexion non terminée", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(message)
                    .foregroundStyle(.secondary)
                signInForm
            }

            Spacer()

            Text("Le lien de connexion utilise PKCE et la session est conservée dans le Trousseau macOS par le SDK Supabase.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { cloud.refreshIdentity() }
    }

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connexion par e-mail")
                .font(.headline)
            TextField("lucas@exemple.com", text: $email)
                .textContentType(.emailAddress)
                .disableAutocorrection(true)
                .onSubmit { cloud.requestMagicLink(email: email) }
            Button("M’envoyer un lien de connexion") {
                cloud.requestMagicLink(email: email)
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
#endif
