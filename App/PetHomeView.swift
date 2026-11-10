import SwiftUI

/// Margot's room, the home screen: her needs, her furniture and toys, and the way out for a walk.
struct PetHomeView: View {
    @ObservedObject var session: GameSession
    let onPlay: () -> Void
    let onDaily: (Date) -> Void
    let onSettings: () -> Void
    let onFeedback: (GameFeedback.Kind) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sheet: HomeSheet?
    @State private var hearts = 0
    @State private var bounce = false
    @State private var note: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollView {
                VStack(spacing: 16) {
                    topBar
                    room
                    needs
                    actions
                    walkButton
                    dailyCard(DailyChallenge(date: timeline.date), now: timeline.date)
                    if session.generating {
                        ProgressView(String(localized: "Preparando passeio…"))
                        Button(String(localized: "Cancelar")) { session.cancelGeneration() }.buttonStyle(GardenButtonStyle())
                    }
                    if let error = session.storageError {
                        GardenNote(text: error + String(localized: " Abra Passear para acessar a recuperação."), symbol: "exclamationmark.triangle")
                    }
                }.padding(.horizontal, 16).padding(.bottom, 20).frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
        }
        .background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(GardenTheme.ink)
        .sheet(item: $sheet) { which in
            switch which {
            case .shop(let tab): ShopView(session: session, initialTab: tab) { sheet = nil }
            case .album: AlbumView(session: session) { sheet = nil }
            case .bowl: BowlSheet(session: session, onFeed: feed, onShop: { sheet = .shop(.food) })
            case .slot(let slot): SlotSheet(session: session, slot: slot, onShop: { sheet = .shop(.home) }) { sheet = nil }
            }
        }
        .task {
            // Screenshot checks: -PCOpenShop YES, optionally -PCShopTab home|accessory|toy.
            if UserDefaults.standard.bool(forKey: "PCOpenShop") {
                sheet = .shop(UserDefaults.standard.string(forKey: "PCShopTab").flatMap(ShopTab.init) ?? .food)
            }
        }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            CoinPill(coins: session.pet.coins)
            Spacer()
            Text(String(localized: "Casa da \(session.dogName)")).font(GardenTheme.heading).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Button(action: onSettings) { Image(systemName: "gearshape").font(.title3) }
                .frame(width: GardenTheme.minTarget, height: GardenTheme.minTarget)
                .accessibilityLabel(String(localized: "Ajustes"))
        }
    }

    private var room: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let floorTop = h * 0.58
            ZStack(alignment: .topLeading) {
                RoomPalette.wall(session.pet.wall)
                FloorArt(id: session.pet.floor).frame(width: w, height: h - floorTop).offset(y: floorTop)
                Rectangle().fill(.black.opacity(0.08)).frame(width: w, height: 3).offset(y: floorTop)
                WindowArt().frame(width: w * 0.28, height: w * 0.22).offset(x: w * 0.36, y: h * 0.08)
                slotButton(.wallLeft, size: w * 0.22).offset(x: w * 0.07, y: h * 0.12)
                slotButton(.wallRight, size: w * 0.22).offset(x: w * 0.71, y: h * 0.12)
                slotButton(.rug, size: w * 0.5, height: w * 0.2).offset(x: w * 0.25, y: h * 0.8)
                slotButton(.floorLeft, size: w * 0.26).offset(x: w * 0.03, y: floorTop - w * 0.1)
                slotButton(.floorRight, size: w * 0.26).offset(x: w * 0.71, y: floorTop - w * 0.1)
                toys(width: w).offset(x: w * 0.04, y: h - w * 0.15)
                margot(size: w * 0.34).offset(x: w * 0.33, y: floorTop - w * 0.08)
                SpeechBubble(text: note ?? session.pet.speech).frame(maxWidth: w * 0.6).offset(x: w * 0.2, y: floorTop - w * 0.26)
            }
            .clipShape(RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.5)))
        }.aspectRatio(1, contentMode: .fit)
    }

    private func margot(size: CGFloat) -> some View {
        let mood = session.pet.mood
        return Button { petMargot() } label: {
            Puppy(pose: mood == .happy ? .happy : .idle, accessory: session.preferences.accessory)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(mood == .sad || mood == .hungry ? -8 : 0))
                .saturation(mood == .sad || mood == .hungry ? 0.7 : 1)
                .offset(y: bounce ? -size * 0.12 : 0)
                .overlay(alignment: .top) {
                    ForEach(0..<hearts, id: \.self) { i in
                        Image(systemName: "heart.fill").foregroundStyle(GardenTheme.terracotta)
                            .offset(x: CGFloat(i % 3 - 1) * 18, y: -CGFloat(10 + i * 8))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
        }.buttonStyle(.plain)
            .accessibilityLabel(String(localized: "\(session.dogName). Toque para fazer carinho."))
    }

    private func slotButton(_ slot: RoomSlot, size: CGFloat, height: CGFloat? = nil) -> some View {
        Button { sheet = .slot(slot) } label: {
            Group {
                if let id = session.pet.room[slot] { FurnitureArt(id: id) }
                else {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        .foregroundStyle(GardenTheme.secondary.opacity(0.35))
                        .overlay(Image(systemName: "plus").foregroundStyle(GardenTheme.secondary.opacity(0.5)))
                }
            }.frame(width: size, height: height ?? size)
        }.buttonStyle(.plain)
            .accessibilityLabel(session.pet.room[slot].flatMap { ShopCatalog.item($0)?.title } ?? String(localized: "Espaço vazio para decorar"))
    }

    private func toys(width: CGFloat) -> some View {
        HStack(spacing: width * 0.02) {
            ForEach(ShopCatalog.items(in: .toy).filter { session.pet.owns($0.id) }) { toy in
                let ready = session.pet.canPlay(with: toy.id, now: session.now())
                Button { play(toy) } label: {
                    ToyArt(id: toy.id).frame(width: width * 0.12, height: width * 0.12).opacity(ready ? 1 : 0.45)
                }.buttonStyle(.plain)
                    .accessibilityLabel(ready ? String(localized: "\(toy.title): brincar") : String(localized: "\(toy.title): descansando"))
            }
        }
    }

    private var needs: some View {
        VStack(spacing: 10) {
            NeedBar(title: String(localized: "Fome"), symbol: "fork.knife", value: session.pet.hunger, color: GardenTheme.trail)
            NeedBar(title: String(localized: "Alegria"), symbol: "heart.fill", value: session.pet.joy, color: GardenTheme.terracotta)
        }.padding(14)
            .background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.4)))
    }

    private var actions: some View {
        HStack(spacing: 4) {
            Button(String(localized: "Comer"), systemImage: "fork.knife") { sheet = .bowl }
            Button(String(localized: "Loja"), systemImage: "bag") { sheet = .shop(.food) }
            Button(String(localized: "Álbum"), systemImage: "photo.on.rectangle") { sheet = .album }
        }.buttonStyle(GardenIconButtonStyle())
            .padding(4).background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.5)))
    }

    private var modePicker: some View {
        ScrollViewReader { reader in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LogicMode.allCases, id: \.self) { mode in
                    let chosen = session.preferences.mode == mode
                    Button { session.setMode(mode) } label: {
                        Label(mode.title, systemImage: mode.symbol).font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .foregroundStyle(chosen ? GardenTheme.background : GardenTheme.ink)
                            .background(chosen ? GardenTheme.ink : GardenTheme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(GardenTheme.border.opacity(chosen ? 0 : 0.5)))
                    }.buttonStyle(.plain).accessibilityAddTraits(chosen ? .isSelected : []).id(mode)
                }
            }.padding(.horizontal, 2)
        }
        .onAppear { reader.scrollTo(session.preferences.mode, anchor: .center) }
        .onChange(of: session.preferences.mode) { _, mode in withAnimation { reader.scrollTo(mode, anchor: .center) } }
        }
    }

    private var walkButton: some View {
        let chosen = session.preferences.difficulty, mode = session.preferences.mode
        let size = mode.size(chosen)
        return VStack(spacing: 8) {
            modePicker
            Button(action: onPlay) {
                VStack(spacing: 2) {
                    Label(mode == .path ? String(localized: "Passear") : String(localized: "Jogar"), systemImage: mode.symbol)
                    Text(String(localized: "\(chosen.title) · até \(Rewards.base(chosen) * GameAttempt.maxLives) moedas")).font(.footnote.weight(.medium)).opacity(0.85)
                }
            }.buttonStyle(GardenButtonStyle(prominent: true)).disabled(session.generating)
            DifficultyPicker(selection: Binding(get: { session.preferences.difficulty }, set: { session.setDifficulty($0) }))
            Text(mode != .path ? String(localized: "\(mode.title): grade \(size) × \(size), 3 vidas.")
                 : chosen.hiddenHouse ? String(localized: "Grade \(size) × \(size), casinha escondida, 3 vidas.")
                 : String(localized: "Grade \(size) × \(size), casinha à vista, 3 vidas."))
                .font(.footnote).foregroundStyle(GardenTheme.secondary).multilineTextAlignment(.center)
        }
    }

    private func dailyCard(_ daily: DailyChallenge, now: Date) -> some View {
        let done = session.completedPuzzleIDs.contains(daily.id)
        let streak = session.dailyStreak(today: now)
        return Button { onDaily(now) } label: {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.seal.fill" : "calendar").font(.title)
                    .foregroundStyle(done ? GardenTheme.accent : GardenTheme.terracotta)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Desafio do dia")).font(GardenTheme.heading)
                    Text(done ? String(localized: "Concluído! Novo desafio em \(DailyCountdown.text(from: now))")
                              : String(localized: "Bônus de \(50 + min(100, 10 * (streak + 1))) moedas · termina em \(DailyCountdown.text(from: now))"))
                        .font(.subheadline).foregroundStyle(GardenTheme.secondary)
                    if streak > 0 {
                        Label(streak == 1 ? String(localized: "1 dia seguido") : String(localized: "\(streak) dias seguidos"), systemImage: "flame.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(GardenTheme.terracotta)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward").foregroundStyle(GardenTheme.secondary)
            }.padding(16)
                .background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.6)))
        }.buttonStyle(.plain).disabled(session.generating)
    }

    // MARK: Care

    private func petMargot() {
        guard session.petMargot() else { hop(); return }
        onFeedback(.step)
        withAnimation(.easeOut(duration: 0.3)) { hearts = 3 }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeIn(duration: 0.3)) { hearts = 0 }
        }
        hop()
    }
    private func feed(_ item: ShopItem) {
        guard session.feed(item.id) else { return }
        sheet = nil
        onFeedback(.clueMet)
        say(String(localized: "Nham! \(item.title) é a melhor coisa do mundo."))
        hop()
    }
    private func play(_ toy: ShopItem) {
        let now = session.now()
        guard session.play(with: toy.id) else {
            let minutes = Int(ceil(session.pet.toyCooldownLeft(toy.id, now: now) / 60))
            say(String(localized: "Já brinquei com isso! Volta em \(minutes) min."))
            return
        }
        onFeedback(.clueMet)
        say(String(localized: "Uhuul! Mais uma vez!"))
        hop(); Task { try? await Task.sleep(for: .milliseconds(450)); hop() }
    }
    private func hop() {
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.25)) { bounce = true }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(duration: 0.3)) { bounce = false }
        }
    }
    private func say(_ text: String) {
        note = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if note == text { note = nil }
        }
    }
}

