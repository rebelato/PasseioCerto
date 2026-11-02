import SwiftUI

/// The meta layer: places reached, Margot's accessories, and a polaroid of every finished walk.
struct CornerView: View {
    @ObservedObject var session: GameSession
    let onClose: () -> Void
    /// Plays any level directly, reached or not.
    let onPlay: (WorldLevel) -> Void
    @State private var choosingWorld: World?
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 16) {
                        Puppy(pose: .happy, accessory: session.preferences.accessory).frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.dogName).font(.title2.weight(.bold)).fontDesign(.serif)
                            Label(String(localized: "\(session.totalPaws) patinhas"), systemImage: "pawprint.fill")
                                .foregroundStyle(GardenTheme.terracotta).font(GardenTheme.heading)
                        }
                    }
                    places
                    accessories
                    album
                }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
            .navigationTitle(String(localized: "Seu cantinho")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Fechar"), action: onClose) } }
        }.tint(GardenTheme.ink)
    }

    private var places: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Lugares")).font(GardenTheme.heading)
            Text(String(localized: "Toque num lugar para escolher a fase, mesmo antes de chegar nele. Isso não muda o seu progresso."))
                .font(.footnote).foregroundStyle(GardenTheme.secondary)
            ForEach(World.allCases, id: \.self) { world in
                let reached = session.unlockedWorlds.contains(world)
                let done = world < session.progress.world ? World.levelsPerWorld : world == session.progress.world ? session.progress.level : 0
                Button { choosingWorld = world } label: {
                HStack(spacing: 14) {
                    Image(systemName: reached ? world.symbol : "lock.fill").font(.title2).frame(width: 36)
                        .foregroundStyle(reached ? GardenTheme.accent : GardenTheme.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(world.title).font(GardenTheme.heading)
                        Text((world.newRule.map { $0.explanation } ?? String(localized: "Onde tudo começa.")) + " " + String(localized: "Grade \(world.size) × \(world.size)."))
                            .font(.footnote).foregroundStyle(GardenTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if reached { Text("\(done)/\(World.levelsPerWorld)").font(.subheadline.monospacedDigit()).foregroundStyle(GardenTheme.secondary) }
                    Image(systemName: "chevron.forward").foregroundStyle(GardenTheme.secondary)
                }.padding(14)
                    .background(reached ? GardenTheme.surface : GardenTheme.background, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                    .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.5)))
                    .contentShape(RoundedRectangle(cornerRadius: GardenTheme.radius))
                }.buttonStyle(.plain)
                    .accessibilityHint(String(localized: "Escolher uma fase deste lugar"))
            }
        }
        .confirmationDialog(choosingWorld?.title ?? "", isPresented: Binding(get: { choosingWorld != nil }, set: { if !$0 { choosingWorld = nil } }),
                            titleVisibility: .visible, presenting: choosingWorld) { world in
            ForEach(0..<World.levelsPerWorld, id: \.self) { level in
                Button(level == World.levelsPerWorld - 1 ? String(localized: "Fase \(level+1) · a mais difícil") : String(localized: "Fase \(level+1)")) {
                    onPlay(WorldLevel(world: world, level: level))
                }
            }
        } message: { world in
            Text(session.preferences.hiddenHouse ? String(localized: "Grade \(world.size) × \(world.size), com a casinha escondida.") : String(localized: "Grade \(world.size) × \(world.size)."))
        }
    }

    private var accessories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Acessórios da \(session.dogName)")).font(GardenTheme.heading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 12)], spacing: 12) {
                ForEach(Accessory.allCases, id: \.self) { item in
                    let unlocked = session.unlockedAccessories.contains(item)
                    let worn = session.preferences.accessory == item
                    Button { session.wear(worn ? nil : item) } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Puppy(accessory: item).opacity(unlocked ? 1 : 0.25)
                                if !unlocked { Image(systemName: "lock.fill").foregroundStyle(GardenTheme.secondary) }
                            }.frame(width: 56, height: 56)
                            Text(unlocked ? item.title : String(localized: "\(item.cost) 🐾")).font(.caption.weight(.semibold))
                        }.frame(maxWidth: .infinity).padding(10)
                            .background(worn ? GardenTheme.sage : GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
                            .overlay(RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(worn ? GardenTheme.accent : GardenTheme.border.opacity(0.5), lineWidth: worn ? 2 : 1))
                    }.buttonStyle(.plain).disabled(!unlocked)
                        .accessibilityLabel(unlocked ? item.title : String(localized: "\(item.title), libera com \(item.cost) patinhas"))
                        .accessibilityAddTraits(worn ? .isSelected : [])
                }
            }
        }
    }

    private var album: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Álbum de passeios")).font(GardenTheme.heading)
            if session.walks.isEmpty {
                Text(String(localized: "Cada passeio concluído vira uma foto aqui.")).foregroundStyle(GardenTheme.secondary)
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(session.walks.reversed(), id: \.puzzle.puzzleID) { walk in
                    Polaroid(walk: walk, dogName: session.dogName, accessory: session.preferences.accessory)
                }
            }
        }
    }
}

/// A finished board as a little photo: route, Margot at home, place, date and paws.
struct Polaroid: View {
    let walk: WalkRecord
    let dogName: String
    var accessory: Accessory?
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let side = proxy.size.width / CGFloat(walk.puzzle.columns.count + 1)
                PuzzleBoard(game: Game(finished: walk), cellSide: side, interactionsEnabled: false, dogName: dogName, accessory: accessory, arrivalProgress: 1)
                    .allowsHitTesting(false)
            }.aspectRatio(CGFloat(walk.puzzle.columns.count + 1) / CGFloat(walk.puzzle.rows.count + 1), contentMode: .fit)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(walk.place?.title ?? String(localized: "Passeio")).font(.caption.weight(.semibold))
                    Text(walk.date, format: .dateTime.day().month()).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                PawScore(paws: walk.paws, size: .caption)
            }
        }.padding(10).padding(.bottom, 6)
            .background(.white, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(Color(red: 0.12, green: 0.2, blue: 0.15))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            .rotationEffect(.degrees(Double(walk.path.count % 5) - 2))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Foto do passeio em \(walk.place?.title ?? String(localized: "Passeio")), \(walk.paws) patinhas"))
    }
}

private extension Game {
    /// Replays a recorded route; records only hold verified finished walks.
    init(finished walk: WalkRecord) {
        self.init(puzzle: walk.puzzle)
        for cell in walk.path.dropFirst() { play(cell) }
    }
}
