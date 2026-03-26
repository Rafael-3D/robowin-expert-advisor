# 🔴 ANÁLISE COMPLETA — RoboWIN V3.2.1 — Dia 16/03/2026

## Resumo Executivo

| Item | Detalhe |
|------|---------|
| **Data** | 16/03/2026 (segunda-feira) |
| **Símbolo** | WINJ26 (Mini Índice Futuro - B3) |
| **Versão** | RoboWIN_CORRIGIDO_V3.2.1 |
| **Resultado** | **Prejuízo de R$ -251,00** (deveria ser R$ -40,00 no máximo) |
| **Causa raiz** | SL/TP NUNCA foram definidos → posição ficou 16 min sem proteção → corretora zerou |
| **Entradas** | 1 de 2 possíveis (2ª foi rejeitada 3x) |

### Gravidade: 🔴 CRÍTICA
O robô operou **16 minutos e 47 segundos** com posição aberta **SEM Stop Loss nem Take Profit**, resultando em prejuízo 6,3x maior que o planejado.

---

## 📋 Parâmetros do Dia

### Parâmetros Carregados (do log)

| Parâmetro | Valor | Observação |
|-----------|-------|------------|
| Compra 1 | 179.755,0 | Nível de compra mais alto |
| Compra 2 | 179.625,0 | Nível de compra mais baixo |
| Venda 1 | 180.820,0 | Nível de venda mais baixo |
| Venda 2 | 180.950,0 | Nível de venda mais alto |
| Take Profit | 800 pts | ~R$ 160,00 |
| Stop Loss | 200 pts | ~R$ 40,00 |
| Break Even | **300 pts** | Alterado de 350→300 às 06:19 |
| Contratos | 1 | |
| Horário | 09:00 - 12:00 | |
| Tick Size | 5.0 | |
| Tick Value | R$ 1,00 | |

> ⚠️ **NOTA**: Os parâmetros que você mencionou (Compra 1: 194.105) **diferem** dos carregados no log (179.755). O log mostra os parâmetros que estavam efetivamente configurados no robô neste dia. Houve uma reinicialização às 06:19:13 onde o BE foi alterado de 350→300 (motivo: "Parâmetros alterados").

---

## 📊 Timeline Completa dos Eventos

```
06:18:56.351 │ 🟢 INIT #1: Robô V3.2.1 inicializado
             │    BE=350, TP=800, SL=200
             │    Stops Level (broker): [não informado no log]
             │
06:19:13.939 │ 🔄 INIT #2: Parâmetros alterados pelo usuário
             │    BE mudou de 350 → 300
             │    Demais parâmetros mantidos
             │
09:00:53.033 │ 🟢 MERCADO ABERTO
             │    Preço de abertura: 181.800,0
             │    Preço atual (tick): 161.885,0 ← ⚠️ PREÇO SUSPEITO (ver Erro #1)
             │
09:00:53.034 │ 📤 SELL_LIMIT enviada
             │    Preço atual mostrado: 161.885,0 (ABAIXO do nível)
             │    Nível de venda: 180.820,0
             │    Lógica: "ordem será executada quando preço SUBIR"
             │
09:00:53.902 │ ✅ SELL_LIMIT CONFIRMADA pelo servidor
             │
09:00:54.005 │ ⚡ POSIÇÃO ABERTA DETECTADA
             │    Tipo: VENDA
             │    Preço Entrada REAL: 181.435,0 ← ⚠️ 615 PTS ACIMA DO LIMIT!
             │    [STATS] Trade #2 iniciado | VENDA @ 181435.0
             │
09:00:54.005 │ 🔧 1ª tentativa de AJUSTAR SL/TP
             │    [VENDA] SL = 181.435 + 200 = 181.635,0 (ACIMA)
             │    [VENDA] TP = 181.435 - 800 = 180.635,0 (ABAIXO)
             │    ❌ "Erro ao modificar posição: invalid stops"
             │
09:00:54 a   │ 🔴🔴🔴 LOOP DE ERRO: ~34.290 tentativas de modificar SL/TP
09:16:41     │    TODAS falharam com "invalid stops"
             │    Posição ABERTA SEM PROTEÇÃO por 15 min 47 seg
             │    Frequência: ~36 tentativas/segundo (a cada tick!)
             │
09:16:41.062 │ ❌ POSIÇÃO FECHADA (zeramento pela corretora)
             │    ╔══════════════════════════════════╗
             │    ║   STOP LOSS EXECUTADO             ║
             │    ╠══════════════════════════════════╣
             │    ║  Prejuízo: R$ -251,00             ║
             │    ║  Preço entrada: 181.435,0          ║
             │    ║  Preço fechamento: 182.690,0       ║
             │    ║  SL configurado: 181.695,0 ← ⚠️   ║
             │    ║  Stops executados: 1/2             ║
             │    ╚══════════════════════════════════╝
             │    [STATS] MFE: 19.550 pts | MAE: 1.250 pts
             │
09:16:41.064 │ 🔄 RESET APÓS STOP LOSS
             │    Stops: 1/2, Restantes: 1
             │    Pronto para nova entrada nos níveis originais
             │    Preço atual: 182.685,0
             │
09:16:41.064 │ 📤 Tentativa 1/3: BUY_LIMIT @ 179.755,0
             │    ❌ Erro 10006: "rejected" (rejeitada pelo servidor)
             │
09:16:43.082 │ 📤 Tentativa 2/3: BUY_LIMIT @ 179.755,0
             │    Preço atual: 182.710,0
             │    ❌ Erro 10006: "rejected"
             │
09:16:46.111 │ 📤 Tentativa 3/3: BUY_LIMIT @ 179.755,0
             │    Preço atual: 182.700,0
             │    ❌ Erro 10006: "rejected"
             │    ⚠️ "Máximo de tentativas de COMPRA atingido (3)"
             │
09:17 a      │ 😴 ROBÔ OCIOSO
11:59        │    Monitorando preço, mas sem conseguir entrar
             │    Última leitura: 182.135,0 às 11:59:20
             │
12:00:00.082 │ 🔴 ENCERRANDO OPERAÇÕES
             │    Motivo: "Horário encerrado"
             │    Sem posição aberta para fechar
```