enum HomeSheet: Identifiable {
    case shop(ShopTab), album, bowl, slot(RoomSlot)
    var id: String {
        switch self {
        case .shop(let tab): "shop-\(tab.rawValue)"
        case .album: "album"
        case .bowl: "bowl"
        case .slot(let slot): "slot-\(slot.rawValue)"
        }
    }
}

struct CoinPill: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 6) {
            CoinIcon()
            Text("\(coins)").font(GardenTheme.heading).monospacedDigit().contentTransition(.numericText())
        }.padding(.horizontal, 12).padding(.vertical, 6)
            .background(GardenTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(GardenTheme.border.opacity(0.5)))
            .animation(.snappy, value: coins)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "\(coins) moedas"))
    }
}

struct NeedBar: View {
    let title: String
    let symbol: String
    let value: Double
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).frame(width: 96, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(GardenTheme.sage)
                    Capsule().fill(value < 30 ? GardenTheme.error : color).frame(width: max(8, proxy.size.width * value / 100))
                }
            }.frame(height: 12)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(title).accessibilityValue(String(localized: "\(Int(value.rounded())) de 100"))
            .animation(.easeOut(duration: 0.4), value: value)
    }
}

struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote.weight(.medium)).multilineTextAlignment(.center)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GardenTheme.border.opacity(0.5)))
            .animation(.easeOut(duration: 0.2), value: text)
    }
}

