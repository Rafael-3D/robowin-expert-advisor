# 📋 Análise do RoboWIN V3.2.2 — Controle de Proximidade para Ordens Pendentes

**Data:** 25/03/2026  
**Arquivo analisado:** `/home/ubuntu/Uploads/Magic.txt`  
**Versão:** RoboWIN V3.2.2  
**Status:** Apenas análise — nenhum arquivo foi modificado

---

## 1. Resumo do Problema

O RoboWIN V3.2.2 **pendura ordens BUY_LIMIT e SELL_LIMIT imediatamente**, mesmo quando o preço atual está **muito longe** dos níveis de entrada definidos (C1, C2, V1, V2). Isso causa:

- **Consumo desnecessário de margem** — a corretora reserva margem para ordens pendentes
- **Bloqueio de outros robôs** — a margem presa impede que outros EAs operem na mesma conta
- **Ordens "penduradas" sem necessidade** — ficam horas no book sem chance real de execução a curto prazo

**Exemplo do problema:** Se o preço está em 130.000 e o nível C2 (Compra 2) está em 129.200, a ordem BUY_LIMIT é colocada imediatamente em 129.200, consumindo margem por 800 pontos de distância — totalmente desnecessário.

---

## 2. Resumo da Solução Desejada

Só pendurar a ordem quando o preço estiver a **no máximo 50 pontos** do nível de entrada:

| Situação | Ação |
|---|---|
| Preço a ≤ 50 pts **acima** de C1 (Compra 1) | Pendura `BUY_LIMIT` em C1 |
| Preço a ≤ 50 pts **acima** de C2 (Compra 2) | Pendura `BUY_LIMIT` em C2 |
| Preço a ≤ 50 pts **abaixo** de V1 (Venda 1) | Pendura `SELL_LIMIT` em V1 |
| Preço a ≤ 50 pts **abaixo** de V2 (Venda 2) | Pendura `SELL_LIMIT` em V2 |
| Preço a > 50 pts de qualquer nível | **Não pendura nada** — apenas monitora |

---

## 3. Análise da Lógica Atual — `MonitorarNiveisEntrada()` (linhas 671–779)

### 3.1 Lógica de COMPRA (linhas 696–736)

```mql5
// === COMPRA ===
if (!compraExecutada && !ordemCompraPendente) {
    double nivelCompra = 0;
    if (precoAtual > pontoCompra1) {          // Preço acima de C1?
        nivelCompra = pontoCompra1;            //   → Pendura em C1
    } else if (precoAtual > pontoCompra2) {   // Preço acima de C2?
        nivelCompra = pontoCompra2;            //   → Pendura em C2
    }
    
    if (nivelCompra > 0) {
        // ENVIA ORDEM IMEDIATAMENTE — sem verificar distância!
        if (PodeEnviarOrdemCompra()) {
            ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, nivelCompra);
        }
    }
}
```

**Como decide:** Se o preço está **acima** de C1, pendura em C1. Se está entre C1 e C2, pendura em C2. A ordem é colocada **imediatamente**, não importa se o preço está 50 ou 5.000 pontos acima do nível.

### 3.2 Lógica de VENDA (linhas 738–778)

```mql5
// === VENDA ===
if (!vendaExecutada && !ordemVendaPendente) {
    double nivelVenda = 0;
    if (precoAtual < pontoVenda1) {           // Preço abaixo de V1?
        nivelVenda = pontoVenda1;              //   → Pendura em V1
    } else if (precoAtual < pontoVenda2) {    // Preço abaixo de V2?
        nivelVenda = pontoVenda2;              //   → Pendura em V2
    }
    
    if (nivelVenda > 0) {
        // ENVIA ORDEM IMEDIATAMENTE — sem verificar distância!
        if (PodeEnviarOrdemVenda()) {
            ExecutarOrdemLimitada(ORDER_TYPE_SELL_LIMIT, nivelVenda);
        }
    }
}
```

**Como decide:** Se o preço está **abaixo** de V1, pendura em V1. Se está entre V1 e V2, pendura em V2. Mesma questão — sem verificação de distância.

### 3.3 Resumo da detecção de níveis

