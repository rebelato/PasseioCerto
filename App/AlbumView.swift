import SwiftUI

/// A polaroid of every finished walk, newest first.
struct AlbumView: View {
    @ObservedObject var session: GameSession
    let onClose: () -> Void
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]
    var body: some View {
        NavigationStack {
            ScrollView {
                if session.walks.isEmpty {
                    Text(String(localized: "Cada passeio concluído vira uma foto aqui.")).foregroundStyle(GardenTheme.secondary).padding(.top, 40)
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(session.walks.reversed(), id: \.puzzle.puzzleID) { walk in
                        Polaroid(walk: walk, dogName: session.dogName, accessory: session.preferences.accessory, houseModel: session.pet.house)
                    }
                }.padding(20)
            }
            .background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
            .navigationTitle(String(localized: "Álbum de passeios")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Fechar"), action: onClose) } }
        }.tint(GardenTheme.ink)
    }
}

/// A finished board as a little photo: route, Margot at home, place, date and paws.
struct Polaroid: View {
    let walk: WalkRecord
    let dogName: String
    var accessory: Accessory?
    var houseModel = "house.classic"
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let side = proxy.size.width / CGFloat(walk.puzzle.columns.count + 1)
                PuzzleBoard(game: Game(finished: walk), cellSide: side, interactionsEnabled: false, dogName: dogName, accessory: accessory, houseModel: houseModel, arrivalProgress: 1)
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