struct WindowArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.62, green: 0.42, blue: 0.28))
            RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.70, green: 0.86, blue: 0.97)).padding(6)
            Circle().fill(.white.opacity(0.9)).frame(width: 22, height: 14).offset(x: -10, y: -6)
            Rectangle().fill(Color(red: 0.62, green: 0.42, blue: 0.28)).frame(width: 4)
            Rectangle().fill(Color(red: 0.62, green: 0.42, blue: 0.28)).frame(height: 4)
        }.accessibilityHidden(true)
    }
}

/// Food from the pantry, one tap to feed.
private struct BowlSheet: View {
    @ObservedObject var session: GameSession
    let onFeed: (ShopItem) -> Void
    let onShop: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Text(String(localized: "O que a \(session.dogName) vai comer?")).font(.title3.weight(.bold)).fontDesign(.serif)
            let pantry = ShopCatalog.items(in: .food).filter { session.pet.portions(of: $0.id) > 0 }
            if pantry.isEmpty {
                Text(String(localized: "A despensa está vazia.")).foregroundStyle(GardenTheme.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                ForEach(pantry) { item in
                    Button { onFeed(item) } label: {
                        VStack(spacing: 4) {
                            FoodArt(id: item.id).frame(width: 56, height: 56)
                            Text(item.title).font(.caption.weight(.semibold))
                            Text("× \(session.pet.portions(of: item.id))").font(.caption2).foregroundStyle(GardenTheme.secondary)
                        }.frame(maxWidth: .infinity).padding(10)
                            .background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
                    }.buttonStyle(.plain)
                }
            }
            Button(String(localized: "Comprar comida"), systemImage: "bag", action: onShop).buttonStyle(GardenButtonStyle())
        }.padding(24).foregroundStyle(GardenTheme.ink).tint(GardenTheme.ink)
            .presentationDetents([.medium]).presentationBackground(GardenTheme.background)
    }
}

