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

### Design review de 23/10/2026 · parte 2

Prioridade 6 do design review: progressão, regras temáticas, meta de coleção e dicas.

- **Mundos:** Praça das Flores 5×5 → Praia 6×6 + osso → Feira 8×8 + árvore → Parque 10×10 + gato → Lagoa 10×10 + poça, com 8 fases cada. Na primeira fase de cada lugar, a Margot apresenta a regra nova. Depois da última fase, a Lagoa recomeça com grades novas.
- **Regras:**
  - osso: o caminho passa por ele;
  - árvore: o caminho passa ao lado de cada uma (na vitória, a Margot faz uma "paradinha estratégica");
  - gato: o caminho não passa ao lado dele, e as casas vizinhas ficam rosadas;
  - poça: só em linha reta;
  - trechos pré-desenhados tracejados nas grades 8×8 e 10×10.

  Entrar ao lado do gato, virar na poça ou desviar de um trecho desenhado contam como erros visíveis.
- **Dificuldade como métrica:** o motor lógico rotula as técnicas por camada: 1 contagem, 2 continuação, 3 alcance e 4 regras temáticas. `LogicEngine.requiredTier` informa a camada mais simples que resolve a fase. Cada fase mira uma faixa de camadas (as primeiras 2, as do meio 2–3, as últimas 3–4); se nenhum candidato cair na faixa, o gerador usa o candidato verificado mais próximo. A ordem das deduções não mudou, então os desafios diários v1 continuam idênticos: conferido para os próximos 400 dias contra a `main`.
- **Gerador por mundo** (`WorldGenerator`): determinístico por fase, exige solução única (`ExactSolver`) e resolução só por lógica. O solver agora poda por alcance e por limites das pistas, e um teste o compara com força bruta em grades 4×4 com regras. Cada mundo tem 2 reservas certificadas. Calibração em macOS (Release): 36 de 40 fases saem do gerador, com até cerca de 0,5 s nas 10×10; as outras usam a reserva do mundo. Para reproduzir: `swift run -c release Calibration worlds`.
- **Dicas:** mostram primeiro um conflito nas marcações; se não houver, a dedução da camada mais simples, em frase curta (por exemplo: "Linha 2, coluna 3: a coluna 3 já está completa, então esta casa fica fora do caminho. Toque nela para marcar ×.").
- **Seu cantinho:** lugares alcançados e seu progresso; acessórios liberados por patinhas (lacinho 10, bandana 25, chapéu 50, óculos 100); álbum de polaroids, uma por passeio concluído, desenhadas a partir da rota salva.

Formatos: puzzle schema 2 (campos opcionais `bones`, `trees`, `cats`, `puddles`, `givenEdges`; grades até 10×10; os puzzles do schema 1 continuam iguais em disco) e save v6 (`progress`, `walks`, `accessory`).

**Fora deste PR:** o desafio diário continua com a política v1 (5×5, Tranquilo, sem regras temáticas). Mudar isso exige uma política `daily-v2`, para não trocar a fase de um dia já gerado.

Capturas: [Parque 10×10](docs/validation/design-review/park-10x10.png), [início com progressão](docs/validation/design-review/home-progress.png) e [Seu cantinho](docs/validation/design-review/corner.png). **Pendente no iPhone:** tempo de geração 10×10 no aparelho, gestos, álbum e VoiceOver das regras novas.

### Escolher a fase e casinha escondida

- **Qualquer fase, a qualquer hora:** em Seu cantinho, tocar num lugar abre as fases de 1 a 8, mesmo antes de chegar nele. A Lagoa 8/8 é a mais difícil. Jogar uma fase escolhida não muda o progresso; depois dela, "Próximo passeio" segue para a fase seguinte daquele lugar.
- **Casinha escondida** (opção no início, sugestão da namorada do Lucas): a casinha só aparece quando o caminho fecha. Para não entregar a posição dela, as pistas contam apenas o caminho e a casa escondida pode ser marcada com × como qualquer outra. O passeio termina quando todas as pistas e regras são atendidas. O gerador certifica que só um caminho a partir da Margot faz isso, e que ele termina na casinha. Um teste compara com força bruta em grades 4×4.
- **Calibração com a casinha escondida:** 38 de 40 fases saem do gerador; cada mundo tem 2 reservas escondidas certificadas. Para reproduzir: `swift run -c release Calibration worlds hidden`. O desafio diário continua com a casinha visível.

