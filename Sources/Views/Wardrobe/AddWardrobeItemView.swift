import SwiftUI
import PhotosUI

/// Ново парче: слика → (означи) → стикер → име, категорија, сезони.
struct AddWardrobeItemView: View {
    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case source
        case crop(UIImage)
        case processing
        case details(UIImage)
    }

    @State private var step: Step = .source
    @State private var original: UIImage?
    @State private var selection: CGRect?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var problem: String?

    @State private var name = ""
    @State private var category: WardrobeCategory = .top
    @State private var seasons: Set<Season> = [Season.current]

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow(L("Ново парче", "New piece"), color: Theme.gold)
                    Spacer()
                    CircleIconButton(systemName: "xmark") { dismiss() }
                }
                switch step {
                case .source: sourceStep
                case .crop(let image): cropStep(image)
                case .processing: processingStep
                case .details(let sticker): detailsStep(sticker)
                }
            }
            .padding(24)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { begin(with: image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                begin(with: image)
                pickerItem = nil
            }
        }
    }

    // MARK: 1. Извор

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Сликај го парчето", "Photograph the piece"))
                .font(.serif(30))
                .foregroundStyle(Theme.ink)
            Text(L("Најдобро е парчето само — на кревет, на под или на закачалка, на светла подлога. Ќе го исечам како стикер.",
                   "Best with the piece on its own — on a bed, the floor or a hanger, on a light background. I'll cut it out as a sticker."))
                .font(.sans(15))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)

            if let problem { problemText(problem) }

            Spacer(minLength: 0)

            if CameraPicker.isAvailable {
                Button { showCamera = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L("Сликај", "Take a photo"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L("Од галерија", "From your photos"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Text(L("Цел лоок со човек? Во следниот чекор означи само парчето што го сакаш. Лицата никогаш не се зачувуваат.",
                   "A full look with a person? In the next step, mark just the piece you want. Faces are never saved."))
                .font(.sans(12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func begin(with image: UIImage) {
        let prepared = image.normalized(maxSide: 1600)
        original = prepared
        selection = nil
        problem = nil
        step = .crop(prepared)
    }

    // MARK: 2. Означи

    private func cropStep(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Означи го парчето", "Mark the piece"))
                .font(.serif(26))
                .foregroundStyle(Theme.ink)
            Text(L("Повлечи правоаголник околу облеката. Ако на сликата е само парчето, притисни „Цела слика“.",
                   "Drag a box around the clothing. If the photo shows only the piece, tap “Whole photo”."))
                .font(.sans(13))
                .foregroundStyle(Theme.inkSoft)

            if let problem { problemText(problem) }

            CropSelectView(image: image, selection: $selection)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                Button {
                    selection = nil
                    Task { await cut(image, crop: nil) }
                } label: {
                    Text(L("Цела слика", "Whole photo")).frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    Task { await cut(image, crop: selection) }
                } label: {
                    Text(L("Исечи", "Cut out"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selection == nil)
            }
        }
    }

    @MainActor
    private func cut(_ image: UIImage, crop: CGRect?) async {
        step = .processing
        switch await StickerMaker.make(from: image, crop: crop) {
        case .sticker(let sticker):
            problem = nil
            step = .details(sticker)
        case .hasFace:
            problem = L("На сликата има лице. Означи само облеката, без глава.", "There's a face in the photo. Mark only the clothing, without the head.")
            step = .crop(image)
        case .noSubject:
            problem = L("Не успеав да го најдам парчето. Пробај поблиску, на посветла подлога.", "I couldn't find the piece. Try closer, on a lighter background.")
            step = .crop(image)
        }
    }

    // MARK: 3. Сечење

    private var processingStep: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large).tint(Theme.navy)
            Text(L("Ја сечам облеката…", "Cutting it out…"))
                .font(.serif(20))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 4. Детали

    private func detailsStep(_ sticker: UIImage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.stone.opacity(0.6))
                    Image(uiImage: sticker)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .shadow(color: Theme.navy.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .frame(height: 260)

                WardrobeItemForm(name: $name, category: $category, seasons: $seasons)

                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let item = WardrobeItem(name: trimmed.isEmpty ? category.shortTitle : trimmed,
                                            category: category,
                                            seasons: Season.allCases.filter { seasons.contains($0) })
                    wardrobe.add(item, image: sticker)
                    dismiss()
                } label: {
                    Text(L("Зачувај во гардероба", "Save to wardrobe"))
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(L("Пробај повторно", "Try again")) {
                    if let original { step = .crop(original) }
                }
                .font(.sans(13, .medium))
                .foregroundStyle(Theme.navy)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func problemText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13))
            Text(text)
                .font(.sans(13, .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.terracotta)
    }
}

/// Име, категорија и сезони (се користи и при уредување).
struct WardrobeItemForm: View {
    @Binding var name: String
    @Binding var category: WardrobeCategory
    @Binding var seasons: Set<Season>

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(L("Име", "Name"))
                TextField("", text: $name, prompt: Text(L("пр. Црна кожна јакна", "e.g. Black leather jacket")).foregroundColor(Theme.muted.opacity(0.7)))
                    .font(.serif(22))
                    .foregroundStyle(Theme.ink)
                    .textInputAutocapitalization(.sentences)
                Hairline()
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(L("Категорија", "Category"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(WardrobeCategory.allCases) { option in
                        ChipButton(title: option.title, isSelected: category == option, expand: true) {
                            category = option
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(L("Сезони", "Seasons"))
                HStack(spacing: 8) {
                    ForEach(Season.allCases) { season in
                        Button {
                            if seasons.contains(season) { seasons.remove(season) } else { seasons.insert(season) }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: season.icon)
                                    .font(.system(size: 16, weight: .light))
                                Text(season.title)
                                    .font(.sans(11, .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(seasons.contains(season) ? Theme.goldLight : Theme.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(seasons.contains(season) ? Theme.navy : Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(seasons.contains(season) ? Theme.navy : Theme.hairline, lineWidth: 0.75))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }
}

/// Уредување постоечко парче.
struct EditWardrobeItemView: View {
    let item: WardrobeItem
    @EnvironmentObject private var wardrobe: WardrobeStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: WardrobeCategory
    @State private var seasons: Set<Season>

    init(item: WardrobeItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _seasons = State(initialValue: Set(item.seasons))
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Eyebrow(L("Уреди", "Edit"), color: Theme.gold)
                        Spacer()
                        CircleIconButton(systemName: "xmark") { dismiss() }
                    }
                    if let image = wardrobe.image(for: item) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .shadow(color: Theme.navy.opacity(0.18), radius: 10, x: 0, y: 6)
                    }
                    WardrobeItemForm(name: $name, category: $category, seasons: $seasons)
                    Button {
                        var updated = item
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.name = trimmed.isEmpty ? category.shortTitle : trimmed
                        updated.category = category
                        updated.seasons = Season.allCases.filter { seasons.contains($0) }
                        wardrobe.update(updated)
                        dismiss()
                    } label: {
                        Text(L("Зачувај", "Save"))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(24)
                .containerRelativeFrame(.horizontal)
            }
        }
    }
}
