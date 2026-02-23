# Análise de Log - RoboWIN v2.00
## Data: 13/02/2026 - Conta Real

---

## 📊 RESUMO DOS PROBLEMAS

| # | Problema | Severidade | Status |
|---|----------|------------|--------|
| 1 | Ordens limitadas rejeitadas (erro 10006) | CRÍTICO | Identificado |
| 2 | Stop Loss invertido (acima da entrada em compra) | CRÍTICO | Identificado |
| 3 | Posição aberta em preço diferente do esperado | ALTO | Identificado |
| 4 | Take Profit não respeitado | ALTO | Identificado |

---

## 🔍 ANÁLISE DETALHADA

### ❌ PROBLEMA 1: Ordens Limitadas Rejeitadas (Erro 10006)

**Evidência do Log:**
```
📋 Tipo: COMPRA
📋 Preço de entrada (normalizado): 187620.0
   Preço atual: 187300.0
📤 ENVIANDO ORDEM...
   Tipo: ORDER_TYPE_BUY_LIMIT
CTrade::OrderSend: buy limit 1.00 WING26 at 187620 sl: 187420 tp: 188420 [rejected]
   Código: 10006
```

**Causa Raiz:**
O código está usando `ORDER_TYPE_BUY_LIMIT` com preço 187620 quando o preço atual é 187300.

**Regras de ordens limitadas:**
- `BUY_LIMIT`: Preço limite deve ser **ABAIXO** do preço atual (comprar quando cair)
- `SELL_LIMIT`: Preço limite deve ser **ACIMA** do preço atual (vender quando subir)

**No caso do log:**
- Preço atual: 187300
- Preço limite: 187620 (320 pontos ACIMA)
- Tipo usado: BUY_LIMIT ← **INCORRETO!**

O broker rejeita porque uma ordem BUY_LIMIT não pode ter preço acima do mercado.

**Correção:**
1. Se `preço_limite > preço_atual` → usar `ORDER_TYPE_BUY_STOP` (ou executar a mercado)
2. Se `preço_limite < preço_atual` → usar `ORDER_TYPE_BUY_LIMIT`

---

### ❌ PROBLEMA 2: Stop Loss Invertido (BUG CRÍTICO)

**Evidência do Log:**
```
║  Tipo: COMPRA
║  Preço Entrada: 187300.0
║  Take Profit: 188420.0
║  Stop Loss: 187420.0   ← 120 pontos ACIMA da entrada!
```

**Análise:**
Para uma posição de COMPRA:
- ✅ Take Profit deve estar ACIMA da entrada
- ✅ Stop Loss deve estar ABAIXO da entrada

**Valores esperados:**
- Entrada: 187300
- TP: 187300 + 800 = 188100 (correto a lógica, mas valor errado)
- SL: 187300 - 200 = **187100** (deveria ser)

**Valor real no log:**
- SL: 187420 (120 pontos ACIMA!) ← **STOP VAI SER EXECUTADO IMEDIATAMENTE!**

**Causa Raiz no Código:**
```mql5
// Na função ExecutarOrdemLimitada():
if (tipo == ORDER_TYPE_BUY_LIMIT) {
    tp = precoEntrada + takeProfitAjustado;  // OK
    sl = precoEntrada - stopLossAjustado;     // OK para preço da ordem
}
```

O problema é que `precoEntrada` = 187620 (preço da ordem limitada), não o preço real de execução.
- SL calculado: 187620 - 200 = 187420 ✓ (correto para ordem em 187620)
- Mas posição foi executada em: 187300
- SL ficou em: 187420 (120 pontos ACIMA da entrada real!)

**Isso explica o fechamento prematuro!**

---

### ❌ PROBLEMA 3: Posição Aberta em Preço Diferente

**Evidência do Log:**
```
Ordem enviada (tentativa 1): preço 187620.0 → Ticket 290600952 ✅
Ordem enviada (tentativa 2): preço 187620.0 → Código 10006 ❌
Ordem enviada (tentativa 3): preço 187620.0 → Código 10006 ❌

... (várias mensagens de máximo tentativas) ...

╔═══════════════════════════════════════════════════════════╗
║              ✅ POSIÇÃO ABERTA                            ║
║  Preço Entrada: 187300.0   ← Diferente de 187620!
```

**Análise:**
A primeira ordem foi aceita, mas como era BUY_LIMIT a um preço ACIMA do mercado, ela provavelmente:
1. Foi convertida pelo broker para execução imediata a mercado, OU
2. Havia uma ordem anterior pendente que foi executada

O MT5 aceita a ordem mas executa no preço de mercado atual quando o preço limite é inválido.

---

### ❌ PROBLEMA 4: Take Profit Não Respeitado

**Evidência do Log:**
```
║           ✅ TAKE PROFIT ATINGIDO
║  Lucro: R$ 8.00
║  Preço: 187340.0

Configurado:
- TP: 188420.0 (1120 pontos acima de 187300)
- Fechou em: 187340.0 (apenas 40 pontos acima)
```

**Causa Raiz:**
O SL de 187420 foi atingido ANTES do TP real!

**Cronologia:**
1. Posição aberta em 187300
2. SL configurado em 187420 (ACIMA da entrada - ERRO!)
3. Preço subiu para 187340
4. SL foi atingido em 187420? Não, lucro foi R$ 8.00

**Análise mais profunda:**
O lucro de R$ 8.00 com 1 contrato WIN = 8 pontos de lucro
187300 + 8 = 187308... não bate.