---

## 🔴 ERRO #1 — Entrada Errada (SELL_LIMIT executou no preço errado)

### O que aconteceu
O robô enviou uma **SELL_LIMIT a 180.820,0** mas a posição abriu em **181.435,0** — ou seja, **615 pontos ACIMA** do preço limite definido.

### Dados do log
```
Preço atual (tick):     161.885,0    ← Preço SUSPEITO
Preço de abertura:      181.800,0    ← Preço real do dia
SELL_LIMIT enviada em:  180.820,0    ← Nível configurado
Preço de execução:      181.435,0    ← Onde realmente executou
Diferença:              +615 pts     ← SLIPPAGE ENORME
```

### Análise da causa raiz

**O preço de 161.885,0 é FALSO.** No momento da abertura do mercado (09:00:53), o `SymbolInfoDouble(_Symbol, SYMBOL_BID)` retornou `161.885,0` — um valor completamente fora da realidade, já que o preço de abertura do dia era `181.800,0`.

Isso é um problema **CONHECIDO** no MetaTrader 5 no momento da abertura do pregão:
- O primeiro tick recebido pode conter dados "sujos" ou do dia anterior
- O `SYMBOL_BID` pode não estar atualizado ainda quando o `OnTick()` dispara pela primeira vez

**Consequência direta:**
1. O robô viu preço = 161.885 (falso, abaixo de Venda 1 = 180.820)
2. A lógica do `MonitorarNiveisEntrada()` (linha 554) checou: `precoAtual (161.885) < pontoVenda1 (180.820)` → **TRUE**
3. Então definiu `nivelVenda = pontoVenda1 = 180.820`
4. Chamou `ExecutarOrdemLimitada(ORDER_TYPE_SELL_LIMIT, 180820)`
5. Na validação (linha 639): `precoLimite (180.820) <= precoAtual (161.885)` → **FALSE** (não bloqueou!)
6. A ordem foi enviada ao servidor
7. O servidor viu que o preço REAL já estava em ~181.435 (ACIMA de 180.820)
8. Como era SELL_LIMIT, executou **imediatamente** no preço de mercado (181.435)

