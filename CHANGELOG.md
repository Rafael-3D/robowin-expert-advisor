# Changelog - RoboWIN

Todas as mudanças notáveis do projeto serão documentadas neste arquivo.

---

## [V3.21] - 2026-02-27

### ⚠️ VERSÃO DE EMERGÊNCIA - Reverte V3.3

**Contexto:** A V3.3 apresentou bug crítico que causou preços incorretos nas ordens de compra (19395.0 ao invés de 193950.0), tornando o robô inoperante.

### Adicionado
- ✅ Módulo de estatísticas (MFE/MAE) integrado da V3.3
- ✅ Chamadas ao `Stats_OnOpen()`, `Stats_OnTick()`, `Stats_OnClose()`
- ✅ Flags `jaLogouLimiteCompra` e `jaLogouLimiteVenda` para evitar logs repetitivos

### Removido
- ❌ Validação de slippage/GAP da V3.3 (causou o bug)
- ❌ Variáveis `precoOrdemCompraPendente` e `precoOrdemVendaPendente`
- ❌ Parâmetro `toleranciaExecucao`
- ❌ Campos `precoOrdemOriginal` e `execucaoValidada` da struct `InfoPosicao`
- ❌ Função `ConfigurarFillingMode()` (desnecessária)

### Corrigido
- 🔧 Logs de "Máximo de tentativas" agora aparecem apenas UMA vez (não a cada tick)
- 🔧 Base de código volta para V3.2 (estável e testada)

### Arquivos
- `RoboWIN_CORRIGIDO_V3.2.1.mq5` - **USAR ESTA VERSÃO**
- `RoboWIN_CORRIGIDO_V3.3.mq5` - REJEITADA (bug crítico)

---

## [V3.30] - 2026-02-26

### ⚠️ VERSÃO REJEITADA - Bug Crítico

**Problema:** Bug na leitura de parâmetros causou preço errado nas ordens.
- Preço configurado: 193950.0
- Preço enviado: 19395.0 (falta um dígito!)

### Adicionado (mas com bug)
- Validação de execução vs preço configurado
- Tolerância máxima de slippage (20 pontos)
- Armazenamento do preço original das ordens
- Módulo de estatísticas (MFE/MAE)

**NÃO USAR ESTA VERSÃO**

---

## [V3.20] - 2026-02-24

### ✅ VERSÃO ESTÁVEL - Base para V3.2.1

### Adicionado
- ✅ Flag `diaEncerrado` para controle rigoroso
- ✅ BREAKEVEN encerra o dia (não permite nova entrada)
- ✅ TAKE PROFIT encerra o dia
- ✅ Apenas STOP LOSS permite nova entrada (se < 2)

### Corrigido
- 🔧 Bug da V3.1 que permitia 3ª entrada após breakeven
- 🔧 Lógica de `ResetarAposStop()` apenas para stop loss

---

## [V3.00] - 2026-02-20

### Adicionado
- Parâmetro `usarOrdemMercado` para controlar comportamento quando preço passa do nível
- Validações de ordem limitada (BUY_LIMIT < preço atual, SELL_LIMIT > preço atual)
- Ajuste automático de SL/TP após execução real
- Diagnóstico detalhado de erros

---

## [V2.00] - 2026-02-15

### Adicionado
- Função `NormalizarPreco()` para múltiplos de 5 (tick size WIN)
- Função `ValidarDistanciaStop()` para respeitar mínimos do broker
- Logs detalhados para debug

### Corrigido
- Parâmetros invertidos em `OrderOpen()` (4 e 5)

---

## [V1.03] - 2026-02-10

### Versão inicial
- Lógica básica de entrada em níveis de compra/venda
- Ordens limitadas
- Stop Loss e Take Profit
- Break Even

---

## Legenda

- ✅ Adicionado/Funcionando
- ❌ Removido/Não funciona
- 🔧 Corrigido
- ⚠️ Atenção/Aviso