/// Choose what goes in one spot of the room.
private struct SlotSheet: View {
    @ObservedObject var session: GameSession
    let slot: RoomSlot
    let onShop: () -> Void
    let onClose: () -> Void
    var body: some View {
        let options = ShopCatalog.items(in: .furniture).filter { $0.furniture == slot.kind && session.pet.owns($0.id) }
        VStack(spacing: 14) {
            Text(slot.kind == .wall ? String(localized: "Na parede") : slot.kind == .rug ? String(localized: "No chão, no meio") : String(localized: "No canto"))
                .font(.title3.weight(.bold)).fontDesign(.serif)
            if options.isEmpty {
                Text(String(localized: "Você ainda não tem nada para este espaço.")).foregroundStyle(GardenTheme.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                ForEach(options) { item in
                    let here = session.pet.room[slot] == item.id
                    Button { session.place(item.id, in: slot); onClose() } label: {
                        VStack(spacing: 4) {
                            FurnitureArt(id: item.id).frame(width: 56, height: 56)
                            Text(item.title).font(.caption.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(10)
                            .background(here ? GardenTheme.sage : GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
                    }.buttonStyle(.plain)
                }
            }
            if session.pet.room[slot] != nil {
                Button(String(localized: "Deixar vazio")) { session.place(nil, in: slot); onClose() }.buttonStyle(GardenButtonStyle())
            }
            Button(String(localized: "Ver móveis na loja"), systemImage: "bag", action: onShop).buttonStyle(GardenButtonStyle())
        }.padding(24).foregroundStyle(GardenTheme.ink).tint(GardenTheme.ink)
            .presentationDetents([.medium, .large]).presentationBackground(GardenTheme.background)
    }
}
