import SwiftUI

/// По најавата: телефонскиот број, за пријателите да те најдат од своите контакти.
/// Се чува само шифриран отпечаток. Може да се прескокне и да се внесе подоцна во Профил.
struct PhoneStepView: View {
    static let askedKey = "phoneAsked"

    @EnvironmentObject private var account: AccountService
    @AppStorage("userName") private var userName: String = ""
    @AppStorage(PhoneStepView.askedKey) private var asked: Bool = false

    @State private var phone = ""
    @State private var region = PhoneID.defaultRegion
    @State private var invalid = false
    @State private var saving = false
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TRIPDROBE")
                        .font(.sans(12, .semibold))
                        .tracking(4)
                        .foregroundStyle(Theme.navy)
                        .padding(.top, 20)
                        .padding(.bottom, 40)

                    Eyebrow(L("Пријатели", "Friends"), color: Theme.gold)
                        .padding(.bottom, 12)

                    Text(L("Твојот\nтелефонски број", "Your\nphone number"))
                        .font(.serif(34))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .padding(.bottom, 14)

                    Text(L("Пријателите што те имаат во контакти ќе те најдат и ќе те додадат во патување — без кодови и линкови.",
                           "Friends who have you in their contacts can find you and add you to a trip — no codes, no links."))
                        .font(.sans(15))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            // Кодот на земјата е веќе внесен (според телефонот) — се допишува само бројот
                            Menu {
                                Picker(selection: $region) {
                                    ForEach(PhoneID.regions, id: \.self) { code in
                                        Text("\(PhoneID.flag(code))  \(PhoneID.regionName(code))  +\(PhoneID.callingCode(for: code))")
                                            .tag(code)
                                    }
                                } label: {
                                    EmptyView()
                                }
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(PhoneID.flag(region))
                                        .font(.system(size: 20))
                                    Text("+\(PhoneID.callingCode(for: region))")
                                        .font(.serif(26))
                                        .foregroundStyle(Theme.ink)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Theme.muted)
                                }
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel(L("Код на земјата", "Country code"))

                            TextField("", text: $phone, prompt: Text(region == "MK" ? "70 123 456" : "123 456 789").foregroundColor(Theme.muted.opacity(0.7)))
                                .font(.serif(26))
                                .foregroundStyle(Theme.ink)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .focused($focused)
                        }
                        Rectangle()
                            .fill(focused ? Theme.navy : Theme.hairline)
                            .frame(height: 1)
                        if invalid {
                            Text(L("Провери го бројот.", "Please check the number."))
                                .font(.sans(13, .medium))
                                .foregroundStyle(Theme.terracotta)
                        }
                    }
                    .padding(.bottom, 14)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 2)
                        Text(L("Не го чуваме самиот број — само шифриран отпечаток. Никој не може да го види.",
                               "We never store the number itself — only an encrypted fingerprint. No one can see it."))
                            .font(.sans(12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 28)

                    Button(action: save) {
                        HStack(spacing: 10) {
                            if saving { ProgressView().tint(Theme.goldLight) }
                            Text(L("Продолжи", "Continue"))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(phone.trimmingCharacters(in: .whitespaces).isEmpty || saving)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { asked = true }
                    } label: {
                        Text(L("Прескокни — ќе го внесам подоцна во Профил", "Skip — I'll add it later in Profile"))
                            .font(.sans(14, .medium))
                            .foregroundStyle(Theme.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    /// Целиот број: кодот на земјата + внесеното (без почетната нула).
    /// Ако е внесен цел меѓународен број (+… или 00…), се зема таков.
    private var fullNumber: String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+") || trimmed.hasPrefix("00") { return trimmed }
        var digits = trimmed.filter { $0.isASCII && $0.isNumber }
        while digits.hasPrefix("0") { digits.removeFirst() }
        return "+" + PhoneID.callingCode(for: region) + digits
    }

    private func save() {
        guard PhoneID.normalize(fullNumber) != nil else {
            invalid = true
            return
        }
        invalid = false
        saving = true
        focused = false
        Task { @MainActor in
            await account.updateProfile(name: userName, phone: fullNumber)
            saving = false
            withAnimation(.easeInOut(duration: 0.3)) { asked = true }
        }
    }
}
