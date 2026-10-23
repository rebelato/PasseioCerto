# Arte da Margot · PC-022

A arte é original, desenhada em SwiftUI/Paths em `App/DesignSystem/MargotArt.swift` por Codex para este projeto. Referências de aparência: fotografias pessoais da Margot fornecidas pelo usuário na conversa (pelagem branca/cacheada, orelhas caídas creme, olhos e nariz escuros, focinho arredondado alongado). Nenhuma fotografia foi copiada para o repositório. Não foram usados assets externos, fontes comerciais ou imagens geradas por modelo nesta entrega.

## Arquivos e estados

- `MargotIdle`: retrato neutro para início/partida, RGBA 512 × 512.
- `MargotWalking`: orelhas levemente abertas durante o percurso, RGBA 512 × 512. O deslocamento continua sendo a animação nativa pelos segmentos da rota da PC-016; não há sprite de corpo inteiro.
- `MargotHappy`: língua à mostra na chegada/conclusão, RGBA 512 × 512.
- `GardenHouse`, `GardenShrub`: casinha terracota e arbusto, RGBA 256 × 256.
- `AppIcon`: Margot em fundo sálvia, RGB 1024 × 1024, sem transparência e sem máscara de cantos embutida.

Tudo fica em `App/Assets.xcassets`. Puppy/GardenHouse/GardenShrub usam o catálogo com fallback para o mesmo desenho nativo se a imagem estiver ausente. Textos, pistas, conexões, hit targets e acessibilidade continuam nativos; arte é decorativa e cabe dentro da célula. Com Reduzir Movimento, aparece diretamente a pose feliz na chegada.

## Reprodução

Na raiz do projeto, com Xcode instalado:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -swift-version 6 -target arm64-apple-macos14.0 -module-cache-path /tmp/passeio-render-cache App/DesignSystem/MargotArt.swift scripts/RenderArtwork.swift -o /tmp/render-margot
/tmp/render-margot /tmp/margot-art
```

Copiar os PNGs nomeados para seus imagesets/appiconset após revisar. O script também gera uma folha de revisão. A fonte vetorial permite exportar novamente em outras resoluções.

## Verificação

[Conjunto](validation/margot-artwork.png), [grade clara](validation/margot-board-light.png), [grade escura](validation/margot-board-dark.png). Renderizações SwiftUI no macOS, grade com células de 48 pt e largura total 288 pt. Inspeção estática: arte contida nas células, pistas e arestas legíveis. Dimensões e canais alpha dos seis PNGs verificados. Ícone configurado no projeto para Debug e Release.

Build completo de simulador e de dispositivo **bloqueados** no CompileAssetCatalogVariant: `No available simulator runtimes for platform iphonesimulator`; serviço CoreSimulator indisponível neste ambiente. Build iOS do código passou com `EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets ASSETCATALOG_COMPILER_APPICON_NAME=` apenas para isolar a checagem de compilação. Isso **não valida** o empacotamento do catálogo/ícone.

Pendente: build completo no Xcode com runtime disponível, ícone instalado na tela inicial, aparência em iPhone pequeno/grande, estados durante animação e revisão visual da semelhança com Margot. PC-022 permanece Em revisão.
