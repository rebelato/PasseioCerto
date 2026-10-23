# Passeio Certo 🐾

Um jogo de lógica para iPhone: descubra o caminho que leva Bento até casa usando pistas numéricas nas linhas e colunas.

**Tecnologia planejada:** SwiftUI + núcleo em Swift puro. Fases geradas e verificadas localmente, com funcionamento offline.

## Comece aqui

- [Board de desenvolvimento no Trello](https://trello.com/b/5ryzhOIc/passeio-certo)
- [Plano completo: marcos, dependências e critérios de aceite](docs/plano.md)
- [Regras propostas do puzzle](docs/regras.md)
- [Direção visual e referência aprovada](docs/design.md)
- [Backlog estruturado com links para os cartões](docs/backlog.json)

O plano tem **26 tarefas para o primeiro beta** e **7 ideias pós-MVP**. As primeiras tarefas prontas para começar são:

1. [PC-001 · Preparar o projeto iOS em SwiftUI](https://trello.com/c/DTdqCQ67)
2. [PC-002 · Fechar as regras e criar fases de referência](https://trello.com/c/jSJI6UTs)
3. [PC-009 · Criar o DesignSystem a partir do esboço aprovado](https://trello.com/c/j97mpHNp)

## Estado atual

Primeira implementação local em SwiftUI: fase fixa 5×5, entrada por toque e arraste, pistas calculadas, marcações ×, desfazer, reiniciar com confirmação e vitória validada. Personagem provisório branco e cacheado inspirado na cachorrinha da foto.

Abra `PasseioCerto.xcodeproj` no Xcode e execute o esquema `PasseioCerto` em um iPhone Simulator. Para aparelho físico, selecione sua equipe de assinatura. Requer iOS 17 ou posterior.

Testes do núcleo: `swift test`. Verificação inicial: quatro testes passaram e build para iPhone Simulator concluído. A execução e revisão visual em aparelho ainda estão pendentes.

Ainda faltam validação dos gestos no aparelho, animação de chegada, arte final, tutorial e desafio diário. O marco M1 segue em andamento; os cartões representam o escopo completo, não apenas este incremento.

## Primeiro beta

Um cachorro, uma praça e grades 5×5. Desenhar o caminho, marcar ×, desfazer, receber dicas explicadas, continuar partidas e ver o cachorro chegar em casa. Depois do primeiro marco jogável com fases fixas, integrar geração automática, tutorial, desafio diário e personalização.

Cada fase gerada precisa passar por duas verificações: **solução única** e **resolução por deduções suportadas, sem chute**. Uma não substitui a outra.

Sem servidor, chamadas de IA ou anúncios no MVP. A partida tem 3 vidas por tentativa, com salvamento local (PC-012). O primeiro objetivo de distribuição é TestFlight; publicação pública é uma decisão posterior.

## Conceito visual aprovado

![Esboço inicial de Passeio Certo](docs/assets/conceito-inicial.png)

O esboço orienta a aparência. Tabuleiro, números, caminho e controles serão nativos e calculados por código; a imagem não será usada como uma tela pronta.

### Núcleo versionado (PC-003)

`Puzzle` guarda definição imutável, identidade, versões e seed opcional. `Game(puzzle:)` mantém rota ordenada, marcações e histórico separados. Ambos têm formato Codable; carregamento valida limites, versões, conexões e ocupação. Persistência em disco será implementada em PC-013.

Validação deste incremento: 12 testes passaram e build de iPhone Simulator aprovado. Fixtures válidas, impossível e ambígua estão em `PuzzleFixtures`. O projeto segue sem solver/gerador.

### Dificuldade e reservas (PC-008, em revisão)

O gerador aceita `difficulty: .relaxed` ou `.challenging` e tem duas fases de reserva verificadas por nível. A classificação é provisória. `generateAsync` executa a geração fora da MainActor com cancelamento; a ligação à tela permanece na PC-015.

[Relatório local e pendências da calibração](docs/validation/pc008.md). Medições reproduzíveis: `swift run -c release Calibration`. Verificação atual: 34 testes passando e build iOS aprovado. Ainda faltam playtest e medição em iPhone.

### Sessão e vidas (PC-012, em revisão)

Três vidas por tentativa. Jogadas impossíveis custam uma vida e são revertidas; ×, desfazer e erros de gesto não custam. Ao zerar, Tentar novamente limpa a partida mantendo a fase. O salvamento local atômico preserva vidas e derrota entre aberturas; falhas de leitura/escrita são informadas. Dicas e preferências ainda terão integração de persistência na PC-013.

50 testes passando e build iOS aprovado. Falta validação manual de gesto→erro→derrota→reinício e VoiceOver no iPhone.

### Persistência completa (PC-013, em revisão)

Formato v3 salva grade, rota, ×, histórico, vidas, preferências, posição no tutorial e IDs concluídos. Restaura a mesma grade, migra formatos anteriores e oferece recuperação por backup sem apagar silenciosamente dados inválidos. A ferramenta selecionada é restaurada; telas de som/hápticos e tutorial entram nas tarefas próprias. Gravações são atômicas e uma vitória não conta duas vezes.

57 testes passando e build iOS aprovado. Falta revisar recuperação e interrupção real no iPhone.

### Dicas explicadas (PC-014, em revisão)

O botão Dica apresenta a primeira dedução disponível, com coordenadas, destaque na célula e na pista relacionada. Considera as marcações × como hipóteses e informa conflitos ou ausência de dedução. Não consulta o gabarito, não aplica movimentos e não consome vidas. Jogar, reiniciar ou suspender descarta dicas antigas.

62 testes passando e build iOS aprovado. [Exemplo visual](docs/validation/hint-example.png) renderizado com SwiftUI no macOS; interação, rolagem e foco do VoiceOver ainda precisam de revisão no iPhone.

### Geração na tela (PC-015, em revisão)

Nova fase permite escolher Tranquilo ou Desafiador e pede confirmação antes de substituir a tentativa. A geração local roda fora da MainActor, mostra carregamento sem percentual inventado e oferece cancelamento. A partida atual permanece disponível se a geração for cancelada ou falhar; apenas um resultado atual substitui e salva a fase, com 3 vidas. Ao atingir o orçamento, usa uma reserva verificada do nível escolhido e informa isso na tela. Background e saída cancelam o pedido; respostas antigas são descartadas.

67 testes passando e build iOS aprovado. Testes cobrem persistência, dificuldade, reserva por orçamento esgotado, falha, cancelamento, background e respostas fora de ordem. Pendente: verificar responsividade, confirmação, cancelamento e retomada em iPhone.
