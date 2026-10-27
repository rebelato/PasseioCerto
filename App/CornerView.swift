import SwiftUI

/// The meta layer: Margot's accessories and a polaroid of every finished walk.
struct CornerView: View {
    @ObservedObject var session: GameSession
    let onClose: () -> Void
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
                    accessories
                    album
                }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
            .navigationTitle(String(localized: "Seu cantinho")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Fechar"), action: onClose) } }
        }.tint(GardenTheme.ink)
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
                    Text(walk.difficulty?.title ?? String(localized: "Passeio")).font(.caption.weight(.semibold))
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
            .accessibilityLabel(String(localized: "Foto do passeio \(walk.difficulty?.title ?? String(localized: "livre")), \(walk.paws) patinhas"))
    }
}

private extension Game {
    /// Replays a recorded route; records only hold verified finished walks.
    init(finished walk: WalkRecord) {
        self.init(puzzle: walk.puzzle)
        for cell in walk.path.dropFirst() { play(cell) }
    }
}
