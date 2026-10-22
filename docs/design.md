# Direção visual · Passeio Certo

## Referência aprovada

![Tela de jogo conceitual](assets/conceito-inicial.png)

Esboço criado com a ferramenta imagegen e aprovado pelo usuário na conversa de concepção. É material de referência para a interface; os assets finais individuais serão preparados em PC-022.

## Intenção

Um puzzle acolhedor para uma pessoa adulta que gosta de Nonogram, Sudoku e animais. A grade e as pistas têm prioridade; a personalidade aparece no Bento e na chegada à casinha.

- Fundo marfim, texto verde-escuro, sálvia/eucalipto e pequenos acentos quentes.
- Tipografia legível com estilos do sistema e Dynamic Type; testar a personalidade do título sem comprometer leitura.
- Células claras, cantos suaves e caminho com linha central explícita. Evitar relevo excessivo que confunda os limites.
- Cão dourado/caramelo, casinha pequena com telhado terracota e vegetação discreta.
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
- Sem cronômetro obrigatório, vidas, anúncios ou bloqueio por moedas no primeiro beta.

## Assets finais

Não recortar o mockup inteiro para simular uma tela. Grade, pistas, texto, caminho e controles serão nativos. Separar cão, casa, ícone e outros desenhos em arquivos apropriados, com origem/licenciamento documentados e tamanhos verificados no aparelho.