Na verdade, parece que a posição foi fechada por **Break Even** ou outro mecanismo.
O código detecta `profit > 0` e mostra "TAKE PROFIT ATINGIDO" incorretamente.

```mql5
// Código atual (problemático):
if (profit > 0) {
    Print("║           ✅ TAKE PROFIT ATINGIDO");
    takeProfitAtingido = true;
}
```

Qualquer lucro positivo é classificado como TP, mesmo sendo só R$ 8,00 de um movimento de 8 pontos.

---

## 🛠️ CORREÇÕES IMPLEMENTADAS NA V3

### Correção 1: Validação de Tipo de Ordem

```mql5
// ANTES (v2.00):
ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, nivelEntrada);

// DEPOIS (v3.00):
// Valida se ordem limitada é possível
double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if (tipo == ORDER_TYPE_BUY_LIMIT && precoLimite >= precoAtual) {
    Print("❌ BUY_LIMIT inválido: preço limite deve ser < preço atual");
    return false;
}
if (tipo == ORDER_TYPE_SELL_LIMIT && precoLimite <= precoAtual) {
    Print("❌ SELL_LIMIT inválido: preço limite deve ser > preço atual");
    return false;
}
```

### Correção 2: Cálculo Correto de SL

```mql5
// ANTES (v2.00): SL calculado com preço da ordem
sl = precoEntrada + stopLossAjustado;  // Para COMPRA: errado quando preço executa diferente

// DEPOIS (v3.00): Função separada para ajustar SL após execução
void AjustarStopsAposExecucao() {
    double precoReal = PositionGetDouble(POSITION_PRICE_OPEN);
    double novoSL, novoTP;
    
    if (posicaoAtual.tipo == POSITION_TYPE_BUY) {
        novoSL = precoReal - stopLoss;  // SL ABAIXO da entrada
        novoTP = precoReal + takeProfit; // TP ACIMA da entrada
    } else {
        novoSL = precoReal + stopLoss;  // SL ACIMA da entrada
        novoTP = precoReal - takeProfit; // TP ABAIXO da entrada
    }
    
    trade.PositionModify(_Symbol, novoSL, novoTP);
}
```

### Correção 3: Detecção Correta de TP/SL

```mql5
// ANTES (v2.00):
if (profit > 0) {
    Print("TAKE PROFIT ATINGIDO");  // Incorreto!
}

// DEPOIS (v3.00):
double precoFechamento = HistoryDealGetDouble(ticket, DEAL_PRICE);
double distanciaDoTP = MathAbs(precoFechamento - posicaoAtual.takeProfit);
double distanciaDoSL = MathAbs(precoFechamento - posicaoAtual.stopLoss);

if (distanciaDoTP < distanciaDoSL && profit > 0) {
    Print("✅ TAKE PROFIT ATINGIDO");
} else if (profit < 0) {
    Print("❌ STOP LOSS EXECUTADO");
} else {
    Print("⚪ FECHAMENTO MANUAL OU BREAK EVEN");
}
```

### Correção 4: Lógica de Entrada Revisada

```mql5
// ANTES (v2.00): Gatilho quando preço <= nível
if (preco <= pontoCompra1) {
    ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, pontoCompra1);
}

// DEPOIS (v3.00): Só executa se ordem limitada fizer sentido
// Para BUY_LIMIT: preço atual deve estar ACIMA do nível
// Quando preço CAIR até o nível, a ordem é executada
if (preco > pontoCompra1 && !ordemCompraPendente) {
    // Coloca ordem limitada de compra abaixo do preço atual
    ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, pontoCompra1);
}
```

---

## 📋 CHECKLIST DE VALIDAÇÕES (V3)

- [x] BUY_LIMIT só aceito se preço_limite < preço_atual
- [x] SELL_LIMIT só aceito se preço_limite > preço_atual
- [x] SL para COMPRA sempre ABAIXO da entrada
- [x] SL para VENDA sempre ACIMA da entrada
- [x] TP para COMPRA sempre ACIMA da entrada
- [x] TP para VENDA sempre ABAIXO da entrada
- [x] Ajuste de SL/TP após execução real da posição
- [x] Detecção correta de TP vs SL vs Fechamento manual
- [x] Validação de preços antes de enviar ordem

---

## 🎯 RESULTADO ESPERADO APÓS CORREÇÕES

Com as correções da V3, o comportamento esperado seria:

1. **Abertura às 09:00** - Preço atual: 187300
2. **Níveis configurados:**
   - Compra 2: 187620 (ACIMA do preço atual)
   - Compra 1: 187750 (ACIMA do preço atual)
3. **Ação correta:** Como os níveis de compra estão ACIMA do preço atual, NÃO DEVE enviar BUY_LIMIT
4. **Alternativa:** Aguardar preço subir ou usar lógica de ordem STOP

Se a intenção é comprar quando o preço SUBIR até 187620:
- Usar `ORDER_TYPE_BUY_STOP` (compra quando preço SOBE até o nível)

Se a intenção é comprar quando o preço CAIR até 187620:
- O preço atual (187300) já está ABAIXO de 187620, então a condição já foi atingida
- Deveria executar IMEDIATAMENTE a mercado

---

## 📝 RECOMENDAÇÕES

1. **Revisar a estratégia:** Definir claramente se os níveis são para:
   - Comprar na queda (BUY_LIMIT) - preço deve estar ACIMA do nível
   - Comprar na subida (BUY_STOP) - preço deve estar ABAIXO do nível

2. **Testar em conta demo** antes de operar em conta real

3. **Monitorar logs** para verificar se os SL/TP estão corretos

4. **Usar a V3** que inclui todas as validações e correções

