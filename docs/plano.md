# Plano de desenvolvimento · Passeio Certo

Planejamento inicial em 22/10/2026. Backlog oficial no [Trello](https://trello.com/b/5ryzhOIc/passeio-certo). Repositório: [rebelato/PasseioCerto](https://github.com/rebelato/PasseioCerto).

## Objetivo e escopo do primeiro beta

Um puzzle tranquilo de pistas numéricas para iPhone. A pessoa desenha um caminho até a casa do Bento usando contagens de linhas e colunas. A recompensa é ver o cachorro percorrer a rota que ela deduziu.

- SwiftUI, um cachorro nomeável, uma praça e grades 5×5.
- Caminho ortogonal simples, marcações × e alternativa ao arraste por toque.
- Pistas, desfazer, reiniciar e dicas explicadas.
- Fases fixas primeiro; depois geração local com solução única E resolução por deduções verificadas.
- Dificuldade calibrada, catálogo de fallback, tutorial jogável e desafio diário.
- Progresso local, arte, sons/hápticos opcionais, acessibilidade e interface em português.
- Testes, playtest real com ela e TestFlight quando a conta Apple estiver disponível.

O MVP inclui 3 vidas por tentativa (planejadas em PC-012). Sem backend, chamadas de IA, anúncios ou economia virtual. A ilustração aprovada é referência visual, não um tabuleiro pronto para usar como imagem.

## Arquitetura proposta

- **PuzzleCore:** tipos de valor, regras, validação, solvers, deduções, geração, seed e dificuldade em Swift puro; testável sem UI.
- **GameFeature:** sessão, comandos de interação e telas em SwiftUI; somente apresentação/estado observável na MainActor.
- **DesignSystem:** tokens e componentes realmente usados.
- **Persistência local:** protocolo pequeno, formato versionado, escrita atômica e recuperação de erros. Escolher a implementação mais simples que cumpra PC-013.

A separação pode começar com pastas e um núcleo testável; não criar uma infraestrutura grande nem módulos vazios. Proposta de iOS mínimo: 17, a confirmar em PC-001. Sem bibliotecas de terceiros obrigatórias.

## Marcos e ordem recomendada

Os números identificam tarefas; **não são uma ordem linear obrigatória**.

| Marco | Resultado verificável | Tarefas |
| --- | --- | --- |
| M1 · Primeira partida | Abrir fase fixa, desenhar, marcar ×, desfazer, validar e ver Bento chegar em casa | [PC-001](https://trello.com/c/DTdqCQ67) → [PC-002](https://trello.com/c/jSJI6UTs) → [PC-003](https://trello.com/c/e7wbM5Ot) → [PC-004](https://trello.com/c/0APdSmtj) → [PC-009](https://trello.com/c/j97mpHNp) → [PC-010](https://trello.com/c/KExv7Ab7) → [PC-011](https://trello.com/c/BHFyMBT5) → [PC-012](https://trello.com/c/yW64AjLB) → [PC-016](https://trello.com/c/RQSxdrQ2) |
| M2 · Fases automáticas | Gerar fase única/dedutível, explicar dica, retomar e cancelar | [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc), [PC-007](https://trello.com/c/5bOYLHfH), [PC-008](https://trello.com/c/k1aXoXht), [PC-013](https://trello.com/c/ZQVqZB8x), [PC-014](https://trello.com/c/Woxa065h), [PC-015](https://trello.com/c/VFTALnFu) |
| M3 · Experiência pessoal | Tutorial, início/diário, nome, ajustes, arte e acessibilidade | [PC-017](https://trello.com/c/od9emsh1), [PC-018](https://trello.com/c/JWDEL6xZ), [PC-019](https://trello.com/c/a8bxpXkT), [PC-020](https://trello.com/c/gfNeyHwO), [PC-021](https://trello.com/c/zZvTLxaL), [PC-022](https://trello.com/c/pDZoW3Hv) |
| M4 · Beta no iPhone | Pipeline, testes integrados, playtest com ela e TestFlight | [PC-023](https://trello.com/c/X0nJpRsH) → [PC-024](https://trello.com/c/I3Z8JV5h) → [PC-025](https://trello.com/c/llcRNHJd) → [PC-026](https://trello.com/c/N3sm5MLT) |

CI pode começar quando o núcleo estiver disponível. Acessibilidade orienta a implementação desde o DesignSystem, antes da auditoria de PC-021.

## Organização do board

- **Referências:** “Comece aqui”, esboço, regras e este plano.
- **Pronto para começar:** dependências satisfeitas; inicialmente PC-001, PC-002 e PC-009.
- **Backlog MVP:** tarefas do primeiro beta, com dependências explícitas.
- **Em andamento:** trabalho iniciado; preferir um cartão ativo por desenvolvedor.
- **Em revisão:** implementação pronta para conferir código, comportamento e visual.
- **Concluído:** critérios verificados; planejamento não é implementação.
- **Pós-MVP:** ideias opcionais, sem bloquear o primeiro beta.

Não foram atribuídos responsáveis nem prazos. Não há estimativa de duração validada. Use IDs PC-xxx em branches/commits/PRs para ligar o trabalho ao cartão. Mova para “Pronto para começar” quando as dependências estiverem verificadas.

## Critério geral de pronto

- Código e UX cumprem o escopo; regras verificadas por testes relevantes.
- Interface conferida em dispositivo ou simulador quando necessário, incluindo erro e interrupção.
- Snapshots/referências visuais inspecionados antes de atualizar.
- README e decisões refletem o que existe; limitações e verificações pendentes declaradas.
- Nenhum dado pessoal, segredo, certificado ou token no repositório.

## Riscos a acompanhar

1. **Unicidade não prova dedutibilidade:** PC-005 e PC-006 fazem verificações distintas; ambas aprovam cada fase.
2. **Mesmas células podem ter conexões diferentes:** verificar arestas e rota, não só ocupação. Contato lateral é permitido, sem conexão automática.
3. **Busca pode crescer demais:** começar em 5×5, medir, limitar operações, cancelar e ter fallback. Grades maiores exigem validação própria.
4. **Determinismo inclui orçamento/fallback:** não usar hash aleatório nem mudar silenciosamente a grade de um ID por timeout/versão.
5. **Dificuldade percebida exige jogar:** métricas provisórias até o playtest; não inventar resultados.
6. **Raciocínio não é coordenação motora:** toque e ações acessíveis devem permitir as mesmas decisões do arraste.
7. **Conta Apple é dependência real:** beta entregue significa build instalada e aberta no iPhone, não apenas Archive gerado.

## Backlog resumido

| ID | Tarefa | Marco | Dependências |
| --- | --- | --- | --- |
| [PC-001](https://trello.com/c/DTdqCQ67) | Preparar o projeto iOS em SwiftUI | M1 | — |
| [PC-002](https://trello.com/c/jSJI6UTs) | Fechar as regras e criar fases de referência | M1 | — |
| [PC-003](https://trello.com/c/e7wbM5Ot) | Modelar puzzle, caminho e sessão em Swift puro | M1 | [PC-002](https://trello.com/c/jSJI6UTs) |
| [PC-004](https://trello.com/c/0APdSmtj) | Validar jogadas, contagens e vitória | M1 | [PC-003](https://trello.com/c/e7wbM5Ot) |
| [PC-005](https://trello.com/c/4DBUFk9s) | Implementar solver exato e prova de unicidade | M2 | [PC-004](https://trello.com/c/0APdSmtj) |
| [PC-006](https://trello.com/c/MLcANDlc) | Criar motor de deduções e justificativas | M2 | [PC-005](https://trello.com/c/4DBUFk9s) |
| [PC-007](https://trello.com/c/5bOYLHfH) | Gerar fases 5×5 com seed e validação dupla | M2 | [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc) |
| [PC-008](https://trello.com/c/k1aXoXht) | Calibrar dificuldade, desempenho e catálogo de fallback | M2 | [PC-007](https://trello.com/c/5bOYLHfH) |
| [PC-009](https://trello.com/c/j97mpHNp) | Criar o DesignSystem a partir do esboço aprovado | M1 | — |
| [PC-010](https://trello.com/c/KExv7Ab7) | Renderizar tabuleiro responsivo e pistas | M1 | [PC-003](https://trello.com/c/e7wbM5Ot), [PC-009](https://trello.com/c/j97mpHNp) |
| [PC-011](https://trello.com/c/BHFyMBT5) | Implementar desenho por arraste, toque e marcação × | M1 | [PC-004](https://trello.com/c/0APdSmtj), [PC-010](https://trello.com/c/KExv7Ab7) |
| [PC-012](https://trello.com/c/yW64AjLB) | Criar sessão de jogo com desfazer e reiniciar | M1 | [PC-011](https://trello.com/c/BHFyMBT5) |
| [PC-013](https://trello.com/c/ZQVqZB8x) | Persistir e restaurar partidas e preferências | M2 | [PC-003](https://trello.com/c/e7wbM5Ot), [PC-012](https://trello.com/c/yW64AjLB) |
| [PC-014](https://trello.com/c/Woxa065h) | Integrar contadores e dicas explicadas à tela de jogo | M2 | [PC-006](https://trello.com/c/MLcANDlc), [PC-012](https://trello.com/c/yW64AjLB) |
| [PC-015](https://trello.com/c/VFTALnFu) | Integrar geração assíncrona, cancelamento e fallback | M2 | [PC-008](https://trello.com/c/k1aXoXht), [PC-013](https://trello.com/c/ZQVqZB8x), [PC-014](https://trello.com/c/Woxa065h) |
| [PC-016](https://trello.com/c/RQSxdrQ2) | Animar a chegada do cachorro e registrar a conclusão | M1 | [PC-004](https://trello.com/c/0APdSmtj), [PC-012](https://trello.com/c/yW64AjLB) |
| [PC-017](https://trello.com/c/od9emsh1) | Criar tutorial curto e jogável | M3 | [PC-011](https://trello.com/c/BHFyMBT5), [PC-014](https://trello.com/c/Woxa065h), [PC-016](https://trello.com/c/RQSxdrQ2) |
| [PC-018](https://trello.com/c/JWDEL6xZ) | Criar início, escolha de dificuldade e desafio diário | M3 | [PC-013](https://trello.com/c/ZQVqZB8x), [PC-015](https://trello.com/c/VFTALnFu) |
| [PC-019](https://trello.com/c/a8bxpXkT) | Personalizar Bento e criar progresso mínimo | M3 | [PC-013](https://trello.com/c/ZQVqZB8x), [PC-016](https://trello.com/c/RQSxdrQ2) |
| [PC-020](https://trello.com/c/gfNeyHwO) | Adicionar ajustes, sons e hápticos discretos | M3 | [PC-012](https://trello.com/c/yW64AjLB), [PC-016](https://trello.com/c/RQSxdrQ2) |
| [PC-021](https://trello.com/c/zZvTLxaL) | Revisar acessibilidade, português e conforto visual | M3 | [PC-010](https://trello.com/c/KExv7Ab7), [PC-011](https://trello.com/c/BHFyMBT5), [PC-014](https://trello.com/c/Woxa065h), [PC-017](https://trello.com/c/od9emsh1), [PC-018](https://trello.com/c/JWDEL6xZ) |
| [PC-022](https://trello.com/c/pDZoW3Hv) | Finalizar arte, ícone e animações do Bento | M3 | [PC-009](https://trello.com/c/j97mpHNp), [PC-016](https://trello.com/c/RQSxdrQ2), [PC-019](https://trello.com/c/a8bxpXkT) |
| [PC-023](https://trello.com/c/X0nJpRsH) | Configurar CI e verificações reproduzíveis | M4 | [PC-001](https://trello.com/c/DTdqCQ67), [PC-004](https://trello.com/c/0APdSmtj), [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc) |
| [PC-024](https://trello.com/c/I3Z8JV5h) | Validar o MVP integrado e desempenho no aparelho | M4 | [PC-015](https://trello.com/c/VFTALnFu), [PC-017](https://trello.com/c/od9emsh1), [PC-018](https://trello.com/c/JWDEL6xZ), [PC-020](https://trello.com/c/gfNeyHwO), [PC-021](https://trello.com/c/zZvTLxaL), [PC-022](https://trello.com/c/pDZoW3Hv), [PC-023](https://trello.com/c/X0nJpRsH) |
| [PC-025](https://trello.com/c/llcRNHJd) | Fazer uma rodada de playtest com ela e ajustar o desafio | M4 | [PC-024](https://trello.com/c/I3Z8JV5h) |
| [PC-026](https://trello.com/c/N3sm5MLT) | Preparar assinatura e distribuir beta no TestFlight | M4 | [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-027](https://trello.com/c/sR9QSUBn) | Explorar grades 6×6/7×7 e novas dificuldades | Pós-MVP | [PC-008](https://trello.com/c/k1aXoXht), [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-028](https://trello.com/c/CzcPwvG6) | Expandir animais, coleção e cenários | Pós-MVP | [PC-019](https://trello.com/c/a8bxpXkT), [PC-022](https://trello.com/c/pDZoW3Hv), [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-029](https://trello.com/c/nMGy1gmE) | Projetar fases com mais de um animal | Pós-MVP | [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc), [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-030](https://trello.com/c/dF2WPu8T) | Explorar um modo de matemática ou palavras | Pós-MVP | [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-031](https://trello.com/c/cQMMOpxc) | Avaliar sincronização iCloud entre aparelhos | Pós-MVP | [PC-013](https://trello.com/c/ZQVqZB8x), [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-032](https://trello.com/c/WUKePV2S) | Adicionar inglês e revisar localização completa | Pós-MVP | [PC-021](https://trello.com/c/zZvTLxaL), [PC-025](https://trello.com/c/llcRNHJd) |
| [PC-033](https://trello.com/c/55a3aEQ9) | Avaliar publicação pública na App Store | Pós-MVP | [PC-026](https://trello.com/c/N3sm5MLT) |

## Critérios de aceite por tarefa

### PC-001 · Preparar o projeto iOS em SwiftUI

[Cartão no Trello](https://trello.com/c/DTdqCQ67) · Base · M1 · Primeira partida

Criar um app nativo pequeno, com domínio independente da interface, sem backend ou IA no runtime.

Dependências: nenhuma.

- [ ] Projeto abre no Xcode e executa em simulador de iPhone; definir iOS mínimo (proposta: iOS 17) e orientação retrato.
- [ ] Separar PuzzleCore (Swift puro), GameFeature (sessão/SwiftUI), DesignSystem e persistência, sem criar módulos vazios sem uso.
- [ ] Previews e testes usam fases locais determinísticas; não exigem rede, credenciais nem serviços externos.
- [ ] README informa Xcode/SDK efetivamente usados, comando de build/teste, bundle ID e passos de assinatura no aparelho.

### PC-002 · Fechar as regras e criar fases de referência

[Cartão no Trello](https://trello.com/c/jSJI6UTs) · Produto / Regras · M1 · Primeira partida

Transformar o conceito aprovado em uma especificação testável antes de implementar o gerador.

Dependências: nenhuma.

- [ ] Uma grade 5×5, um cachorro e uma casa distintos; movimento ortogonal sem repetir células; não é necessário preencher toda a grade.
- [ ] Partida e chegada contam nas pistas; documentar caminho parcial, célula com ×, obstáculos e momento da vitória.
- [ ] Trechos não consecutivos podem ficar lado a lado, mas só se conectam por arestas desenhadas; não há conexão automática pela cor das células.
- [ ] Definir como marcar casa/partida, apagar o último trecho, encerrar um gesto e lidar com pistas satisfeitas sem revelar gabarito.
- [ ] Conjunto de fixtures inclui o esboço aprovado (linhas 3,1,3,1,1 e colunas 1,1,3,1,3), mais casos válidos, impossíveis e ambíguos; confirmar classificações com solver quando disponível.

### PC-003 · Modelar puzzle, caminho e sessão em Swift puro

[Cartão no Trello](https://trello.com/c/e7wbM5Ot) · Núcleo · M1 · Primeira partida

Definir tipos de valor serializáveis que possam ser testados sem SwiftUI.

Dependências: [PC-002](https://trello.com/c/jSJI6UTs).

- [ ] Tipos para coordenada, dimensões, obstáculos, endpoints, pistas de linhas/colunas e rota ordenada com suas conexões explícitas.
- [ ] Separar a definição imutável da fase do caminho/×/histórico do jogador; início e fim são informações conhecidas desde o começo.
- [ ] Formato Codable com puzzleID, schemaVersion, generatorVersion e seed quando aplicável; rejeitar dados fora dos limites.
- [ ] Fixtures disponíveis para previews, testes e tutorial; regras não dependem de cores, pixels ou da ilustração.

### PC-004 · Validar jogadas, contagens e vitória

[Cartão no Trello](https://trello.com/c/0APdSmtj) · Núcleo · M1 · Primeira partida

Aceitar vitórias pelo cumprimento das regras, e não por comparação com uma imagem ou solução guardada.

Dependências: [PC-003](https://trello.com/c/e7wbM5Ot).

- [ ] Validar limites, obstáculos, adjacência ortogonal, repetição, continuidade cão→casa e todas as contagens, incluindo endpoints.
- [ ] Diferenciar incompleto, contradição comprovada e solução completa; não chamar um prefixo de errado apenas por divergir do gabarito.
- [ ] Contagem da ocupação conhecida inclui endpoints uma única vez; distinguir o endpoint isolado da rota conectada.
- [ ] Testes cobrem rota desconectada, ciclos, extremos, pista excedida, soma incompatível e diferentes conexões com as mesmas células.

### PC-005 · Implementar solver exato e prova de unicidade

[Cartão no Trello](https://trello.com/c/4DBUFk9s) · Núcleo · M2 · Fases automáticas

Contar soluções reais até duas e produzir uma referência confiável para validar o gerador.

Dependências: [PC-004](https://trello.com/c/0APdSmtj).

- [ ] API retorna sem solução, solução única ou múltiplas; pode interromper após encontrar a segunda.
- [ ] Unicidade considera a rota/arestas, não apenas o conjunto de células; ordem é fixada a partir do cão, sem duplicar a rota invertida.
- [ ] Aceitar restrições do estado atual para consultar existência de continuação, sem usar solução conhecida como oráculo de erro.
- [ ] Comparar resultados em grades pequenas com enumeração independente; cobrir fixtures de PC-002.
- [ ] Busca cancelável com limites de operações/nós; atingir o limite retorna indeterminado, nunca aprova unicidade.

### PC-006 · Criar motor de deduções e justificativas

[Cartão no Trello](https://trello.com/c/MLcANDlc) · Núcleo · M2 · Fases automáticas

Resolver e explicar o puzzle por regras lógicas, sem adivinhar ou consultar a resposta pronta.

Dependências: [PC-005](https://trello.com/c/4DBUFk9s).

- [ ] Implementar regras sólidas de pista completa, casas restantes obrigatórias, conectividade e continuidade; registrar células, pistas e motivo de cada dedução.
- [ ] Distinguir fato deduzido, marcação do jogador e segmento conectado; uma célula obrigatória distante pode ser destacada sem desenhar uma conexão fictícia.
- [ ] Confrontar deduções com todas as soluções compatíveis nas fixtures: nenhuma regra elimina uma solução válida.
- [ ] Quando não houver dedução suportada, retornar isso explicitamente; não apresentar resultado de backtracking como uma explicação lógica.
- [ ] Estado contraditório não gera uma dica inventada: explicar o conflito comprovável ou orientar revisão/desfazer.

### PC-007 · Gerar fases 5×5 com seed e validação dupla

[Cartão no Trello](https://trello.com/c/5bOYLHfH) · Núcleo · M2 · Fases automáticas

Gerar fases automaticamente no aparelho com garantias explícitas de qualidade.

Dependências: [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc).

- [ ] Criar caminho candidato, endpoints, pistas e obstáculos; só publicar após unicidade exata e resolução integral pelo repertório lógico.
- [ ] Seed e versão produzem a mesma fase entre execuções; usar PRNG/hash estáveis, nunca hashValue/Hasher do Swift para identidade.
- [ ] Limitar candidatos e operações, suportar cancelamento e descartar resultados de pedidos antigos.
- [ ] Ao esgotar o orçamento, usar fase previamente validada com identidade própria; não atribuir duas grades ao mesmo puzzleID.
- [ ] Corpus automatizado registra taxa de aceitação/rejeição e inclui casos patológicos; nenhuma fase é aceita quando o solver fica indeterminado.

### PC-008 · Calibrar dificuldade, desempenho e catálogo de fallback

[Cartão no Trello](https://trello.com/c/k1aXoXht) · Núcleo / Qualidade · M2 · Fases automáticas

Definir níveis de desafio usando deduções e validar que o gerador funciona de forma confortável no iPhone.

Dependências: [PC-007](https://trello.com/c/5bOYLHfH).

- [ ] Classificar inicialmente Tranquilo e Desafiador conforme regras, cadeias e passos lógicos; dificuldade por tamanho não é suficiente.
- [ ] Revisar jogando uma amostra identificável por seed/versão; tratar os limites iniciais como provisórios.
- [ ] Medir tempo, memória, nós e taxa de rejeição em hardware disponível, registrando dispositivo e build; definir limites com base nas medições.
- [ ] Preparar catálogo pequeno de fases verificadas por dificuldade para uso offline; carregamento e geração ficam fora da MainActor.
- [ ] Grades maiores ficam desabilitadas até terem validação própria.

### PC-009 · Criar o DesignSystem a partir do esboço aprovado

[Cartão no Trello](https://trello.com/c/j97mpHNp) · Design · M1 · Primeira partida

Traduzir o conceito em componentes SwiftUI legíveis e reutilizáveis, sem transformar a imagem em interface.

Dependências: nenhuma.

- [ ] Paleta marfim/sálvia/verde-escuro, escala tipográfica com Dynamic Type, espaçamentos, cantos, ícones e estados definidos em tokens.
- [ ] Componentes para pistas, ferramentas Caminho/Marcar ×, Desfazer, Dica e notas explicativas.
- [ ] Definir aparência de cão, casa, obstáculo, célula livre, descartada, caminho e pista atendida/excedida; informação não depende apenas de cor.
- [ ] Revisar contraste e composição em iPhone pequeno; tabuleiro tem prioridade sobre decoração.
- [ ] Registrar o mockup como referência visual; texto, pistas e grade são renderizados por código.

### PC-010 · Renderizar tabuleiro responsivo e pistas

[Cartão no Trello](https://trello.com/c/KExv7Ab7) · SwiftUI · M1 · Primeira partida

Desenhar uma fase real, com conexões precisas e alinhamento consistente das pistas.

Dependências: [PC-003](https://trello.com/c/e7wbM5Ot), [PC-009](https://trello.com/c/j97mpHNp).

- [ ] Grade 5×5 com pistas alinhadas a cada linha/coluna, cão e casa nas coordenadas corretas.
- [ ] Desenhar ligações entre centros, sem unir automaticamente trechos apenas adjacentes; evitar cobrir números com arte.
- [ ] Estados do tabuleiro consomem modelos do núcleo; fixtures incluem o caminho parcial do conceito.
- [ ] Safe areas, controles inferiores e rolagem respeitados; conteúdo não passa sob relógio ou botões.
- [ ] Cada célula tem identificação estável e descrição acessível de posição e estado.

### PC-011 · Implementar desenho por arraste, toque e marcação ×

[Cartão no Trello](https://trello.com/c/BHFyMBT5) · SwiftUI / Interação · M1 · Primeira partida

Permitir resolver o puzzle sem exigir precisão motora nem gestos ocultos.

Dependências: [PC-004](https://trello.com/c/0APdSmtj), [PC-010](https://trello.com/c/KExv7Ab7).

- [ ] Arrastar estende um prefixo conectado ao cão; recuar sobre o último segmento desfaz o trecho correspondente.
- [ ] Toque em célula vizinha é alternativa ao arraste; modo Marcar × permite marcar/desmarcar exclusões sem desenhar conexões.
- [ ] Células de partida/casa não podem ser descartadas; rota e × não ocupam a mesma célula sem uma resolução de conflito explícita.
- [ ] Tratar saída da grade, movimento rápido/diagonal, interrupção e cancelamento do gesto sem criar saltos ou estado corrompido.
- [ ] Acessibilidade oferece ações equivalentes sem arrastar; mudanças de ferramenta têm rótulo e estado selecionado claros.

### PC-012 · Criar sessão de jogo com desfazer e reiniciar

[Cartão no Trello](https://trello.com/c/yW64AjLB) · Sessão · M1 · Primeira partida

Consolidar ações em um GameViewModel previsível, independente da animação e da persistência.

Dependências: [PC-011](https://trello.com/c/BHFyMBT5), [PC-005](https://trello.com/c/4DBUFk9s).

- [ ] Um gesto finalizado ou uma ação por toque corresponde a uma transação de histórico; desfazer restaura caminho e marcações.
- [ ] Reiniciar pede confirmação e não altera o puzzleID; troca de fase não mistura históricos.
- [ ] Contagens são derivadas do estado atual e do modelo, nunca de variáveis duplicadas na View.
- [ ] Teste partida fixa completa com desenhar, descartar, desfazer, reiniciar e ganhar.
- [ ] Cada tentativa começa com 3 vidas, exibidas como corações e com rótulo acessível.
- [ ] Perder 1 vida ao confirmar extensão ortogonal que excede uma pista, chega à casa sem cumprir as pistas ou torna impossível concluir a rota. Para este último caso, o solver deve comprovar continuação antes da jogada e ausência dela depois, ignorando marcações ×; indeterminado/cancelado nunca desconta vida.
- [ ] Uma ação por toque ou gesto inteiro desconta no máximo 1 vida e reverte o caminho ao estado anterior em caso de erro; eventos repetidos do arraste não descontam novamente. Diagonal, salto, toque fora, obstáculo, ferramenta ×, desfazer e gesto cancelado não descontam vidas.
- [ ] Desfazer não recupera vidas perdidas. Ao zerar, bloquear novas jogadas e oferecer Tentar novamente: mesma fase, caminho/×/histórico limpos e 3 vidas, sem espera, anúncio ou pagamento. Reinício manual pede confirmação.
- [ ] Persistir vidas, estado de derrota e versão da sessão junto da partida; reabrir não restaura vidas. Migrar sessões antigas para 3 vidas. Integrar com PC-013.
- [ ] Tutorial PC-017 explica quais erros custam vida; feedback textual e acessível acompanha os corações. Testar débito único, derrota, reinício, restauração, consulta indeterminada e retorno assíncrono obsoleto.
- [ ] Validar fora da MainActor; enquanto houver consulta pendente, não aceitar nova jogada. Resultados antigos/cancelados após reinício ou troca de fase não podem descontar vidas.

### PC-013 · Persistir e restaurar partidas e preferências

[Cartão no Trello](https://trello.com/c/ZQVqZB8x) · Dados locais · M2 · Fases automáticas

Manter o progresso offline e sobreviver a interrupções do iPhone.

Dependências: [PC-003](https://trello.com/c/e7wbM5Ot), [PC-012](https://trello.com/c/yW64AjLB).

- [ ] Salvar fase, rota, ×, posição no tutorial, preferências e progresso em formato versionado e com escrita atômica.
- [ ] Restaurar partida sem gerar outra grade para a mesma identidade, inclusive após encerramento/reabertura.
- [ ] Dados corrompidos ou incompatíveis oferecem recuperação explícita, sem apagar silenciosamente progresso válido.
- [ ] Salvar em momentos seguros e na mudança de scenePhase; navegação e efeitos não duplicam vitórias.
- [ ] Testes de round-trip, versão incompatível, falha de escrita e interrupção durante salvamento.

### PC-014 · Integrar contadores e dicas explicadas à tela de jogo

[Cartão no Trello](https://trello.com/c/Woxa065h) · SwiftUI / Lógica · M2 · Fases automáticas

Fazer o feedback ajudar no raciocínio sem revelar automaticamente a solução.

Dependências: [PC-006](https://trello.com/c/MLcANDlc), [PC-012](https://trello.com/c/yW64AjLB).

- [ ] Pistas exibem pendente, atendida ou excedida com distinção de símbolo/texto; atendida não significa caminho globalmente correto.
- [ ] Botão Dica mostra uma dedução real com linha/coluna/células destacadas e linguagem curta em português.
- [ ] Dicas respeitam o estado atual, × e conexões; conflito comprovado tem mensagem própria.
- [ ] Dica não aplica silenciosamente movimentos nem usa o gabarito para afirmar que uma célula está errada.
- [ ] Explicação, destaque e ações são acessíveis e podem ser fechados sem alterar a partida.

### PC-015 · Integrar geração assíncrona, cancelamento e fallback

[Cartão no Trello](https://trello.com/c/VFTALnFu) · Integração · M2 · Fases automáticas

Conectar o motor de geração à experiência do jogo sem bloquear a interface.

Dependências: [PC-008](https://trello.com/c/k1aXoXht), [PC-013](https://trello.com/c/ZQVqZB8x), [PC-014](https://trello.com/c/Woxa065h).

- [ ] Nova fase usa gerador local e a dificuldade escolhida; UI permanece responsiva.
- [ ] Carregamento mostra andamento verdadeiro quando houver dados; oferece cancelar e não inventa percentuais.
- [ ] Token/identidade da sessão impede resposta antiga de substituir uma fase nova; cancelar ao sair ou trocar pedido.
- [ ] Fallback é validado, preserva identidade e informa indisponibilidade de geração quando relevante.
- [ ] Testar erros, orçamento excedido, cancelamento, background e troca rápida de fases sem chamadas de rede.

### PC-016 · Animar a chegada do cachorro e registrar a conclusão

[Cartão no Trello](https://trello.com/c/RQSxdrQ2) · SwiftUI / Recompensa · M1 · Primeira partida

Entregar o momento afetivo do conceito, acionado apenas por uma solução válida.

Dependências: [PC-004](https://trello.com/c/0APdSmtj), [PC-012](https://trello.com/c/yW64AjLB).

- [ ] Após validação completa, congelar a rota e animar o cão por seus segmentos até a casa.
- [ ] Conclusão oferece próxima fase, jogar novamente e voltar ao início; uma animação não controla a validade da vitória.
- [ ] Registrar a vitória uma única vez mesmo com taps repetidos, reaparecimento da View ou interrupção.
- [ ] Reduce Motion usa transição simples; o jogador pode pular a animação.
- [ ] Retomar após background não duplica recompensas nem deixa a tela travada.

### PC-017 · Criar tutorial curto e jogável

[Cartão no Trello](https://trello.com/c/od9emsh1) · Produto / SwiftUI · M3 · Experiência pessoal

Ensinar jogando, sem um onboarding de slides longo.

Dependências: [PC-011](https://trello.com/c/BHFyMBT5), [PC-014](https://trello.com/c/Woxa065h), [PC-016](https://trello.com/c/RQSxdrQ2).

- [ ] Pequenas fases fixas ensinam contagens incluindo endpoints, caminho ortogonal, ×, desfazer e dica.
- [ ] Uma ação e uma explicação curta por momento; a pessoa executa a regra antes de avançar.
- [ ] Pode pular, repetir e reabrir em Ajustes; progresso salvo.
- [ ] Não exige arrastar nem ignora Dynamic Type/VoiceOver.
- [ ] Ao terminar, abre uma partida normal e não mistura regras especiais do tutorial com o validador real.

### PC-018 · Criar início, escolha de dificuldade e desafio diário

[Cartão no Trello](https://trello.com/c/JWDEL6xZ) · Produto / SwiftUI · M3 · Experiência pessoal

Dar um ponto de entrada simples para jogar e continuar sem menus excessivos.

Dependências: [PC-013](https://trello.com/c/ZQVqZB8x), [PC-015](https://trello.com/c/VFTALnFu).

- [ ] Tela inicial oferece Continuar, Novo passeio e Desafio do dia; o caminho até a partida é curto.
- [ ] Dificuldades vêm da classificação real; não apresentar opção que o gerador/catálogo ainda não suporta.
- [ ] Diário tem chave estável de data civil e versão, com política de fuso documentada; nunca sobrescreve uma partida aberta.
- [ ] Mudança do relógio/data ou atualização não substitui grade já persistida sob o mesmo ID.
- [ ] Tudo funciona offline; um puzzle diário tem identidade única e pode ser retomado.

### PC-019 · Personalizar Bento e criar progresso mínimo

[Cartão no Trello](https://trello.com/c/a8bxpXkT) · Produto / Dados · M3 · Experiência pessoal

Tornar o jogo dela sem criar uma administração de abrigo ou economia paralela.

Dependências: [PC-013](https://trello.com/c/ZQVqZB8x), [PC-016](https://trello.com/c/RQSxdrQ2).

- [ ] Permitir nomear o cachorro, com fallback Bento; nome aparece no início, na partida e na conclusão.
- [ ] Persistir nome e preferências; testar nomes longos, caracteres especiais e acessibilidade.
- [ ] Mostrar contagem de passeios concluídos e uma pequena coleção preparada para expansão, sem inventar desbloqueios não implementados.
- [ ] Vitórias/recompensas são idempotentes por partida; repetir fase não gera duplicação acidental.
- [ ] Primeiro marco usa um cachorro e uma praça; coleção extensa fica para pós-MVP.

### PC-020 · Adicionar ajustes, sons e hápticos discretos

[Cartão no Trello](https://trello.com/c/gfNeyHwO) · Experiência · M3 · Experiência pessoal

Oferecer resposta tátil/sonora opcional sem atrapalhar a dedução.

Dependências: [PC-012](https://trello.com/c/yW64AjLB), [PC-016](https://trello.com/c/RQSxdrQ2).

- [ ] Ajustes de som e hápticos persistem e podem ser alterados sem sair/perder a partida.
- [ ] Sinais discretos para ação válida, conflito de regra e conclusão; sem latido repetitivo obrigatório.
- [ ] Não interromper áudio de outros apps sem intenção explícita; respeitar comportamento esperado do aparelho.
- [ ] Ajustes permitem reabrir tutorial e consultar regras.
- [ ] Ausência de som/háptico não remove informação necessária para resolver ou entender o jogo.

### PC-021 · Revisar acessibilidade, português e conforto visual

[Cartão no Trello](https://trello.com/c/zZvTLxaL) · Qualidade / Acessibilidade · M3 · Experiência pessoal

Consolidar requisitos acessíveis presentes desde o tabuleiro, não remendar só no lançamento.

Dependências: [PC-010](https://trello.com/c/KExv7Ab7), [PC-011](https://trello.com/c/BHFyMBT5), [PC-014](https://trello.com/c/Woxa065h), [PC-017](https://trello.com/c/od9emsh1), [PC-018](https://trello.com/c/JWDEL6xZ).

- [ ] VoiceOver anuncia coordenada, estado, pistas e ações equivalentes para desenho/exclusão; foco previsível em dica e vitória.
- [ ] Texto ampliado, contraste, modo de marcação e alvos de toque são verificados em iPhone pequeno/grande; não depender só de cor.
- [ ] Reduce Motion e interrupções não quebram conclusão nem navegação; tabuleiro mantém prioridade e legibilidade.
- [ ] Interface completa em pt-BR com String Catalog e unidades/textos consistentes; preparar localização sem forçar idiomas novos no MVP.
- [ ] Revisar safe areas e evitar informação escondida por barras, teclado, notas ou botões fixos.

### PC-022 · Finalizar arte, ícone e animações do Bento

[Cartão no Trello](https://trello.com/c/pDZoW3Hv) · Design / Assets · M3 · Experiência pessoal

Trocar arte provisória por um conjunto pequeno coerente com o conceito aprovado.

Dependências: [PC-009](https://trello.com/c/j97mpHNp), [PC-016](https://trello.com/c/RQSxdrQ2), [PC-019](https://trello.com/c/a8bxpXkT).

- [ ] Cão, casa, praça/obstáculo e ícone final em formatos/resoluções adequados ao iPhone, com proveniência documentada.
- [ ] Estados necessários à caminhada e à chegada definidos; arte não cobre pistas, células ou conexões.
- [ ] Telas continuam legíveis com animação reduzida e símbolos substitutos; nenhuma regra depende da anatomia/pose de uma imagem.
- [ ] Assets organizados no catálogo e usados por componentes; não embutir a imagem inteira do mockup como tela.
- [ ] Revisar em tamanho real de dispositivo; nomes e textos permanecem nativos/localizáveis.

### PC-023 · Configurar CI e verificações reproduzíveis

[Cartão no Trello](https://trello.com/c/X0nJpRsH) · Engenharia · M4 · Beta no iPhone

Garantir que mudanças de UI ou gerador não quebrem regras e builds sem ser percebidas.

Dependências: [PC-001](https://trello.com/c/DTdqCQ67), [PC-004](https://trello.com/c/0APdSmtj), [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc).

- [ ] Workflow GitHub Actions executa testes do núcleo e build/testes iOS compatíveis com runner e SDK fixados/documentados.
- [ ] CI inclui fixtures de unicidade, deduções e seeds de regressão; falhas não são contornadas desativando testes.
- [ ] Build de verificação sem assinatura e sem credenciais pessoais; segredos de distribuição separados se forem necessários depois.
- [ ] README explica como reproduzir os checks localmente e quais dependem de simulador/hardware.
- [ ] Executar o pipeline real e registrar resultado antes de marcar concluído; especificar limites do corpus para manter custo previsível.

### PC-024 · Validar o MVP integrado e desempenho no aparelho

[Cartão no Trello](https://trello.com/c/I3Z8JV5h) · Qualidade · M4 · Beta no iPhone

Verificar a experiência completa com os dados, solver e UI reais.

Dependências: [PC-015](https://trello.com/c/VFTALnFu), [PC-017](https://trello.com/c/od9emsh1), [PC-018](https://trello.com/c/JWDEL6xZ), [PC-020](https://trello.com/c/gfNeyHwO), [PC-021](https://trello.com/c/zZvTLxaL), [PC-022](https://trello.com/c/pDZoW3Hv), [PC-023](https://trello.com/c/X0nJpRsH).

- [ ] Cobrir início→tutorial→fase→dica→desfazer→retomar→vitória e diário, incluindo app encerrado/background durante geração ou animação.
- [ ] Revisão visual em iPhone pequeno/grande, texto ampliado e configurações acessíveis; screenshots/snapshots só atualizados após inspeção.
- [ ] Lote reproduzível de fases confirma validade, unicidade, conclusão lógica e classificação; registrar seeds que falharem.
- [ ] Medir geração e fluidez no hardware disponível, registrar resultados e corrigir gargalos materiais.
- [ ] Checklist de privacidade e funcionamento offline corresponde ao código; não adicionar analytics, anúncios ou coleta sem decisão de produto.

### PC-025 · Fazer uma rodada de playtest com ela e ajustar o desafio

[Cartão no Trello](https://trello.com/c/llcRNHJd) · Produto / Validação · M4 · Beta no iPhone

Confirmar que as regras são entendidas e que ela quer jogar a próxima fase.

Dependências: [PC-024](https://trello.com/c/I3Z8JV5h).

- [ ] Preparar pequena sequência de fases fáceis/intermediárias identificadas por seed e observações, sem coletar dados pessoais automaticamente.
- [ ] Observar compreensão de endpoints, contagens, × e caminho por toque/arraste; registrar onde precisou de explicação.
- [ ] Checar se a classificação corresponde à percepção e se as dicas ensinam sem estragar a descoberta.
- [ ] Transformar problemas observados em ajustes/correções verificáveis; priorizar clareza e prazer do puzzle.
- [ ] Playtest é etapa humana: não inventar resultados nem marcar aprovado sem a sessão real.

### PC-026 · Preparar assinatura e distribuir beta no TestFlight

[Cartão no Trello](https://trello.com/c/N3sm5MLT) · Distribuição · M4 · Beta no iPhone

Instalar a primeira versão nela pelo caminho oficial de beta, usando a conta Apple do projeto.

Dependências: [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Confirmar equipe Apple Developer, bundle ID, capabilities, nome, ícone, versões e idiomas efetivamente disponíveis.
- [ ] Archive Release e validação no App Store Connect bem-sucedidos; configurações de privacidade/exportação refletem o código.
- [ ] Definir beta interno/externo conforme a conta, com textos de teste e revisão da Apple quando exigida.
- [ ] Upload e convite só com acesso/autorização efetivos; não compartilhar senhas ou certificados no repo.
- [ ] Confirmar instalação e abertura no iPhone dela e registrar a build; instruções de renovação do beta documentadas.

### PC-027 · Explorar grades 6×6/7×7 e novas dificuldades

[Cartão no Trello](https://trello.com/c/sR9QSUBn) · Pós-MVP · Depois do primeiro beta

Expandir apenas quando o gerador e a interação pequenos estiverem validados.

Dependências: [PC-008](https://trello.com/c/k1aXoXht), [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Medir custo e taxa de aceitação para cada tamanho, sem inferir desempenho a partir de 5×5.
- [ ] Garantir unicidade de rota e conclusão lógica pelo repertório suportado.
- [ ] Validar toque, leitura e acessibilidade em tela pequena antes de liberar.
- [ ] Atualizar catálogo/fallback e classificador com corpus revisado.

### PC-028 · Expandir animais, coleção e cenários

[Cartão no Trello](https://trello.com/c/CzcPwvG6) · Pós-MVP · Depois do primeiro beta

Adicionar cachorros e depois outros bichos como variações afetivas, mantendo regras claras.

Dependências: [PC-019](https://trello.com/c/a8bxpXkT), [PC-022](https://trello.com/c/pDZoW3Hv), [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Definir espécies/visuais e ambientes a partir do que ela gostar no playtest.
- [ ] Desbloqueios têm condição explícita e salvamento versionado.
- [ ] Arte nova preserva leitura de coordenadas, endpoints e caminho.
- [ ] Evitar transformar a coleção em manutenção obrigatória ou punição por ficar sem jogar.

### PC-029 · Projetar fases com mais de um animal

[Cartão no Trello](https://trello.com/c/nMGy1gmE) · Pós-MVP · Experimento de regras

Tratar como uma variante real do puzzle, com custo e regras próprios.

Dependências: [PC-005](https://trello.com/c/4DBUFk9s), [PC-006](https://trello.com/c/MLcANDlc), [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Especificar pareamento animal–destino, contagem agregada e restrições de cruzamento/compartilhamento.
- [ ] Atualizar validador, solver exato e motor lógico; unicidade deve incluir cada rota e pareamento.
- [ ] Cores têm símbolos/nome como alternativa; interface mostra claramente qual animal está sendo movido.
- [ ] Validar diversão e geração antes de integrar à progressão normal.

### PC-030 · Explorar um modo de matemática ou palavras

[Cartão no Trello](https://trello.com/c/dF2WPu8T) · Pós-MVP · Experimento de produto

Investigar o interesse por outras mecânicas sem diluir a experiência principal.

Dependências: [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Escolher uma única hipótese para prototipar a partir do feedback dela: pistas aritméticas OU associações de palavras.
- [ ] Especificar regras, entradas válidas, solução e como evitar ambiguidades antes de codar.
- [ ] Para palavras, usar conteúdo revisado e critérios verificáveis; não confiar em associações arbitrárias geradas ao vivo.
- [ ] Testar o protótipo separado antes de acrescentar modos e menus ao jogo principal.

### PC-031 · Avaliar sincronização iCloud entre aparelhos

[Cartão no Trello](https://trello.com/c/cQMMOpxc) · Pós-MVP · Expansão opcional

Só adicionar sincronização se existir uma necessidade real de trocar de aparelho.

Dependências: [PC-013](https://trello.com/c/ZQVqZB8x), [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Definir política de conflito para sessão em andamento, vitórias e preferências.
- [ ] App continua jogável sem login/conexão; indisponibilidade de sync não apaga dados locais.
- [ ] Migração e recuperação de conflitos testadas com diferentes versões do formato.
- [ ] Habilitar capacidades e atualizar declaração de privacidade conforme o que for implementado.

### PC-032 · Adicionar inglês e revisar localização completa

[Cartão no Trello](https://trello.com/c/WUKePV2S) · Pós-MVP · Expansão opcional

Expandir o idioma mantendo português e personalidade do jogo.

Dependências: [PC-021](https://trello.com/c/zZvTLxaL), [PC-025](https://trello.com/c/llcRNHJd).

- [ ] Traduzir interface, tutorial, dicas e pluralização usando o String Catalog.
- [ ] Testar textos longos, formatação de datas e VoiceOver por idioma.
- [ ] Nomes do cachorro escolhidos pela pessoa são preservados.
- [ ] Revisar screenshots e metadados apenas para idiomas realmente suportados.

### PC-033 · Avaliar publicação pública na App Store

[Cartão no Trello](https://trello.com/c/55a3aEQ9) · Pós-MVP · Lançamento opcional

Decidir se o presente vira um produto público depois do beta.

Dependências: [PC-026](https://trello.com/c/N3sm5MLT).

- [ ] Revisar escopo de suporte, posicionamento, classificação etária e dados de privacidade reais.
- [ ] Preparar descrição, screenshots e política de privacidade coerentes com a versão.
- [ ] Modelo comercial, se existir, é uma decisão separada; sem anúncios/moedas adicionados automaticamente.
- [ ] Submeter somente após decisão explícita de publicar e com a conta Apple configurada.

## Fonte estruturada

[backlog.json](backlog.json) guarda os mesmos IDs, critérios, dependências e links. Trello acompanha a execução; a lista em JSON é a organização inicial, sem sincronização automática de status.
