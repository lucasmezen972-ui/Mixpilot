#if os(macOS)
import MixPilotHelp
import SwiftUI

struct MixPilotHelpCenterView: View {
    @State private var language = MixPilotHelpLanguage.preferred()
    @State private var searchText = ""
    @State private var category: MixPilotHelpCategory?
    @State private var selectedArticleID: String? = MixPilotHelpCatalog.definitions.first?.id

    private let catalog = MixPilotHelpCatalog.shared

    private var articles: [MixPilotHelpArticle] {
        catalog.search(searchText, language: language, category: category)
    }

    private var selectedArticle: MixPilotHelpArticle? {
        let available = catalog.articles(language: language)
        return available.first { $0.id == selectedArticleID } ?? articles.first
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                controls
                Divider()
                articleList
            }
            .navigationTitle(text("help.center.title"))
            .frame(minWidth: 330)
        } detail: {
            if let article = selectedArticle {
                articleDetail(article)
            } else {
                ContentUnavailableView(
                    text("help.center.no_result"),
                    systemImage: "magnifyingglass"
                )
            }
        }
        .frame(minWidth: 980, minHeight: 680)
        .onChange(of: language) { _, _ in
            if !articles.contains(where: { $0.id == selectedArticleID }) {
                selectedArticleID = articles.first?.id
            }
        }
        .onChange(of: category) { _, _ in
            selectedArticleID = articles.first?.id
        }
        .onChange(of: searchText) { _, _ in
            if !articles.contains(where: { $0.id == selectedArticleID }) {
                selectedArticleID = articles.first?.id
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(text("help.center.search"), text: $searchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Picker("", selection: $language) {
                    ForEach(MixPilotHelpLanguage.allCases, id: \.self) { item in
                        Text(text(MixPilotHelpCatalog.languageNameKey(item))).tag(item)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 130)

                Picker("", selection: $category) {
                    Text(text("help.center.all_categories"))
                        .tag(Optional<MixPilotHelpCategory>.none)
                    ForEach(MixPilotHelpCategory.allCases, id: \.self) { item in
                        Text(text(MixPilotHelpCatalog.categoryTitleKey(item)))
                            .tag(Optional(item))
                    }
                }
                .labelsHidden()
            }

            Label(text("help.center.offline_note"), systemImage: "wifi.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var articleList: some View {
        List(articles, selection: $selectedArticleID) { article in
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: article.symbol)
                    .frame(width: 24)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title).font(.headline)
                    Text(article.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 5)
            .tag(article.id)
        }
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView(
                    text("help.center.no_result"),
                    systemImage: "magnifyingglass"
                )
            }
        }
    }

    private func articleDetail(_ article: MixPilotHelpArticle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: article.symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.indigo)
                        .frame(width: 52, height: 52)
                        .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(article.title)
                            .font(.largeTitle.bold())
                        Text(article.summary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text(article.body)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: 760, alignment: .leading)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(article.title)
    }

    private func text(_ key: String) -> String {
        catalog.localized(key, language: language)
    }
}
#endif
