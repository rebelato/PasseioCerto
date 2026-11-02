import SwiftUI

/// Gallery of visual states, including components reserved for later features.
struct GardenGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GardenTheme.spacing) {
            Text("Passeio Certo").font(GardenTheme.title)
            Text("Praça das Flores · Fase 1").font(.subheadline)
            HStack {
                Puppy().frame(width: 52, height: 52)
                Text("Leve a Margot até a casinha").font(GardenTheme.heading)
            }.padding(12).background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: 18))
            HStack {
                GardenClue(target: 3, count: 1, label: "Pendente")
                GardenClue(target: 3, count: 3, label: "Atendida")
                GardenClue(target: 3, count: 4, label: "Excedida")
            }.frame(height: 60)
            HStack {
                GardenCell()
                GardenCell(occupied: true)
                GardenCell(excluded: true)
                GardenCell(obstacle: true)
                GardenCell(highlighted: true)
            }.frame(height: 48)
            GardenNote(text: "A coluna 3 já está completa. Marque as outras casas com ×.", symbol: "lightbulb")
            PawScore(paws: 2)
            HStack {
                Button("Desfazer", systemImage: "arrow.uturn.backward") {}
                Button("Dica", systemImage: "lightbulb") {}
            }.buttonStyle(GardenButtonStyle())
            Text("Galeria de componentes · prévia visual").font(.footnote)
        }.padding(16).foregroundStyle(GardenTheme.ink).background(GardenTheme.background)
    }
}
struct GardenPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            GameView().previewDisplayName("Partida")
            GardenGallery().previewDisplayName("Componentes")
            GardenGallery().environment(\.colorScheme, .dark).previewDisplayName("Escuro")
            GardenGallery().environment(\.dynamicTypeSize, .accessibility2).previewDisplayName("Texto ampliado")
        }
    }
}
