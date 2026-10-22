import SwiftUI

@main struct PasseioCertoApp: App {
    var body: some Scene { WindowGroup { GameView() } }
}

struct Puppy: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                Ellipse().fill(Color(red: 0.82, green: 0.80, blue: 0.73)).frame(width: w*0.9, height: w*0.65).offset(y: w*0.06)
                ForEach(0..<12) { i in
                    Circle().fill(Color(red: 0.97, green: 0.96, blue: 0.90))
                        .frame(width: w*0.32, height: w*0.32)
                        .offset(x: cos(Double(i)*Double.pi/6)*w*0.29, y: sin(Double(i)*Double.pi/6)*w*0.27)
                }
                Circle().fill(Color(red: 0.97, green: 0.96, blue: 0.90)).frame(width: w*0.65)
                HStack(spacing: w*0.22) {
                    Circle().fill(.black).frame(width: w*0.09)
                    Circle().fill(.black).frame(width: w*0.09)
                }.offset(y: -w*0.03)
                Ellipse().fill(.black).frame(width: w*0.16, height: w*0.11).offset(y: w*0.16)
                HStack { Capsule().fill(Color(red: 0.88, green: 0.86, blue: 0.78)).frame(width: w*0.19, height: w*0.38); Spacer(); Capsule().fill(Color(red: 0.88, green: 0.86, blue: 0.78)).frame(width: w*0.19, height: w*0.38) }.padding(.horizontal, w*0.02)
            }.frame(width: w, height: g.size.height)
        }.accessibilityHidden(true)
    }
}
struct GameView: View {
    @State private var game = Game()
    @State private var marking = false
    @State private var reset = false
    @State private var message = "Os números indicam quantas casas o caminho ocupa."
    private let green = Color(red: 0.20, green: 0.35, blue: 0.27)
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Passeio Certo").font(.largeTitle.bold()).foregroundStyle(green)
                Text("Praça das Flores · Fase 1").font(.subheadline)
                Puppy().frame(width: 78, height: 78)
                Text(game.won ? "Chegamos em casa!" : "Leve sua companheira até a casinha").font(.title3.bold()).multilineTextAlignment(.center)
                board.aspectRatio(1, contentMode: .fit)
                Text(message).font(.callout).multilineTextAlignment(.center)
                Picker("Ferramenta", selection: $marking) {
                    Text("Caminho").tag(false)
                    Text("Marcar ×").tag(true)
                }.pickerStyle(.segmented)
                HStack {
                    Button("Desfazer", systemImage: "arrow.uturn.backward") { game.undo() }.disabled(!game.canUndo)
                    Spacer()
                    Button("Reiniciar", systemImage: "arrow.clockwise") { reset = true }
                }.buttonStyle(.bordered)
                Text("Toque nas casas vizinhas para desenhar. Volte uma casa para apagar o último trecho.").font(.footnote).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }.background(Color(red: 0.97, green: 0.95, blue: 0.89)).tint(green)
            .confirmationDialog("Reiniciar esta fase?", isPresented: $reset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) { game = Game() }
            }
    }
    private var board: some View {
        GeometryReader { geo in
            let side = geo.size.width / 6
            ZStack(alignment: .topLeading) {
                ForEach(0..<5) { i in
                    clue(game.columns[i], game.columnCounts[i]).frame(width: side, height: side).offset(x: Double(i+1)*side)
                    clue(game.rows[i], game.rowCounts[i]).frame(width: side, height: side).offset(y: Double(i+1)*side)
                }
                ForEach(0..<25) { i in
                    let cell = Cell(i/5, i%5)
                    Button {
                        if !game.play(cell, marking: marking) { message = "Use uma casa vizinha livre, sem ultrapassar as pistas." }
                        else { message = game.won ? "Todas as pistas foram atendidas. Muito bem!" : "Continue seguindo as pistas das linhas e colunas." }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.85))
                            if cell == game.start { Puppy().padding(5) }
                            else if cell == game.goal { Image(systemName: "house.fill").font(.title2).foregroundStyle(Color(red: 0.68, green: 0.37, blue: 0.26)) }
                            else if game.marks.contains(cell) { Text("×").font(.title).foregroundStyle(.secondary) }
                        }
                    }.buttonStyle(.plain).frame(width: side-4, height: side-4)
                        .offset(x: Double(cell.col+1)*side+2, y: Double(cell.row+1)*side+2)
                        .accessibilityLabel("Linha \(cell.row+1), coluna \(cell.col+1)" )
                        .accessibilityValue(cell == game.start ? "Cachorrinha" : cell == game.goal ? "Casa" : game.path.contains(cell) ? "Caminho" : game.marks.contains(cell) ? "Marcada com xis" : "Livre")
                }
                Path { p in
                    for (i, c) in game.path.enumerated() {
                        let point = CGPoint(x: (Double(c.col)+1.5)*side, y: (Double(c.row)+1.5)*side)
                        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                    }
                }.stroke(green.opacity(0.65), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)).allowsHitTesting(false)
            }
        }
    }
    private func clue(_ target: Int, _ count: Int) -> some View {
        Text(count == target ? "\(target) ✓" : "\(target)").font(.headline).foregroundStyle(count == target ? green : .secondary)
            .accessibilityLabel("\(count) de \(target) casas ocupadas")
    }
}
