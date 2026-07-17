import MixPilotHelp
import SwiftUI

struct RemoteHelpCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var language = MixPilotHelpLanguage.preferred()
    @State private var searchText = ""
    @State private var category: MixPilotHelpCategory?

    private let catalog = MixPilotHelpCatalog.shared

    private var articles: [MixPilotHelpArticle] {
        catalog.search(searchText, language: language, category: category)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $language) {
                        ForEach(MixPilotHelpLanguage.allCases, id: \.self) { item in
                            Text(text(MixPilotHelpCatalog.languageNameKey(item))).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryButton(nil, title: text("help.center.all_categories"))
                            ForEach(MixPilotHelpCategory.allCases, id: \.self) { item in
                                categoryButton(item, title: text(MixPilotHelpCatalog.categoryTitleKey(item)))
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Label(text("help.center.offline_note"), systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if articles.isEmpty {
                        ContentUnavailableView(
                            text("help.center.no_result"),
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        ForEach(articles) { article in
                            NavigationLink {
                                RemoteHelpArticleView(article: article)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: article.symbol)
                                        .frame(width: 28)
                                        .foregroundStyle(.indigo)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(article.title).font(.headline)
                                        Text(article.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: text("help.center.search"))
            .navigationTitle(text("help.center.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(text("help.center.close")) { dismiss() }
                }
            }
        }
    }

    private func categoryButton(
        _ value: MixPilotHelpCategory?,
        title: String
    ) -> some View {
        Button(title) { category = value }
            .buttonStyle(.bordered)
            .tint(category == value ? .indigo : .secondary)
            .controlSize(.small)
    }

    private func text(_ key: String) -> String {
        catalog.localized(key, language: language)
    }
}

private struct RemoteHelpArticleView: View {
    let article: MixPilotHelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: article.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 58, height: 58)
                    .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                Text(article.title)
                    .font(.largeTitle.bold())

                Text(article.summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Divider()

                Text(article.body)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
