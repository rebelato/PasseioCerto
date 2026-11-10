# TestFlight

Requer o Apple Developer Program pago. O Personal Team gratuito não envia builds. Antes do primeiro envio:

1. **Conta no Xcode:** em Settings → Accounts, o time pago precisa aparecer. No projeto, em Signing & Capabilities, selecione esse time.
2. **App no App Store Connect:** crie o app com o bundle ID `com.rebelato.PasseioCerto`.

## Gerar e enviar

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project PasseioCerto.xcodeproj -scheme PasseioCerto -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/PasseioCerto.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/PasseioCerto.xcarchive \
  -exportOptionsPlist scripts/ExportOptions-TestFlight.plist \
  -exportPath build/export -allowProvisioningUpdates
```

A assinatura e o envio usam a conta já logada no Xcode, sem senha na linha de comando. Com `manageAppVersionAndBuildNumber`, o App Store Connect sobe o número do build sozinho a cada envio. A versão do app fica em `MARKETING_VERSION` (1.0).

## O que testar (texto para o TestFlight)

> Passeio Certo: leve a Margot até a casinha seguindo as pistas de cada linha e coluna.
>
> Por favor, teste:
> - Os quatro níveis (Fácil 5×5, Médio 7×7, Difícil 15×15, Especialista 20×20). A casinha só aparece no Fácil; nos outros, ela surge quando o caminho fecha.
> - Desenhar arrastando ou tocando na casa vizinha. Um passo fora do caminho certo tira uma vida; tocar e segurar marca ×.
> - No 15×15 e no 20×20: ampliar com pinça, arrastar com dois dedos e desenhar com um dedo.
> - Perder as 3 vidas e usar "Tentar de novo" (deve repetir a mesma fase); completar e escolher "Nova fase" ou "Jogar esta de novo".
> - A casa da Margot: fome e alegria caindo com o tempo, comer, carinho, brinquedos e o balão de fala.
> - Ganhar moedas nos passeios (mais nos níveis difíceis e no desafio do dia) e gastar na loja: comida, acessórios, móveis, cores, piso e casinha.
> - Decorar o quarto tocando nos espaços, e o lembrete de fome nos Ajustes.
> - O desafio do dia, a sequência de dias e o álbum.
> - Vibração, sons e a animação de chegada.
>
> Conte o que ficou confuso, fácil ou difícil demais, e qualquer travamento.
