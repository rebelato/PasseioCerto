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

### Chegada e conclusão (PC-016, em revisão)

Após vitória validada, Margot percorre em dois segundos os segmentos da rota congelada. A conclusão é salva antes da animação; pular, suspender ou reabrir não repete o registro. Reduzir Movimento mostra diretamente o estado de chegada. A conclusão oferece próxima fase, jogar novamente e voltar a uma tela inicial simples (a tela completa segue na PC-018). Desfazer fica indisponível após vitória; jogar novamente inicia uma tentativa limpa da mesma fase.

68 testes passaram e build iOS aprovado. [Estado final do tabuleiro](docs/validation/arrival-example.png) renderizado em SwiftUI no macOS. Pendente no iPhone: fluidez, pular, Reduce Motion, VoiceOver e navegação. A arte da Margot ainda é provisória (PC-022).

### Tutorial jogável (PC-017, em revisão)

Primeiro passeio usa uma grade fixa 3×3 e seis momentos: contagem incluindo endpoints, caminho ortogonal, ×, desfazer, dica real e chegada. Cada ação avança o checkpoint salvo. O exercício usa Game, HintProvider e o validador normal, sem alterar a tentativa ou registrar recompensas. Ao retornar a um checkpoint, o pequeno exercício é reconstruído; passos já concluídos não são repetidos.

Abre automaticamente enquanto não concluído/pulado; Continuar depois mantém o progresso, Pular vai ao passeio normal e Ajustes permite continuar ou repetir. Todos os passos funcionam por toque e ação de acessibilidade, sem exigir arraste; layout usa texto escalável e rolagem.

71 testes passaram e build iOS aprovado. [Primeiro passo renderizado em SwiftUI no macOS](docs/validation/tutorial-example.png). Pendente no iPhone: fluxo da apresentação, toque, foco VoiceOver e Dynamic Type.

### Início e desafio diário (PC-018, em revisão)

O app abre no início com Continuar (última tentativa ativa), Novo passeio, dificuldade Tranquilo/Desafiador, Desafio do dia e Ajustes. Dentro da partida, Início preserva o progresso. Novo passeio pede confirmação para substituir somente o passeio normal; os diários ficam guardados.

O diário usa calendário gregoriano **UTC**, independente do fuso do aparelho: chave `daily-v1-AAAA-MM-DD`, seed numérica AAAAMMDD e nível Tranquilo. A data aparece no início, atualizado a cada minuto; o dia muda à meia-noite UTC. Não há servidor nem dependência de rede. A política v1 deve ser mantida; alterações incompatíveis no gerador exigem nova versão da política diária.

Save v4 migra v3 e formatos antigos, guarda a tentativa ativa, o passeio normal e diários por ID. A grade completa, vidas, rota e histórico de um diário persistido são recuperados sem geração, mesmo após voltar o relógio ou atualizar o app. Abrir outro dia não troca a fase ativa automaticamente. Cancelar/falhar durante geração preserva a tentativa; o diário só passa a ativo quando pronto.

76 testes passaram e build iOS aprovado. Cobertura inclui fronteira UTC, offsets de fuso, migração v3, independência dos progressos, reabertura sem regenerar, mudança de data e falha de geração. Pendente no iPhone: layout do início, navegação, Dynamic Type/VoiceOver e retomada real.

### Personalização e progresso (PC-019, em revisão)

Ajustes permite editar o nome da cachorrinha. O padrão é Margot (substitui Bento do plano inicial, conforme decisão do usuário). Nomes são normalizados, limitados a 24 caracteres Unicode completos e preservam acentos/emojis; vazio retorna a Margot. O nome aparece no início, partida, conclusão, tutorial e rótulos do tabuleiro. Preferências antigas sem nome continuam compatíveis com save v4.

Seu cantinho reúne a companheira atual, a Praça das Flores e o total de passeios diferentes concluídos. A contagem usa IDs de fases já concluídas: repetir, retomar ou pular a animação não duplica; diário tem seu próprio ID. Não há moedas, novos animais ou desbloqueios fictícios.

80 testes passaram e build iOS aprovado. Testes de nomes longos, acentos, emoji composto, fallback, preferências antigas, persistência entre diário/normal e vitória idempotente. Pendente no iPhone: teclado, nomes longos com Dynamic Type, VoiceOver e revisão visual do cantinho.

### Sons, hápticos e regras (PC-020, em revisão)

Ajustes oferece controles independentes e persistentes de Sons e Feedback tátil, tutorial e consulta das regras. Eventos transitórios sinalizam ação confirmada, conflito com perda de vida e vitória; não são salvos nem reproduzidos ao restaurar. Um arraste gera no máximo um sinal; gesto cancelado e toque sem efeito não geram sinal. Desfazer válido usa o sinal de ação. Mensagens, pistas e vidas continuam sendo a fonte de informação com tudo desligado.

No iOS, tons PCM originais curtos e de baixo volume são reproduzidos sem sobreposição. A sessão usa [AVAudioSession ambient](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient), configurada para misturar com áudio externo e respeitar o modo silencioso. Sons param ao desativar a opção, abrir Ajustes, voltar ao início ou sair da atividade. Feedback tátil usa impacto suave, aviso e sucesso; ausência de hardware não impede jogar.