Capturas: [Lagoa 8/8 com a casinha escondida](docs/validation/design-review/hidden-house-pond.png), [início](docs/validation/design-review/home-hidden-toggle.png) e [escolha de lugar](docs/validation/design-review/corner-choose-level.png). **Pendente:** o seletor de fases e o surgimento da casinha não foram tocados no simulador.

### Passos definitivos, um único caminho certo e fases sempre novas

Decisão do Lucas depois de jogar a Lagoa 8/8. Ela substitui a regra do design review de "punir só o que é visível".

- **Passos só no caminho certo:** cada fase tem uma única solução certificada (`PuzzleSolution.route`). Um passo para fora dela é recusado e custa uma vida; no Tranquilo, conta só como erro para as patinhas. A parte certa do traço é mantida.
- **Sem desfazer:** o botão sumiu e voltar uma casa é ignorado. Marcar ✕ continua livre, e o tutorial agora ensina a limpar o ✕ tocando de novo.
- **Fases sempre novas:** cada vez que uma fase é jogada, a grade é gerada de novo com uma variação aleatória. "Outra fase" (no lugar de "Reiniciar"), "Tentar de novo" e "Jogar de novo" trazem outra grade do mesmo lugar. Por isso, reiniciar não devolve as vidas na mesma grade. O desafio do dia continua igual o dia todo, e reiniciá-lo recomeça a mesma grade.

[Captura da barra sem Desfazer](docs/validation/design-review/toolbar-no-undo.png).

### Quatro dificuldades, vidas sempre e gerador rápido

Ajustes do Lucas depois de jogar. Eles substituem mundos, regras temáticas, obstáculos e os modos Tranquilo/Desafiador.

- **Dificuldades:**

  | Nível | Grade | Casinha |
  |---|---|---|
  | Fácil | 5×5 | à vista |
  | Médio | 7×7 | escondida |
  | Difícil | 15×15 | escondida |
  | Especialista | 20×20 | escondida |

  Todos os níveis têm 3 vidas, inclusive o desafio do dia (política `daily-v2`: um Médio, igual o dia todo; os dias v1 já jogados continuam valendo na sequência).
- **Sem pista 0 e sem obstáculos:** o caminho passa por todas as linhas e colunas. O código das regras temáticas continua no núcleo, mas o gerador não as usa.
- **Toques:** qualquer toque numa casa fora do caminho certo custa uma vida, seja ao lado da ponta ou longe dela. Tocar e segurar marca ✕, sem custo.
- **"Outra fase":** pede confirmação num bottom sheet, com os botões "Trocar de fase" e "Continuar nesta".
- **Zoom:** nas grades 15×15 e 20×20, pinça para ampliar e dois dedos para arrastar; um dedo continua desenhando.
- **Gerador (`WalkGenerator`):**
  - **Rota:** sorteia uma rota que nunca encosta em si mesma e passa por todas as linhas e colunas.
  - **Unicidade:** se a lógica resolve a fase inteira, a solução é única, então a busca exaustiva é dispensada.
  - **Conserto:** onde a lógica trava, revela um trecho do caminho; no fim, remove os trechos revelados que não fazem falta.
  - **Técnicas novas** (camada 5, fora do padrão v1, para não mudar fases antigas): ligações obrigatórias em toda a grade e olhar um passo à frente na ponta.
  - **Tempos** (macOS, Release), mediana e máximo de 10 fases por nível:

    | Nível | Mediana | Máximo | Trechos revelados |
    |---|---|---|---|
    | Fácil | ~1 ms | ~4 ms | 0 |
    | Médio | ~1,5 ms | ~6 ms | 0–3 |
    | Difícil | ~0,1 s | ~0,2 s | cerca de 11 |
    | Especialista | ~0,8 s | ~1,1 s | cerca de 22 |

  - **Reservas:** quando falha (cerca de 2 em 10 no Especialista), usa uma reserva certificada.
  - **Preparo antecipado:** enquanto você joga, a próxima fase do mesmo nível já é gerada em segundo plano.
  - **Reproduzir:** `swift run -c release Calibration sizes`.

Capturas: [início](docs/validation/design-review/home-difficulties.png) e [Especialista 20×20](docs/validation/design-review/expert-20x20.png). **Pendente:** o zoom com pinça, os toques que custam vida e o bottom sheet não foram exercitados com toques reais. A geração no build Debug é cerca de 10 vezes mais lenta que no Release, e o preparo antecipado esconde isso a partir da segunda fase.
