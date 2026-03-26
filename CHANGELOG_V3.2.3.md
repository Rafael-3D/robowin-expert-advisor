# 📋 CHANGELOG - RoboWIN V3.2.3

## Data: 25/03/2026
## Base: V3.2.2 (4 Correções Urgentes)

---

### 🎯 Problema Resolvido

**Ordens pendentes sendo penduradas LONGE do preço atual.**

Na V3.2.2, assim que o preço ficava ACIMA de um nível de compra (ou ABAIXO de um nível de venda), a ordem limitada era imediatamente colocada, mesmo que o preço estivesse a milhares de pontos de distância. Isso causava:

- Ordens pendentes desnecessárias no livro
- Risco de execução em gaps sem controle
- Exposição prolongada a cenários adversos

**Exemplo do problema:**
```
Preço atual: 179.605
C1: 177.325 (distância: 2.280 pts) → V3.2.2 pendurava BUY_LIMIT ❌
V2: 178.520 (distância: 1.085 pts) → V3.2.2 pendurava SELL_LIMIT ❌
```

---

### ✅ Solução Implementada: Filtro de Proximidade

Novo parâmetro configurável `distanciaProximidade` (padrão: **50 pontos**) que controla a distância máxima para pendurar uma ordem limitada.

**Regra de COMPRA (BUY_LIMIT):**
```
Só pendura se: (PreçoAtual - NívelCompra) <= distanciaProximidade
```

**Regra de VENDA (SELL_LIMIT):**
```
Só pendura se: (NívelVenda - PreçoAtual) <= distanciaProximidade
```

**Exemplo com filtro ativo (50 pts):**
```
Preço: 179.605
C1: 177.325 (distância: 2.280 pts) → NÃO pendura (longe) ✓
V2: 178.520 (distância: 1.085 pts) → NÃO pendura (longe) ✓

Preço: 178.570
V2: 178.520 (distância: 50 pts) → PENDURA! (próximo) ✓

Preço: 177.370
C1: 177.325 (distância: 45 pts) → PENDURA! (próximo) ✓
```

---

### 📝 Modificações Detalhadas

#### 1. Novo Parâmetro Input
```cpp
input int distanciaProximidade = 50; // Distância mínima para pendurar ordem (pts)
```
- Configurável pelo usuário na aba "Inputs" do MetaTrader
- Valor padrão: 50 pontos (adequado para WIN)
- Pode ser ajustado conforme volatilidade do dia

#### 2. Função `MonitorarNiveisEntrada()` - Modificada
- **COMPRA:** Antes de atribuir `nivelCompra`, verifica se `(precoAtual - pontoCompraX) <= distanciaProximidade`
- **VENDA:** Antes de atribuir `nivelVenda`, verifica se `(pontoVendaX - precoAtual) <= distanciaProximidade`
- Se a distância for maior que o filtro, a ordem NÃO é pendurada (aguarda aproximação)
- Aplica-se a todos os 4 níveis (C1, C2, V1, V2)

#### 3. Controle de Logs
- **Logs de "aguardando aproximação":** Máximo 1x por minuto (variável estática `ultimoLogProximidade`)
- **Logs de "pendurando ordem":** Sempre exibidos (evento importante)
- **Log de status:** Atualizado para incluir informação do filtro

#### 4. Cabeçalho e Versão
- Versão atualizada para `3.23`
- Histórico no cabeçalho inclui V3.2.3
- Banner do OnInit inclui filtro de proximidade
- Comments das ordens atualizados para `WIN-V3.23`

---

### 🛡️ Funcionalidades PRESERVADAS (sem alteração)

| Funcionalidade | Status |
|---|---|
| ✅ Validação de Ticks (leilão abertura) | Mantida |
| ✅ Kill Switch SL/TP (20 tentativas) | Mantido |
| ✅ Verificação de Margem (1.5x) | Mantida |
| ✅ Trailing Stop Progressivo (4 níveis) | Mantido |
| ✅ Breakeven encerra o dia | Mantido |
| ✅ Take Profit encerra o dia | Mantido |
| ✅ Stop Loss permite nova entrada (se < 2) | Mantido |
| ✅ Reset após Stop Loss | Mantido |
| ✅ Stats Module (CSV) | Mantido |
| ✅ Magic Number: 12345 | Mantido |
| ✅ Ordem a mercado (usarOrdemMercado) | Mantida |

---

### 📊 Benefícios

1. **Menos ordens desnecessárias** no livro de ofertas
2. **Proteção contra gaps** - não fica exposto a cenários distantes
3. **Mais controle** - só entra quando o preço realmente se aproxima
4. **Configurável** - pode ajustar de 10 a 200+ pts conforme estratégia
5. **Logs limpos** - mensagens controladas (1x/min) evitam poluição

---

### 📁 Arquivos

| Arquivo | Descrição |
|---|---|
| `RoboWIN_CORRIGIDO_V3.2.3.mq5` | Código fonte V3.2.3 |
| `CHANGELOG_V3.2.3.md` | Este arquivo |
| `RoboWIN_Stats.mqh` | Módulo de estatísticas (sem alteração) |

---

### ⚠️ Recomendações

1. **Testar em conta demo** antes de usar em conta real
2. **Valor padrão (50 pts)** é conservador - adequado para WIN
3. **Se quiser mais agressivo**, reduza para 30 pts
4. **Se quiser mais conservador**, aumente para 100 pts
5. O filtro NÃO afeta ordens a mercado (usarOrdemMercado=true)
