# Direção visual · Passeio Certo

## Referência aprovada

![Tela de jogo conceitual](assets/conceito-inicial.png)

Esboço criado com a ferramenta imagegen e aprovado pelo usuário na conversa de concepção. É material de referência para a interface; os assets finais individuais serão preparados em PC-022.

## Intenção

Um puzzle acolhedor para uma pessoa adulta que gosta de Nonogram, Sudoku e animais. A grade e as pistas têm prioridade; a personalidade aparece no Bento e na chegada à casinha.

- Fundo marfim, texto verde-escuro, sálvia/eucalipto e pequenos acentos quentes.
- Tipografia legível com estilos do sistema e Dynamic Type; testar a personalidade do título sem comprometer leitura.
- Células claras, cantos suaves e caminho com linha central explícita. Evitar relevo excessivo que confunda os limites.
- Cachorrinha branca de pelagem cacheada, orelhas caídas, olhos e focinho escuros, inspirada na foto enviada pelo usuário, casinha pequena com telhado terracota e vegetação discreta.
- Cinco pistas de colunas e cinco pistas de linhas corretamente alinhadas; sem números ornamentais dentro da grade.

## Hierarquia da partida

1. Navegação e identificação da fase.
2. Objetivo curto com o nome do cachorro.
3. Tabuleiro, pistas e estados.
4. Nota contextual/dica quando solicitada.
5. Ferramentas Caminho / Marcar ×.
6. Desfazer e Dica.

Evitar cabeçalho que roube o espaço da grade. A moldura de iPhone da ilustração não é parte da interface. Não colocar controles ou conteúdo sob a barra de status, home indicator ou teclado.

## Estados necessários

Célula livre, obstáculo, endpoint do cachorro, endpoint da casa, caminho com arestas, marcação ×, célula destacada por dica e foco acessível. Pistas pendentes/atendidas/excedidas precisam de indicação além da cor.

Som, hápticos e animação são complementos opcionais. Com Reduce Motion, a vitória continua compreensível sem o cachorro percorrer toda a tela.

## Interação e conforto

- Arrastar tem alternativa por toque e por ações de acessibilidade.
- Não exigir precisão motora para demonstrar que a pessoa entendeu a dedução.
- Pista atendida não é selo de acerto global. × é marcação do jogador.
- Dica explica um próximo fato; não resolve silenciosamente a fase.
- Três corações indicam vidas por tentativa, com texto acessível e feedback de erro além da cor. Ao zerar, oferecer Tentar novamente. Sem cronômetro obrigatório, anúncios ou bloqueio por moedas.

## Assets finais

Não recortar o mockup inteiro para simular uma tela. Grade, pistas, texto, caminho e controles serão nativos. Separar cão, casa, ícone e outros desenhos em arquivos apropriados, com origem/licenciamento documentados e tamanhos verificados no aparelho.

A primeira implementação usa uma ilustração vetorial SwiftUI provisória. A foto pessoal não é incluída no repositório.

## Sistema visual implementado · PC-009

`App/DesignSystem` centraliza tokens de cor semânticos claro/escuro, título serifado, texto arredondado, espaçamento de 16 pt, cantos e área mínima dos controles. Componentes: GardenClue, GardenCell, GardenTools, GardenNote e GardenButtonStyle. Puppy foi separado e preserva a referência branca/cacheada. A arte continua provisória.

Na partida, banner compacto deixa espaço para a grade; caminho é desenhado abaixo dos endpoints. Pistas usam ✓ e ! além da cor. Fonte ampliada aumenta o tamanho mínimo da grade, com rolagem horizontal, e ferramentas têm alternativa de disposição vertical. Galeria/Previews incluem botão Dica e destaque de célula, sem ligar funcionalidades futuras ao jogo.

Contraste calculado dos tokens: texto principal/fundo claro 11,05:1; secundário/fundo 5,44:1; erro/superfície 6,92:1; texto sobre sálvia escura 8,68:1. Contornos contra superfície: 3,15:1 claro e 4,06:1 escuro.

Galerias SwiftUI renderizadas em macOS em largura de 375 pt: [claro](validation/design-components-light.png), [escuro](validation/design-components-dark.png). São componentes, não screenshots de iPhone. A renderização completa com ScrollView não ficou disponível via ImageRenderer; a configuração de texto ampliado no renderer macOS não reproduziu o comportamento iOS. CoreSimulatorService está indisponível no ambiente.

Build de iPhone Simulator aprovado. PC-009 permanece em revisão até verificar a tela completa no iPhone pequeno, texto ampliado, VoiceOver e interação; não considerar a galeria como validação dessas condições.
