# Regras propostas · versão 0.1

Estas decisões tornam o conceito implementável. PC-002 deve confirmá-las com fixtures e registrar qualquer alteração antes do gerador.

## Objetivo

Desenhar um caminho contínuo do cachorro até a casa, cumprindo todas as pistas numéricas. Não é necessário usar todas as células.

## Tabuleiro

- MVP: grade 5×5 com um cachorro e uma casa em células distintas.
- Coordenadas usadas pela interface: linha e coluna de 1 a 5. O modelo pode usar base zero internamente, com conversão explícita.
- Cada linha/coluna tem uma pista: o número exato de células ocupadas pela rota final naquela linha/coluna.
- A célula do cachorro e a da casa contam, inclusive antes de estarem conectadas. Cada uma conta uma única vez.
- Obstáculos, se presentes, são explícitos e nunca podem fazer parte do caminho.
- Somatório das pistas das linhas deve coincidir com o das colunas e com a quantidade final de células do caminho. Isso é necessário, mas não suficiente para provar validade.

## Caminho

- Movimento apenas ortogonal, sem diagonais.
- Rota ordenada a partir do cachorro; sem repetir uma célula, sem ciclos, ramificações ou cruzamentos.
- Só termina com vitória quando chega à casa e atende a TODAS as pistas e regras.
- A interação estende um prefixo conectado ao cachorro; não deixa segmentos soltos.
- Trechos não consecutivos podem ser vizinhos lateralmente, mas **não se conectam por proximidade**. Conexões são arestas explícitas desenhadas entre centros de células.
- Por isso, duas rotas com a mesma ocupação e arestas diferentes são soluções distintas. A prova de unicidade precisa considerar a rota inteira.
- A inversão de uma mesma rota não conta como uma segunda solução: a orientação é fixada cão→casa.

## Marcações e ferramentas

- **Caminho:** arrastar ou tocar numa célula adjacente para estender o trecho atual.
- Recuar sobre o último trecho apaga aquele trecho; uma transação de gesto inteiro pode ser desfeita.
- **Marcar ×:** hipótese/dedução da pessoa de que a célula não faz parte do caminho. Não é uma certificação do aplicativo.
- Células do cachorro/casa não podem receber ×. Caminho e × não coexistem na mesma célula; resolver a marcação antes de estender por ali.
- Toques e ações acessíveis oferecem alternativa completa ao arraste.
- Desfazer não custa vidas, moeda ou tentativas. Reiniciar pede confirmação.

## Contagens e feedback

- Ocupação conhecida = endpoints mais células desenhadas, sem contar a casa duas vezes quando o caminho chega.
- Pista atendida significa apenas que aquela contagem foi atingida; não garante solução global correta.
- Violações de regra recebem feedback local: limites, obstáculo, movimento impossível ou pista excedida.
- Não usar a solução guardada para marcar uma célula como errada apenas porque difere do gabarito.
- Se um solver não consegue terminar a análise no orçamento, o resultado é indeterminado, nunca “sem solução” ou “solução única”.

## Dicas e fases sem chute

- O solver exato verifica existência e unicidade.
- O motor lógico propaga deduções e registra justificativas: linha/coluna completa, posições restantes obrigatórias, continuidade e conectividade quando comprováveis.
- Uma fase só é aprovada pelo gerador se o motor lógico consegue concluí-la sem testar hipóteses/backtracking.
- Um fato sobre uma célula distante pode ser destacado em uma dica, mas não inventa uma ligação ao caminho atual.
- Uma dica considera o estado atual. Se ele for inconsistente, explicar o conflito comprovável ou orientar revisão; não inventar uma célula culpada sem prova.
- Explicação indisponível deve ser declarada; o motor não disfarça consulta ao gabarito como dedução.

## Fixture do conceito aprovado

Pistas de linhas: `[3, 1, 3, 1, 1]`.

Pistas de colunas: `[1, 1, 3, 1, 3]`.

