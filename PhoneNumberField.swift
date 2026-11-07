import SwiftUI

/// Телефонски број со кодот на земјата: знаме и +389 (според телефонот) + бројот.
/// Врзан за целиот број, на пр. „+38970123456“; празно ако не е внесено ништо.
/// Со допир на кодот се избира друга земја.
struct PhoneNumberField: View {
    @Binding var number: String
    var fontSize: CGFloat = 19

    @State private var region = PhoneID.defaultRegion
    @State private var local = ""
    @State private var didSetup = false

    private var composed: String { PhoneID.compose(region: region, local: local) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
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
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(PhoneID.flag(region))
                        .font(.system(size: fontSize * 0.8))
                    Text("+\(PhoneID.callingCode(for: region))")
                        .font(.serif(fontSize))
                        .foregroundStyle(Theme.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .accessibilityLabel(L("Код на земјата", "Country code"))

            TextField("", text: $local,
                      prompt: Text(region == "MK" ? "70 123 456" : "123 456 789")
                        .foregroundColor(Theme.muted.opacity(0.7)))
                .font(.serif(fontSize))
                .foregroundStyle(Theme.ink)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
        }
        .onAppear {
            guard !didSetup else { return }
            didSetup = true
            load(number)
        }
        .onChange(of: local) { _, typed in
            // Залепен или автоматски пополнет цел број (+389… или 00389…) → се дели на код и број
            let trimmed = typed.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("+") || trimmed.hasPrefix("00") {
                load(trimmed)
                return
            }
            publish()
        }
        .onChange(of: region) { _, _ in publish() }
        .onChange(of: number) { _, latest in
            // Променето однадвор (пр. вчитан зачуван број)
            if latest != composed { load(latest) }
        }
    }

    private func load(_ full: String) {
        let parts = PhoneID.split(full)
        region = parts.region
        local = parts.local
        publish()
    }

    private func publish() {
        if number != composed { number = composed }
    }
}
