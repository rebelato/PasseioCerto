# Integração contínua · PC-023

Workflow `.github/workflows/ci.yml`, em push para main, pull requests e execução manual. Um job macOS com limite de 25 minutos; execuções antigas da mesma branch são canceladas. Sem assinatura, certificados ou segredos pessoais; token somente leitura e checkout sem persistir credenciais. Actions fixadas por SHA. Logs, resultado do build e screenshot são retidos por 7 dias.

## Ambiente

- Runner GitHub `macos-15` (imagem mantida pelo GitHub, não imutável).
- Xcode **26.3**, `/Applications/Xcode_26.3.app/Contents/Developer`.
- SDK/runtime iOS **26.2**, iPhone 16 criado exclusivamente para o job e removido no final.
- O script verifica as versões esperadas e falha se forem removidas do runner, em vez de trocar silenciosamente o SDK.
- Disponibilidade conferida no [manifesto oficial do runner](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md). O log de cada execução registra versões efetivas.

## Verificações

1. Todos os testes Swift Package, incluindo regras, fixtures de unicidade, deduções, persistência, vidas, dicas, datas e acessibilidade.
2. Corpus determinístico de geração seeds 0…49 (duas gerações por seed para comparar determinismo), extremos UInt64, cancelamento e orçamento esgotado. Dificuldade cobre seeds 0…9 por nível e orçamento; orçamentos internos são limitados. Nenhum fuzzing ilimitado. Calibração de desempenho com 100 seeds segue uma ferramenta separada, não um benchmark bloqueante em runner compartilhado.
3. Build completo do app iOS com catálogo e ícone, sem assinatura. Não exclui assets para contornar falhas.
4. Presença de Assets.car, localização pt-BR e metadados do ícone.
5. Instalar e abrir no simulador; confirmar processo após três segundos e capturar tela.

Os testes de domínio rodam no macOS. A etapa iOS é um smoke test de instalação/abertura, **não** uma suíte XCUITest nem validação de partidas, VoiceOver, hápticos ou fluidez. Não há retries automáticos nem testes desativados.

## Reproduzir

Na raiz do repositório, em Mac com Xcode/runtime instalados:

```sh
export DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
export EXPECTED_XCODE_VERSION=26.3
export EXPECTED_IOS_SDK=26.2
export SIMULATOR_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-26-2
bash scripts/ci.sh
```

Evidências em `build/ci-evidence` e derivados em `build/ci-derived`, ignorados pelo Git. O script remove apenas o result bundle gerado anteriormente para permitir nova execução. Para testar somente o núcleo: `swift test --disable-sandbox`. Para diagnosticar outro Xcode, ajuste DEVELOPER_DIR/runtime e omita as variáveis EXPECTED; isso não equivale ao ambiente fixado do CI.

## Resultado real

A execução no GitHub será registrada nesta seção após o primeiro push. Conclusão da PC-023 depende do pipeline real, não apenas da sintaxe YAML.
