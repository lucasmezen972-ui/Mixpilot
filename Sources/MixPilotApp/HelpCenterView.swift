#if os(macOS)
import MixPilotCore
import SwiftUI

struct HelpCenterView: View {
    @AppStorage("help.locale") private var localeCode = HelpLocale.french.rawValue
    @State private var query = ""
    @State private var selection: HelpTopicID? = .gettingStarted

    private var locale: HelpLocale {
        HelpLocale(rawValue: localeCode) ?? .french
    }

    private var catalog: HelpCenterCatalog {
        HelpCenterCatalog(locale: locale)
    }

    private var results: [HelpTopic] {
        catalog.search(query)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                Picker("Language", selection: $localeCode) {
                    Text("Français").tag(HelpLocale.french.rawValue)
                    Text("English").tag(HelpLocale.english.rawValue)
                    Text("Español").tag(HelpLocale.spanish.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                List(results, selection: $selection) { topic in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(topic.title).font(.headline)
                        Text(topic.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 3)
                    .tag(topic.id)
                }
                .searchable(text: $query, placement: .sidebar, prompt: searchPrompt)
            }
            .padding(.top, 12)
            .navigationTitle(helpTitle)
        } detail: {
            if let selection, let topic = catalog.topic(for: selection) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(topic.title)
                            .font(.largeTitle.bold())
                        Text(topic.summary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Divider()
                        Text(topic.body)
                            .font(.body)
                            .textSelection(.enabled)
                            .lineSpacing(4)
                        if !topic.keywords.isEmpty {
                            Text(topic.keywords.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(32)
                }
            } else {
                ContentUnavailableView(noResultTitle, systemImage: "questionmark.circle", description: Text(noResultDescription))
            }
        }
        .onChange(of: localeCode) { _, _ in
            if let selection, catalog.topic(for: selection) == nil {
                self.selection = catalog.topics.first?.id
            }
        }
    }

    private var helpTitle: String {
        switch locale {
        case .french: "Centre d’aide"
        case .english: "Help Center"
        case .spanish: "Centro de ayuda"
        }
    }

    private var searchPrompt: String {
        switch locale {
        case .french: "Rechercher dans l’aide"
        case .english: "Search help"
        case .spanish: "Buscar en la ayuda"
        }
    }

    private var noResultTitle: String {
        switch locale {
        case .french: "Aucun résultat"
        case .english: "No results"
        case .spanish: "Sin resultados"
        }
    }

    private var noResultDescription: String {
        switch locale {
        case .french: "Essayez un logiciel, une erreur ou une étape du Live."
        case .english: "Try a software name, an error or a Live step."
        case .spanish: "Prueba un software, un error o una etapa de Live."
        }
    }
}
#endif