### Impacto
- Entrada 615 pontos pior que o planejado
- O TP ficou mais distante e o SL mais próximo do mercado
- Contribuiu para a impossibilidade de definir SL/TP (ver Erro #2)

### Correção sugerida
```
// Na MonitorarNiveisEntrada(), adicionar validação do preço:
double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);

// NOVO: Validar se preço está dentro de um range razoável
if (precoAtual < pontoCompra2 * 0.95 || precoAtual > pontoVenda2 * 1.05) {
    Print("⚠️ Preço suspeito: ", precoAtual, " - ignorando tick");
    return;
}

// NOVO: Não operar no primeiro tick - aguardar estabilização
static int tickCount = 0;
if (tickCount < 5) { tickCount++; return; }
```

---

## 🔴 ERRO #2 — "Invalid Stops" (SL/TP NUNCA definidos → Zeramento pela Corretora)

### O que aconteceu
Após a posição ser aberta em 181.435,0 (VENDA), o robô tentou definir:
- **SL = 181.635,0** (entrada + 200 pts, acima da entrada ✓)
- **TP = 180.635,0** (entrada - 800 pts, abaixo da entrada ✓)

Os valores estão **logicamente corretos** para uma VENDA. Mas a corretora rejeitou **TODAS as 34.290 tentativas** com erro `"invalid stops"`.

### Por que o broker rejeitou?

O erro `"invalid stops"` no MT5 (código 10016 interno do `trade.PositionModify`) ocorre quando o SL ou TP está **muito próximo do preço atual de mercado**, violando a distância mínima (`SYMBOL_TRADE_STOPS_LEVEL`).

**Cenário provável:**

```
Entrada (VENDA):   181.435,0
SL tentado:        181.635,0  (200 pts acima da entrada)
Preço de mercado:  ~181.500+ (já subindo contra a posição)

Distância SL→Mercado: 181.635 - 181.500 = apenas ~135 pts
Stops Level mínimo:   Provavelmente 200+ pts (definido pela B3/corretora)

→ 135 < 200 → REJEITADO!
```

O **preço já estava se movendo contra a posição** no momento exato em que o robô tentou definir o SL. Como o mercado subiu rapidamente após a abertura, o SL de 181.635 ficou progressivamente mais próximo (e eventualmente ABAIXO) do preço de mercado, tornando-o **permanentemente inválido**.

### O loop infinito
```
A cada tick (~100ms):
  1. MonitorarPosicao() → stopsAjustados = false
  2. AjustarStopsAposExecucao() calcula SL=181635, TP=180635
  3. trade.PositionModify() → "invalid stops"
  4. stopsAjustados permanece FALSE
  5. Volta ao passo 1
  
Resultado: 34.290 tentativas em 16 minutos → TODAS falharam
```

### O "SL configurado: 181.695,0" é FANTASMA
No log do `VerificarResultadoPosicao()`, aparece `SL configurado: 181.695,0`. Mas como o `stopsAjustados` nunca virou `true` (vide o loop de erro), o valor `posicaoAtual.stopLoss` é o valor **padrão/inicial**, não um SL efetivamente registrado na corretora. A posição **NUNCA teve SL/TP no servidor**.

### O que realmente fechou a posição?
Como não havia SL no servidor, a posição só poderia ser fechada por:
1. **Zeramento compulsório pela corretora** (limite de margem/risco) — **MAIS PROVÁVEL**
2. Chamada de margem
3. Liquidação no horário (não se aplica, ainda eram 09:16)

O preço de fechamento foi **182.690,0** (1.255 pts contra a posição de venda). Com SL de 200 pts, a perda deveria ser R$ 40. O prejuízo real foi **R$ 251,00** — ou seja, **6,3x pior**.

### MFE e MAE registrados pelo Stats
- **MFE (Maximum Favorable Excursion): 19.550 pts** — Em algum momento o preço chegou a 181.435 - 19.550 = ~161.885 (novamente o preço "falso" do primeiro tick). Isso confirma que o Stats captou o tick falso como MFE.
- **MAE (Maximum Adverse Excursion): 1.250 pts** — Maior excursão adversa real antes do fechamento.

### Impacto
| Cenário | Prejuízo |
|---------|----------|
| **Com SL funcionando (200 pts)** | R$ -40,00 |
| **Prejuízo REAL (sem SL)** | R$ -251,00 |
| **Excesso de perda** | R$ -211,00 (528% a mais) |

### Correção sugerida

**Problema central: o robô NÃO tem fallback quando `PositionModify` falha.**

```
// Em AjustarStopsAposExecucao(), adicionar:
static int tentativasModify = 0;
tentativasModify++;

if (!trade.PositionModify(_Symbol, novoSL, novoTP)) {
    Print("❌ Tentativa ", tentativasModify, " de modificar SL/TP falhou");
    
    // NOVO: Após N tentativas, fechar posição a mercado por segurança
    if (tentativasModify >= 50) {
        Print("🚨 EMERGÊNCIA: Impossível definir SL/TP após 50 tentativas!");
        Print("🚨 FECHANDO POSIÇÃO A MERCADO para evitar prejuízo maior!");
        trade.PositionClose(_Symbol);
        tentativasModify = 0;
        return;
    }
    
    // NOVO: Tentar com SL mais distante (incrementar distância)
    int novaDistancia = stopLoss + (tentativasModify * 50);
    // ... recalcular novoSL com novaDistancia
}
```

---

## 🟡 ERRO #3 — BUY_LIMIT Rejeitada 3x (Erro 10006)

### O que aconteceu
Após o stop loss, o robô tentou reentrar com **BUY_LIMIT @ 179.755,0**, mas o servidor rejeitou 3 vezes com **erro 10006** ("Order rejected by server").

### Dados do log
```
09:16:41.064 │ BUY_LIMIT @ 179.755 → ❌ 10006 (rejected)
09:16:43.082 │ BUY_LIMIT @ 179.755 → ❌ 10006 (rejected)  Preço: 182.710
09:16:46.111 │ BUY_LIMIT @ 179.755 → ❌ 10006 (rejected)  Preço: 182.700
             │ "Máximo de tentativas de COMPRA atingido (3)"
```

### Análise

O **erro 10006** no MT5 significa "Order rejected" e pode ocorrer por:
1. **Conta sem margem suficiente** — Após o prejuízo de R$ 251, pode não ter saldo para nova operação
2. **Limite de ordens pendentes atingido** — Improvável (apenas 1 ordem)
3. **Restrição da corretora** — Após zeramento compulsório, algumas corretoras bloqueiam novas ordens temporariamente
4. **Distância excessiva** — BUY_LIMIT a 179.755 com mercado em 182.700 = 2.945 pts de distância. Pode violar alguma regra da corretora sobre ordens muito distantes.

### Impacto
- O robô ficou **ocioso de 09:17 até 12:00** sem poder operar
- 1 entrada de 2 foi desperdiçada
- O preço nunca chegou em 179.755 nesse dia (ficou entre 181-183k), então mesmo que a ordem fosse aceita, provavelmente não teria sido executada

### Observação sobre BUY_LIMIT vs BUY_STOP

O robô usa **BUY_LIMIT** corretamente neste caso:
- **BUY_LIMIT**: Compra quando o preço **cair até** o nível definido. Preço limite deve ser **abaixo** do preço atual. ✅ (179.755 < 182.700)
- **BUY_STOP**: Compra quando o preço **subir até** o nível definido. Preço stop deve ser **acima** do preço atual.

A escolha de BUY_LIMIT está correta pela lógica do robô (esperar o preço cair até o nível de compra).

---

## 🟡 ERRO #4 — Encerramento do Dia (12:00)

### O que aconteceu
Às 12:00:00.082, o robô executou `EncerrarDia("Horário encerrado")`. O log mostra apenas o banner de encerramento, **sem** `trade.PositionClose()`.

### Análise
Isso é **comportamento correto** neste caso:
- A posição foi fechada às 09:16:41 (stop loss)
- Às 12:00 não havia posição aberta
- A função `EncerrarDia()` (linha 941-957) verifica `PositionSelect(_Symbol)` antes de chamar `trade.PositionClose()` — como não havia posição, não fechou nada

### ⚠️ Porém...
Se o robô tivesse conseguido abrir a 2ª posição (BUY_LIMIT), e essa posição ainda estivesse aberta às 12:00, a função `EncerrarDia()` **fecharia corretamente** a posição (linha 951).

O risco está em: **se o bug do "invalid stops" acontecer novamente na 2ª entrada**, a posição poderia ficar aberta sem SL até às 12:00 — 2h45min sem proteção.

---

## 📊 Módulo de Estatísticas (RoboWIN_Stats.mqh)

### Status dos CSVs
O módulo de Stats está **configurado** no código e foi **ativado** no dia 16/03:
```
[STATS] Trade #2 iniciado | VENDA @ 181435.0
[STATS] Dados salvos em: Stats\trades_20260316.csv
[STATS] Trade #2 finalizado | Resultado: -251.00 | MFE: 19550 pts | MAE: 1250 pts
```

**Porém, o arquivo CSV NÃO foi encontrado** no diretório `/home/ubuntu/robowin_fix/Stats/` — apenas existe um `.gitkeep`. O CSV é salvo pelo MT5 no diretório `FILE_COMMON` do MetaTrader, que fica em:
```
C:\Users\<user>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Stats\
```

> 📌 **Para acessar o CSV**: Abra o MT5 → Arquivo → Abrir Pasta de Dados → vá para `MQL5\Files\Stats\` ou procure em `Common\Files\Stats\`.

### Dados coletados pelo Stats (do log)
| Métrica | Valor | Observação |
|---------|-------|------------|
| Trade # | 2 | Indica que houve outro trade antes (provavelmente de outro dia) |
| Tipo | VENDA | |
| Preço entrada | 181.435,0 | |
| Resultado | R$ -251,00 | |
| MFE | 19.550 pts | ⚠️ **INCORRETO** — captou o tick falso de 161.885 |
| MAE | 1.250 pts | Correto — excursão adversa real |
| Duração | ~16 min | |

### Bug no Stats: MFE incorreto
O MFE de 19.550 pts é absurdo para uma operação de 16 minutos no WIN. Isso ocorre porque:
1. O Stats calcula: `excursao = precoEntrada (181435) - precoAtual (161885) = 19550`
2. O tick falso de 161.885 inflou o MFE artificialmente
3. O Stats deveria ter um filtro de sanidade para descartar MFEs absurdos

---

## 🔮 Análise: Trailing Stop Progressivo (Proposta)

### Conceito proposto
Em vez de um Break Even fixo (que move o SL para a entrada quando lucro atinge X pontos), implementar um **Trailing Stop que sobe em patamares**:

| Lucro atingido | Novo SL (distância da entrada) |
|----------------|-------------------------------|
| +450 pts | Break Even (SL = entrada) |
| +600 pts | SL = entrada + 150 pts |
| +700 pts | SL = entrada + 300 pts |
| +760 pts | SL = entrada + 500 pts |

### Vantagens
1. **Protege lucro progressivamente** — Não é tudo ou nada como o BE atual
2. **Permite que o trade "respire"** — O SL não fica grudado na entrada
3. **Maximiza lucro em movimentos fortes** — Captura mais se o preço continuar a favor

### Análise de viabilidade no código atual

O Break Even atual está na função `GerenciarBreakEven()` (linha 778-807). A implementação atual:
```cpp
if (lucro >= breakEvenPontos) {  // Se lucro >= 300 pts
    novoSL = posicaoAtual.precoEntrada;  // Move SL para entrada
    breakEvenAtivado = true;  // Flag única, não escala mais
}
```

Para implementar o Trailing Progressivo, seria necessário:

1. **Substituir** o `breakEvenAtivado` (bool) por um `nivelTrailing` (int, 0-4)
2. **Criar array** de patamares: `{450, 600, 700, 760}` e SLs: `{0, 150, 300, 500}`
3. **No loop**, verificar se lucro atingiu o próximo patamar e mover SL progressivamente
4. **Cuidado com "invalid stops"** — O mesmo bug do Erro #2 pode impedir o trailing!

### ⚠️ Pré-requisito OBRIGATÓRIO
Antes de implementar o Trailing Stop Progressivo, é **OBRIGATÓRIO** resolver o Erro #2 (invalid stops). Sem um mecanismo de fallback quando `PositionModify()` falha, o trailing nunca funcionará de forma confiável.

---

## 🧠 Diagnóstico Consolidado

### Cadeia de falhas (cascata)

```
TICK FALSO (161.885)
    │
    ├─→ SELL_LIMIT enviada quando preço real já era ~181.435
    │       │
    │       └─→ Execução imediata a 181.435 (615 pts de slippage)
    │               │
    │               └─→ SL calculado = 181.635 (muito perto do mercado)
    │                       │
    │                       └─→ "invalid stops" x34.290 (16 min)
    │                               │
    │                               └─→ POSIÇÃO SEM PROTEÇÃO
    │                                       │
    │                                       └─→ ZERAMENTO: R$ -251
    │                                               │
    │                                               └─→ BUY_LIMIT rejeitada 3x
    │                                                       │
    │                                                       └─→ DIA PERDIDO
    │
    └─→ Stats MFE inflado (19.550 pts falso)
```

### Classificação dos bugs

| # | Bug | Severidade | Tipo | Código afetado |
|---|-----|-----------|------|----------------|
| 1 | Tick falso na abertura | 🔴 Crítica | Dados de mercado | `MonitorarNiveisEntrada()` L508 |
| 2 | Sem fallback para "invalid stops" | 🔴 Crítica | Lógica de proteção | `AjustarStopsAposExecucao()` L340 |
| 3 | Loop infinito de tentativas de modify | 🟡 Alta | Performance | `MonitorarPosicao()` L767 |
| 4 | BUY_LIMIT rejeitada sem diagnóstico | 🟡 Média | Resiliência | `ExecutarOrdemLimitada()` L622 |
| 5 | Stats MFE captura tick falso | 🟡 Baixa | Métricas | `Stats_OnTick()` L111 |
| 6 | SL fantasma no log (181.695 vs 181.635) | 🟡 Baixa | Log enganoso | `VerificarResultadoPosicao()` L812 |

---

## ✅ Recomendações de Correção (Prioridade)

### 🔴 P0 — Emergência: Mecanismo de proteção obrigatório

**Problema**: Se `PositionModify()` falha, a posição fica sem SL indefinidamente.

**Solução**: Adicionar um **"kill switch"** — após N tentativas falhas de definir SL/TP, fechar a posição a mercado imediatamente.

```
// Pseudo-código:
if (tentativasModify > MAX_TENTATIVAS_MODIFY) {
    FECHAR_POSIÇÃO_IMEDIATAMENTE();
    LOG("EMERGÊNCIA: SL/TP impossível - posição fechada por segurança");
}
```

### 🔴 P1 — Validação de tick na abertura

**Problema**: Primeiro tick pode conter preço "sujo"/stale.

**Solução**: 
- Ignorar os primeiros N ticks após abertura do mercado
- Validar que preço está dentro de ±5% do range configurado (pontoCompra2 a pontoVenda2)
- Comparar `SYMBOL_BID` com preço de abertura do dia (`iOpen`)

### 🟡 P2 — SL dinâmico quando "invalid stops"

**Problema**: SL de 200 pts pode ser menor que STOPS_LEVEL do broker.

**Solução**: 
- Capturar `SYMBOL_TRADE_STOPS_LEVEL` na inicialização
- Se SL < STOPS_LEVEL, ajustar SL para o mínimo permitido
- Se mercado já passou do SL, fechar a mercado

### 🟡 P3 — Diagnóstico do erro 10006

**Problema**: BUY_LIMIT rejeitada sem motivo claro.

**Solução**: 
- Verificar saldo/margem antes de enviar ordem
- Implementar espera progressiva entre tentativas (backoff)
- Tentar ordem a mercado como fallback (se `usarOrdemMercado` permitir)

### 🟢 P4 — Stats: Filtro de sanidade

**Problema**: MFE captura tick falso.

**Solução**: 
- Filtrar excursões maiores que TP * 2
- Desconsiderar ticks que variam mais de X% em relação ao anterior

---

## 📁 Arquivos Analisados

| Arquivo | Linhas | Status |
|---------|--------|--------|
| `dia16-03-26.pdf` | ~349.094 linhas extraídas | ✅ Analisado completamente |
| `RoboWIN_CORRIGIDO_V3.2.1.mq5` | 1.021 linhas | ✅ Analisado completamente |
| `RoboWIN_Stats.mqh` | 305 linhas | ✅ Analisado completamente |
| `Stats/trades_20260316.csv` | Não encontrado localmente | ⚠️ Salvo no FILE_COMMON do MT5 |

---

## 📌 Resumo Final

O dia 16/03/2026 foi comprometido por uma **cascata de 3 falhas** que se potencializaram:

1. **Tick falso** na abertura → entrada no preço errado
2. **SL/TP nunca definidos** → 16 minutos sem proteção → zeramento
3. **Reentrada bloqueada** → dia desperdiçado com 1 entrada restante

A causa mais **urgente** a resolver é o item #2: o robô **PRECISA** de um mecanismo de emergência quando não consegue definir SL/TP. Sem isso, qualquer falha de `PositionModify()` resulta em exposição ilimitada ao risco.

> ⚡ **Ação imediata recomendada**: Adicionar "kill switch" de N tentativas máximas antes de fechar posição automaticamente. Isso teria limitado o prejuízo a ~R$ 40 (SL programado) ou menos, em vez de R$ 251.

---

*Relatório gerado em 16/03/2026 — Análise apenas, nenhum código foi modificado.*
