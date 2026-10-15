import SwiftUI

struct OnboardingView: View {
    @AppStorage("userName") private var userName: String = ""
    @State private var name: String = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            LuxBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 56)

                    // Монограм
                    ZStack {
                        Circle()
                            .fill(Theme.surface)
                            .frame(width: 84, height: 84)
                            .shadow(color: Theme.gold.opacity(0.25), radius: 24, x: 0, y: 10)
                        Circle()
                            .strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1)
                            .frame(width: 84, height: 84)
                        Image(systemName: "suitcase.rolling")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(Theme.goldDeep)
                    }
                    .padding(.bottom, 34)

                    Eyebrow("Valise")
                        .padding(.bottom, 14)

                    Text("Пакувај паметно.\nПатувај лесно.")
                        .font(.serif(40))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .padding(.bottom, 16)

                    Text("Твој личен асистент што знае какво ќе е времето, колку собира торбата и што не смее да се заборави.")
                        .font(.sans(16))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(4)
                        .padding(.bottom, 36)

                    VStack(alignment: .leading, spacing: 18) {
                        feature("cloud.sun", "Листа според прогнозата", "Чадор само кога ќе треба, јакна само кога е студено.")
                        feature("ruler", "Без казни на аеродром", "Точни мерки за рачен багаж кај авиокомпаниите.")
                        feature("house", "Мирен излез од дома", "Шпорет, вода, прозорци — проверено пред да заклучиш.")
                    }
                    .padding(.bottom, 40)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("Како да те викам?", color: Theme.muted)
                        TextField("", text: $name, prompt: Text("Твоето име").foregroundColor(Theme.muted.opacity(0.7)))
                            .font(.serif(26))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focused)
                            .onSubmit(start)
                        Rectangle()
                            .fill(focused ? Theme.gold : Theme.hairline)
                            .frame(height: 1)
                            .animation(.easeInOut, value: focused)
                    }
                    .padding(.bottom, 30)

                    Button(action: start) {
                        HStack(spacing: 10) {
                            Text("Започни")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmed.isEmpty)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func start() {
        guard !trimmed.isEmpty else { return }
        focused = false
        userName = trimmed
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.goldDeep)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.goldLight.opacity(0.6)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