```
         V2 ─── pontoVenda2 (mais alto)     ← SELL_LIMIT se preço < V2
         V1 ─── pontoVenda1 (mais baixo)    ← SELL_LIMIT se preço < V1
         
      (zona neutra — preço entre C1 e V1)
         
         C1 ─── pontoCompra1 (mais alto)    ← BUY_LIMIT se preço > C1
         C2 ─── pontoCompra2 (mais baixo)   ← BUY_LIMIT se preço > C2
```

A lógica de **qual nível** escolher está correta. O problema é que **não há filtro de proximidade** — a ordem é pendurada mesmo com o preço muito distante.

---

## 4. Análise da Modificação do Magic Number

O usuário adicionou filtro por Magic Number `12345` em três pontos do código:

### 4.1 Configuração no OnInit (linha 157) ✅
```mql5
trade.SetExpertMagicNumber(12345);
```
**Status:** Correto. Todas as ordens enviadas pelo `trade` serão marcadas com Magic 12345.

### 4.2 Filtro de posições no OnTick (linhas 202–210) ✅
```mql5
bool temNossaPosicao = false;
for(int i = PositionsTotal() - 1; i >= 0; i--) {
    ulong ticketPos = PositionGetTicket(i);
    if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
       PositionGetInteger(POSITION_MAGIC) == 12345) {
        temNossaPosicao = true;
        break;
    }
}
```
**Status:** Correto. Só considera posições do nosso robô (símbolo + magic 12345).

### 4.3 Filtro ao cancelar ordens pendentes (linhas 304–307) ✅
```mql5
if (OrderSelect(ticket) && 
    OrderGetString(ORDER_SYMBOL) == _Symbol && 
    OrderGetInteger(ORDER_MAGIC) == 12345) {
```
**Status:** Correto. Só cancela ordens que pertencem ao nosso robô.

### 4.4 Avaliação geral do Magic Number

| Local | Filtro aplicado? | Status |
|---|---|---|
| `OnInit` — SetExpertMagicNumber | ✅ Sim (12345) | Correto |
| `OnTick` — detecção de posição | ✅ Sim (Symbol + Magic) | Correto |
| `CancelarTodasOrdensPendentes` | ✅ Sim (Symbol + Magic) | Correto |
| `EncerrarDia` — PositionClose | ⚠️ Usa `_Symbol` sem Magic | Ver nota abaixo |
| `GerenciarTrailingStop` — PositionSelect | ⚠️ Usa `_Symbol` sem Magic | Ver nota abaixo |

> **Nota:** As funções `PositionSelect(_Symbol)`, `PositionClose(_Symbol)` e `PositionModify(_Symbol, ...)` do MQL5 selecionam a **primeira** posição do símbolo, sem filtrar por Magic Number. Se houver outro EA operando o mesmo símbolo, pode haver conflito. Porém, isso é uma limitação da API `CTrade` do MQL5 e **não** é um bug introduzido pelo usuário. Para cenários com múltiplos EAs no mesmo símbolo, seria necessário usar `PositionSelectByTicket()` — mas isso é uma otimização futura, **fora do escopo** da modificação atual.

---

## 5. Viabilidade da Implementação de Proximidade

### ✅ É totalmente viável

A modificação é **simples e cirúrgica** — envolve adicionar **uma única condição** antes de cada bloco que envia a ordem.

### 5.1 Onde adicionar

Na função `MonitorarNiveisEntrada()`, em **dois pontos específicos**:

1. **Bloco de COMPRA** (após linha 705): antes de chamar `PodeEnviarOrdemCompra()`
2. **Bloco de VENDA** (após linha 747): antes de chamar `PodeEnviarOrdemVenda()`

### 5.2 O que adicionar

Um parâmetro de input para a distância máxima e uma verificação de distância entre `precoAtual` e `nivelCompra`/`nivelVenda`.

---

## 6. Lógica Proposta (Conceitual)

### 6.1 Novo parâmetro de input

```mql5
input int distanciaMaxOrdem = 50;  // Distância máxima (pts) para pendurar ordem
```

### 6.2 Modificação na COMPRA

**Antes (atual):**
```mql5
if (nivelCompra > 0) {
    if (PodeEnviarOrdemCompra()) {
        // ... envia ordem
    }
}
```

