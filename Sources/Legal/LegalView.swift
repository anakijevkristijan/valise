import SwiftUI

/// Политиката за приватност / Условите - прикажани во апликацијата (работи и без интернет).
struct LegalView: View {
    let doc: LegalDoc
    @Environment(\.dismiss) private var dismiss

    private enum Block {
        case title(String)
        case heading(String)
        case bullet(AttributedString)
        case paragraph(AttributedString)
    }

    private var blocks: [Block] {
        LegalTexts.markdown(doc)
            .components(separatedBy: "\n")
            .compactMap { raw -> Block? in
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty { return nil }
                if line.hasPrefix("## ") { return .heading(String(line.dropFirst(3))) }
                if line.hasPrefix("# ") { return .title(String(line.dropFirst(2))) }
                if line.hasPrefix("- ") { return .bullet(Self.inline(String(line.dropFirst(2)))) }
                return .paragraph(Self.inline(line))
            }
    }

    private static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        view(for: block)
                    }
                    if !LegalTexts.supportEmail.isEmpty,
                       let url = URL(string: "mailto:\(LegalTexts.supportEmail)") {
                        Link(destination: url) {
                            Label(L("Пиши ни", "Write to us"), systemImage: "envelope")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 40)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }

            CircleIconButton(systemName: "xmark") { dismiss() }
                .padding(20)
                .accessibilityLabel(L("Затвори", "Close"))
        }
        .presentationCornerRadius(28)
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .title(let text):
            Text(text)
                .font(.serif(32))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let text):
            Text(text)
                .font(.serif(21))
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("•").foregroundStyle(Theme.gold)
                Text(text)
                    .font(.sans(15))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .paragraph(let text):
            Text(text)
                .font(.sans(15))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// „Со продолжување се согласуваш со Условите и Политиката“ - со линкови до двата текста.
struct LegalConsentNote: View {
    @State private var shown: LegalDoc?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Со продолжување се согласуваш со:", "By continuing you agree to the:"))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 14) {
                Button(L("Услови за користење", "Terms of Use")) { shown = .terms }
                Button(L("Политика за приватност", "Privacy Policy")) { shown = .privacy }
            }
            .font(.sans(12, .semibold))
            .foregroundStyle(Theme.navy)
            .buttonStyle(.plain)
        }
        .sheet(item: $shown) { doc in
            LegalView(doc: doc)
        }
    }
}