Cachorro: `(1,1)`. Casa: `(5,5)`. Sem obstáculos.

Rota completa de referência, com 9 células:

```text
(1,1) → (1,2) → (1,3)
                    ↓
                  (2,3)
                    ↓
                  (3,3) → (3,4) → (3,5)
                                    ↓
                                  (4,5)
                                    ↓
                                  (5,5)
```

O mockup mostra apenas o prefixo até `(3,3)`. O estado autoritativo das pistas deve ser recalculado pelo app, não copiado das cores da imagem.

Esta fixture é introdutória. Não representa toda a dificuldade ou a variedade esperada; o solver fará a verificação formal em PC-005.

## Identidade, diário e fallback

- puzzleID, schemaVersion e generatorVersion precisam acompanhar os dados salvos.
- Usar seed e algoritmos determinísticos, sem depender de hashValue/Hasher aleatórios do processo.
- Limites de candidatos/operações são parte do processo reprodutível; cancelamento não pode produzir uma grade diferente sob o mesmo ID.
- Fallbacks têm identidade própria e são verificados antecipadamente.
- Desafio diário usa chave de data civil com política de fuso documentada. Persistir a grade selecionada; virar o dia ou atualizar o app não substitui uma partida já aberta.

## Fora do primeiro conjunto de regras

Vários animais, portais, chaves, pistas de palavras ou operações matemáticas novas. Cada variante exige desenho, solver e testes próprios antes de entrar na progressão.

## Fixtures executáveis · PC-002

`Sources/PuzzleCore/PuzzleFixtures.swift` contém quatro grades 5×5:

- `approved-5x5-v1`: conceito aprovado, com rota testemunha válida.
- `perimeter-5x5-v1`: rota pelo perímetro e obstáculo explícito no centro.
- `disconnected-5x5-v1`: somas compatíveis, mas uma linha inteira de obstáculos separa os endpoints. Busca de conectividade no teste comprova impossibilidade.
- `ambiguous-5x5-v1`: duas rotas válidas com a mesma ocupação no bloco superior 3×3, mas com arestas diferentes. Demonstra por que unicidade não pode comparar só células.

“Válida” significa que existe uma rota comprovada; não afirma unicidade. PC-005 verificará as classificações pelo solver exato. Os testemunhos são dados de teste/referência, nunca um oráculo de erro ou dica na interface.

### Contrato dos gestos

Um toque válido é uma transação. Um arraste será uma única transação de histórico, mesmo passando por várias células: Desfazer restaura o estado anterior ao gesto inteiro. Recuar para a penúltima célula remove o último segmento. Soltar encerra a transação; cancelar/interromper restaura o estado anterior ao gesto. Sair da grade não acrescenta células; movimentos diagonais ou saltos não inventam segmentos intermediários. Esse contrato será implementado em PC-011/PC-012; a versão atual oferece toque.

A casa encerra a rota, mas só representa vitória com todas as pistas atendidas. Uma chegada incompleta permite recuar/desfazer. Nenhuma ferramenta pode marcar × sobre endpoints, obstáculos ou caminho. Pistas satisfeitas mostram a contagem alcançada, sem garantir que exista continuação.

## Validador central · PC-004

`RouteValidator` diferencia `incomplete`, `contradiction(motivo)` e `complete`. Valida início, limites, obstáculos, repetição/ciclos, conexões ortogonais, continuação após a casa, conflito de × e excesso nas pistas. Uma chegada que não satisfaz todas as pistas é contradição explícita, preservada no salvamento para permitir revisão e desfazer.

`incomplete` significa apenas ausência de violação detectada: não prova que existe solução. Análise global de continuidade possível depende do solver de PC-005. Marcações × livres continuam sendo hipóteses do jogador.

Verificação: 18 testes passando, incluindo duas soluções com mesma ocupação e arestas diferentes; build iPhone Simulator aprovado. A mensagem de chegada incompleta foi compilada, mas ainda não revisada visualmente em aparelho.