**Depois (proposto):**
```mql5
if (nivelCompra > 0) {
    double distancia = precoAtual - nivelCompra;  // Sempre positivo (preço > nível)
    
    if (distancia <= distanciaMaxOrdem) {
        // Preço PRÓXIMO do nível — pendurar ordem
        if (PodeEnviarOrdemCompra()) {
            Print("   📏 Distância até nível: ", (int)distancia, " pts (máx: ", distanciaMaxOrdem, ")");
            // ... envia ordem
        }
    }
    // Se distancia > 50, NÃO faz nada — apenas continua monitorando
}
```

### 6.3 Modificação na VENDA

**Antes (atual):**
```mql5
if (nivelVenda > 0) {
    if (PodeEnviarOrdemVenda()) {
        // ... envia ordem
    }
}
```

**Depois (proposto):**
```mql5
if (nivelVenda > 0) {
    double distancia = nivelVenda - precoAtual;  // Sempre positivo (nível > preço)
    
    if (distancia <= distanciaMaxOrdem) {
        // Preço PRÓXIMO do nível — pendurar ordem
        if (PodeEnviarOrdemVenda()) {
            Print("   📏 Distância até nível: ", (int)distancia, " pts (máx: ", distanciaMaxOrdem, ")");
            // ... envia ordem
        }
    }
    // Se distancia > 50, NÃO faz nada — apenas continua monitorando
}
```

### 6.4 Fluxo visual

```
A cada tick:
  ├─ Calcular precoAtual
  ├─ Determinar nivelCompra (C1 ou C2)
  ├─ distancia = precoAtual - nivelCompra
  ├─ distancia <= 50?
  │   ├─ SIM → Pendurar BUY_LIMIT
  │   └─ NÃO → Não fazer nada (monitorar no próximo tick)
  │
  ├─ Determinar nivelVenda (V1 ou V2)
  ├─ distancia = nivelVenda - precoAtual
  ├─ distancia <= 50?
  │   ├─ SIM → Pendurar SELL_LIMIT
  │   └─ NÃO → Não fazer nada (monitorar no próximo tick)
```

---

## 7. Exemplo Prático

Suponha:
- C1 = 129.500, C2 = 129.000, V1 = 130.500, V2 = 131.000
- `distanciaMaxOrdem = 50`

| Preço Atual | Nível Mais Próximo | Distância | Ação |
|---|---|---|---|
| 130.200 | C1 (129.500) | 700 pts | ❌ Não pendura — muito longe |
| 129.540 | C1 (129.500) | 40 pts | ✅ Pendura BUY_LIMIT em 129.500 |
| 129.030 | C2 (129.000) | 30 pts | ✅ Pendura BUY_LIMIT em 129.000 |
| 130.480 | V1 (130.500) | 20 pts | ✅ Pendura SELL_LIMIT em 130.500 |
| 130.100 | V1 (130.500) | 400 pts | ❌ Não pendura — muito longe |
| 130.970 | V2 (131.000) | 30 pts | ✅ Pendura SELL_LIMIT em 131.000 |

---

## 8. Confirmação de Entendimento

✅ **Entendi o problema:** Ordens pendentes sendo colocadas cedo demais, consumindo margem desnecessariamente e impedindo outros robôs.

✅ **Entendi a solução:** Adicionar filtro de proximidade de 50 pontos — só pendurar a ordem quando o preço chegar perto do nível.

✅ **Entendi a arquitetura do código:** A função `MonitorarNiveisEntrada()` é o ponto exato de modificação, linhas 696–778.

✅ **A modificação do Magic Number está correta** nos 3 pontos implementados (OnInit, OnTick, CancelarTodasOrdensPendentes).

✅ **A implementação é viável e simples:** Adicionar 1 parâmetro `input` + 2 verificações de distância (uma para compra, uma para venda).

✅ **Impacto zero no restante do código:** Nenhuma outra função precisa ser alterada. O trailing stop, kill switch, verificação de margem, stats — tudo continua funcionando normalmente.

---

## 9. Próximo Passo

Quando autorizado, implementarei a modificação no código adicionando:

1. `input int distanciaMaxOrdem = 50;` nos parâmetros
2. Verificação `precoAtual - nivelCompra <= distanciaMaxOrdem` no bloco de compra
3. Verificação `nivelVenda - precoAtual <= distanciaMaxOrdem` no bloco de venda
4. Logs informativos de distância para debug

**Nenhum arquivo foi modificado nesta análise.**