83 testes passaram e build iOS aprovado. Cobertura de eventos por gesto, cancelamento, conflito, vitória sem repetição, preferências restauradas e mensagens preservadas com opções desligadas. Pendente em iPhone: volume, vibração, silencioso, fones, interrupção por chamada, música externa, VoiceOver e interface dos ajustes.

### Acessibilidade e português (PC-021, em revisão)

VoiceOver recebe coordenadas, estado, contagens de linha/coluna, ponta atual e conexões reais da rota. Ações nomeadas permitem desenhar ou alternar × sem trocar a ferramenta; tabuleiro bloqueado fica somente para leitura. A leitura segue pistas de coluna e linhas em ordem. Fechar dica devolve foco ao botão Dica. A ferramenta selecionada tem checkmark além da cor.

Em tamanhos de acessibilidade, ferramentas ficam empilhadas e dificuldade usa menu. Botões permitem múltiplas linhas; células continuam com tamanho escalável e rolagem. Reduzir Movimento mantém o comportamento da PC-016.

O String Catalog `App/Localizable.xcstrings` tem português brasileiro, com língua-fonte `pt` compatível com o projeto existente. Mensagens do núcleo usam String(localized:). Para atualizar chaves, faça build com SWIFT_EMIT_LOC_STRINGS=YES e execute `python3 scripts/update-localizations.py <pasta Objects-normal/arm64>`. O script preserva traduções existentes.

86 testes passaram e build iOS aprovado, incluindo compilação do catálogo no bundle. [Claro](docs/validation/accessibility-light.png) e [escuro](docs/validation/accessibility-dark.png) foram renderizados no macOS em largura de 320 pt; não são capturas de iPhone. [Contrastes calculados](docs/validation/accessibility-contrast.json) verificam pares de cores explícitos do tema; não cobrem todas as cores dinâmicas do sistema.

**Pendente em iPhone pequeno/grande:** navegação completa por VoiceOver, foco de dica/vitória, Dynamic Type máximo, teclado/safe areas, rolagem do tabuleiro, Reduzir Movimento e interrupções. O simulador não pôde ser executado neste ambiente; build e snapshots estáticos não substituem essa revisão.

### Arte da Margot (PC-022, em revisão)

Retratos neutro, em passeio e feliz, casinha, arbusto e ícone em catálogo. Fonte vetorial original e exportação reproduzível; fotos pessoais não incluídas. [Arte e proveniência](docs/artwork.md).

Renderizações claras/escuras e PNGs revisados. Código iOS compila com catálogo excluído da checagem; build completo do catálogo bloqueado por CoreSimulator indisponível, inclusive na tentativa para dispositivo. Ainda precisa de build completo e revisão em iPhone.

### Integração contínua (PC-023)

GitHub Actions verifica testes do núcleo, build iOS completo com assets e instalação/abertura em simulador. Ambiente fixado em macOS 15, Xcode 26.3 e iOS 26.2, sem assinatura ou credenciais pessoais. [Comandos, limites e evidências](docs/ci.md).

### Design review de 23/10/2026 · parte 1

Aplicação das prioridades 1–5 do design review.

- **Sem mensagens de dev:** a fase de reserva é usada em silêncio. O balão da Margot só fala quando há algo a dizer: erro, dica ou vitória.
- **Desafio diário no fuso local:** vira à meia-noite do aparelho, com contagem regressiva ("Novo desafio em 3h 12min") e sequência de dias. O id `daily-v1-AAAA-MM-DD` não mudou.
- **Vidas:** só custam vida os erros visíveis: passar do número de uma pista, chegar à casinha cedo, pisar num arbusto ou cruzar o caminho. Becos sem saída ficam para a pessoa descobrir; o solver não é consultado. A casa e a pista culpadas piscam por 600 ms antes de a jogada ser desfeita. No Tranquilo não há vidas. Ao chegar, as vidas restantes viram de 1 a 3 patinhas, e o recorde por fase fica salvo.
- **Tela de jogo sem rolagem:** barra fina (← · nome e corações · ⚙), balão da Margot, a maior grade que couber e a barra Desfazer · Dica · Reiniciar. Arrastar, ou tocar na casa vizinha à ponta, desenha; tocar em outra casa (ou tocar e segurar) alterna ×. O caminho é cor de terra e os arbustos ficam sobre solo. Há haptic leve por casa desenhada e um "tic" quando uma pista é atendida.
- **Vitória:** a Margot anda, abana o rabo e entra na casinha, com o haptic de sucesso na chegada. Depois sobe um sheet com as patinhas e "Próximo passeio".
- **Início:** "Jogar" é o único botão preenchido, com o modo ao lado. Abaixo ficam o card do Desafio do dia e o resumo do cantinho. Nos Ajustes, o nome salva sozinho.

Formatos: tentativa v3 (`mode`, `mistakes`) e save v5 (`bestPaws`, `playMode`). Saves antigos migram: vidas v2 viram erros, e passeios já concluídos valem 1 patinha.

Capturas no simulador (iPhone 17 Pro, iOS 26.5): [início](docs/validation/design-review/home.png), [partida](docs/validation/design-review/game.png), [escuro](docs/validation/design-review/game-dark.png), [vitória](docs/validation/design-review/victory.png). Para abrir a partida direto: `xcrun simctl launch <id> com.rebelato.PasseioCerto -PCOpenWalk YES`. **Pendente:** arrastar, tocar, a animação de vitória e os hápticos não foram exercitados de forma automatizada; conferir no iPhone.
