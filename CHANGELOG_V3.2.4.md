# 📋 CHANGELOG - RoboWIN V3.2.4

## 🗓️ Data: 25/03/2026

## 📌 Resumo
**V3.2.4: Otimização de Logs (Terminal Limpo)**

Versão focada em reduzir a poluição do terminal do MetaTrader 5, removendo logs periódicos desnecessários e tornando-os opcionais via parâmetro de debug.

---

## 🐛 Problema Resolvido

### Log de status poluindo o terminal (~180x por dia)
Na V3.2.3, a função `MonitorarNiveisEntrada()` gerava um log a cada 60 segundos:

```
📊 Status: Compra=aguardando | Venda=aguardando | Stops: 0/2 | Preço: 186465.0 | Mercado: OK | Filtro: 50pts
```

**Impacto:**
- ~180 mensagens de status por dia de operação (3h × 60 min/h)
- Logs de "aguardando aproximação" adicionais (~180x por dia)
- **Total estimado: ~360 linhas desnecessárias/dia**
- Dificuldade para encontrar logs importantes (ordens, erros, trailing)

---

## ✅ Solução Implementada (Opção 1 + 3)

### 1. Novo parâmetro input
```cpp
input bool logStatusAtivo = false;  // ⭐ V3.2.4: Ativar log de status periódico (debug)
```
- **Padrão: `false`** (terminal limpo)
- Quando `true`: mostra logs de status e proximidade (para debug)

### 2. Log de status periódico → condicional
**ANTES (V3.2.3):**
```cpp
// Log de status (apenas a cada minuto para não poluir)
static datetime ultimoLogStatus = 0;
if (TimeCurrent() - ultimoLogStatus > 60) {
    Print("📊 Status: ...");
    ultimoLogStatus = TimeCurrent();
}
```

**DEPOIS (V3.2.4):**
```cpp
// ⭐ V3.2.4: Log de status periódico (apenas se ativado para debug)
if (logStatusAtivo) {
    static datetime ultimoLogStatus = 0;
    if (TimeCurrent() - ultimoLogStatus > 60) {
        Print("📊 Status: ...");
        ultimoLogStatus = TimeCurrent();
    }
}
```

### 3. Logs de "aguardando aproximação" → condicional
**ANTES (V3.2.3):**
```cpp
if (podeLogarProximidade) {
    Print("⏳ Aguardando aproximação de C1...");
    ultimoLogProximidade = TimeCurrent();
}
```

**DEPOIS (V3.2.4):**
```cpp
if (logStatusAtivo && podeLogarProximidade) {
    Print("⏳ Aguardando aproximação de C1...");
    ultimoLogProximidade = TimeCurrent();
}
```

### 4. Logs de "pendurando ordem" → SEMPRE mostrar ✅
```cpp
Print("📍 Preço próximo de C1 - Pendurando BUY_LIMIT");  // Sempre visível (evento importante)
```

---

## 📊 Comparação Antes/Depois

| Tipo de Log | V3.2.3 | V3.2.4 (padrão) | V3.2.4 (debug) |
|---|---|---|---|
| 📊 Status periódico | ✅ 1x/min (~180/dia) | ❌ Desativado | ✅ 1x/min |
| ⏳ Aguardando aproximação | ✅ 1x/min (~180/dia) | ❌ Desativado | ✅ 1x/min |
| 📍 Pendurando ordem | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| ✅ Posição aberta | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| 📈 Trailing stop | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| ❌ Stop Loss | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| ✅ Take Profit | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| ⚪ Breakeven | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| ❌ Erros/Avisos | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| 🚨 Kill Switch | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| 🟢 Inicialização | ✅ Sempre | ✅ Sempre | ✅ Sempre |
| 🔴 Encerramento | ✅ Sempre | ✅ Sempre | ✅ Sempre |

**Redução estimada: ~360 linhas/dia no modo padrão** 🎯

---

## 🔧 Como Ativar o Debug

### No MetaTrader 5:
1. Abrir as propriedades do Expert Advisor (ícone de engrenagem no gráfico)
2. Aba **"Entradas"**
3. Encontrar **`logStatusAtivo`**
4. Mudar de `false` para `true`
5. Clicar **OK**

### Quando usar debug:
- 🔍 Investigar por que uma ordem não foi pendurada
- 🔍 Verificar se o preço está se aproximando dos níveis
- 🔍 Confirmar que o mercado estabilizou após abertura
- 🔍 Diagnosticar comportamento inesperado

### Quando desativar (padrão):
- ✅ Operação normal do dia-a-dia
- ✅ Quando o robô já está funcionando corretamente
- ✅ Para manter o terminal limpo e focado em eventos relevantes

---

## 🛡️ Funcionalidades Preservadas (100%)

Todas as funcionalidades da V3.2.3 foram mantidas sem alteração:

- ✅ Filtro de Proximidade (50 pts padrão)
- ✅ Validação de Ticks (ignora leilão de abertura)
- ✅ Kill Switch SL/TP (fecha após 20 falhas)
- ✅ Verificação de Margem (1.5x segurança)
- ✅ Trailing Stop Progressivo (4 níveis: BE→+150→+300→+500)
- ✅ Breakeven encerra o dia
- ✅ Take Profit encerra o dia
- ✅ Stop Loss permite nova entrada (se < 2)
- ✅ Magic Number 12345
- ✅ Módulo de Estatísticas (Stats)
- ✅ Ordem a mercado (opcional)

---

## 📁 Arquivos

| Arquivo | Descrição |
|---|---|
| `RoboWIN_CORRIGIDO_V3.2.4.mq5` | Código fonte V3.2.4 |
| `CHANGELOG_V3.2.4.md` | Este documento |
| `RoboWIN_CORRIGIDO_V3.2.3.mq5` | Versão anterior (referência) |

---

## ⚠️ Recomendações

1. **Testar em conta DEMO** antes de usar em conta real
2. **Manter `logStatusAtivo = false`** para operação normal
3. **Ativar debug temporariamente** apenas para diagnóstico
4. **Lembrar de desativar** o debug após investigação
