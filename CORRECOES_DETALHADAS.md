# 🔧 Correções Aplicadas no Expert Advisor para WIN

## 📋 Resumo Executivo

Este documento detalha todas as correções aplicadas no código MQL5 do Expert Advisor para operar o mini-índice WIN no MetaTrader 5.

---

## ⭐ CORREÇÃO 1: Função `ExecutarOrdemLimitada()` - Parâmetros Invertidos

### 🔴 PROBLEMA ORIGINAL

O código enviava o preço de entrada no **4º parâmetro** quando deveria estar no **5º**:

```mql5
// ❌ CÓDIGO ERRADO (linha original)
trade.OrderOpen(_Symbol, tipo, contratos, nivelReferencia, 0, sl, tp, ...)
//                                        ↑ 4º parâmetro   ↑ 5º
```

**Resultado:** As ordens eram criadas com **preço 0**, causando rejeição pelo broker.

**Log de erro:**
```
failed sell limit 1 WING26 at 0 (190755) sl: 190955 tp: 189955
```

---

### ✅ CORREÇÃO APLICADA

```mql5
// ✅ CÓDIGO CORRIGIDO
trade.OrderOpen(
    _Symbol,              // Símbolo
    tipo,                 // Tipo (BUY_LIMIT ou SELL_LIMIT)
    contratos,            // Volume
    0,                    // ⭐ 4º parâmetro: stop_limit price (0 para ordem limitada)
    precoEntrada,         // ⭐ 5º parâmetro: price (preço de entrada)
    sl,                   // Stop Loss
    tp,                   // Take Profit
    ORDER_TIME_DAY,       // Validade
    0,                    // Expiração
    "WIN-Limitada"        // Comentário
);
```

### 📚 Documentação MT5

Segundo a [documentação oficial do OrderOpen()](https://www.mql5.com/en/docs/trading/ordersend):

```
bool OrderOpen(
    string           symbol,           // Símbolo
    ENUM_ORDER_TYPE  order_type,       // Tipo de ordem
    double           volume,           // Volume
    double           limit_price,      // Stop limit price
    double           price,            // Preço de execução
    double           sl,               // Stop Loss
    double           tp,               // Take Profit
    ...
);
```

Para ordens **LIMIT**, o parâmetro `limit_price` deve ser **0** e o `price` deve conter o preço de entrada.

---

## ⭐ CORREÇÃO 2: Nova Função `NormalizarPreco()`

### 🔴 PROBLEMA

O WIN trabalha com **tick size de 5 pontos**. Preços devem ser múltiplos de 5 (ex: 189700, 189705, 189710).

Enviar preços como 189702 ou 189703 causa rejeição.

---

### ✅ SOLUÇÃO: Função de Normalização

```mql5
double NormalizarPreco(double preco)
{
    // Arredonda para o múltiplo de 5 mais próximo
    double precoNormalizado = MathRound(preco / TICK_SIZE_WIN) * TICK_SIZE_WIN;
    
    Print("   [NORMALIZAÇÃO] ", preco, " → ", precoNormalizado);
    return precoNormalizado;
}
```

### 📊 Exemplos de Normalização

| Preço Original | Preço Normalizado |
|----------------|-------------------|
| 189702         | 189700            |
| 189703         | 189705            |
| 189708         | 189710            |
| 189712         | 189710            |
| 189713         | 189715            |

---

## ⭐ CORREÇÃO 3: Validação e Ajuste Automático de Stops

### 🔴 PROBLEMA

O broker define uma distância mínima para Stop Loss e Take Profit (`SYMBOL_TRADE_STOPS_LEVEL`).

Se SL ou TP estiverem muito próximos do preço de entrada, a ordem é rejeitada com erro **"Invalid stops"**.

---

### ✅ SOLUÇÃO: Função `ValidarDistanciaStop()`

```mql5
int ValidarDistanciaStop(int distancia, string tipoStop)
{
    // 1. Obter distância mínima do broker
    int minimoPermitido = (int)(stopsLevelBroker * tickSize);
    
    if (minimoPermitido == 0) {
        minimoPermitido = 50; // Fallback seguro para WIN
    }
    
    // 2. Garantir que seja múltiplo de 5
    minimoPermitido = (int)(MathCeil(minimoPermitido / TICK_SIZE_WIN) * TICK_SIZE_WIN);
    
    // 3. Ajustar se necessário
    if (distancia < minimoPermitido) {
        Print("⚠️ ", tipoStop, " (", distancia, " pts) abaixo do mínimo (", minimoPermitido, " pts)");
        Print("   Ajustando para: ", minimoPermitido, " pts");
        return minimoPermitido;
    }
    
    // 4. Garantir múltiplo de 5
    int distanciaNormalizada = (int)(MathRound(distancia / TICK_SIZE_WIN) * TICK_SIZE_WIN);
    
    if (distanciaNormalizada != distancia) {
        Print("⚠️ ", tipoStop, " ajustado de ", distancia, " para ", distanciaNormalizada);
    }
    
    return distanciaNormalizada;
}
```

### 📋 Processo de Validação

1. **Obter mínimo do broker** via `SYMBOL_TRADE_STOPS_LEVEL`
2. **Comparar com valores configurados** (stopLoss, takeProfit)
3. **Ajustar automaticamente** se estiver abaixo do mínimo
4. **Normalizar ao tick size** (múltiplos de 5)

---

## ⭐ CORREÇÃO 4: Informações do Símbolo em OnInit()

### ✅ ADICIONADO

No `OnInit()`, agora obtemos informações críticas do símbolo:

```mql5
// Obter informações do símbolo
tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
stopsLevelBroker = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

Print("📊 INFORMAÇÕES DO SÍMBOLO:");
Print("   Símbolo: ", _Symbol);
Print("   Tick Size: ", tickSize);
Print("   Tick Value: ", tickValue);
Print("   Stops Level (broker): ", stopsLevelBroker, " pontos");
```

### 🎯 Benefícios

- **Validação automática** de acordo com as regras do broker
- **Logs informativos** para debug
- **Adaptação dinâmica** às mudanças de configuração do símbolo

---

## ⭐ CORREÇÃO 5: Logs Detalhados para Debug

### ✅ ANTES DO ENVIO DA ORDEM

```mql5
Print("\n╔═══════════════════════════════════════════════════════════╗");
Print("║         EXECUTANDO ORDEM LIMITADA                        ║");
Print("╚═══════════════════════════════════════════════════════════╝");
Print("📋 Tipo: ", tipoStr);
Print("📋 Preço de entrada (original): ", nivelReferencia);
Print("📋 Preço de entrada (normalizado): ", precoEntrada);
Print("📋 Stop Loss: ", stopLossAjustado, " pts");
Print("📋 Take Profit: ", takeProfitAjustado, " pts");
Print("📋 Take Profit final: ", tp);
Print("📋 Stop Loss final: ", sl);
```

### ✅ VALIDAÇÃO PRÉ-ENVIO

```mql5
Print("\n🔍 VALIDAÇÃO FINAL:");
Print("   Distância TP: ", distanciaTP, " pts");
Print("   Distância SL: ", distanciaSL, " pts");
Print("   Mínimo broker: ", stopsLevelBroker, " pts");
```

### ✅ PARÂMETROS ENVIADOS

```mql5
Print("\n📤 ENVIANDO ORDEM...");
Print("   Símbolo: ", _Symbol);
Print("   Tipo: ", EnumToString(tipo));
Print("   Volume: ", contratos);
Print("   Parâmetro 4 (stop_limit): 0");
Print("   Parâmetro 5 (price): ", precoEntrada);
Print("   Stop Loss: ", sl);
Print("   Take Profit: ", tp);
```

### ✅ TRATAMENTO DE ERROS

```mql5
if (!resultado) {
    Print("\n❌ ERRO AO ENVIAR ORDEM:");
    Print("   Código: ", trade.ResultRetcode());
    Print("   Descrição: ", trade.ResultRetcodeDescription());
    Print("   Deal: ", trade.ResultDeal());
    Print("   Order: ", trade.ResultOrder());
    
    // Diagnóstico adicional
    if (trade.ResultRetcode() == 10006) {
        Print("   → Possível solução: Verificar conexão com servidor");
    } else if (trade.ResultRetcode() == 10013) {
        Print("   → Possível solução: Preço inválido ou fora do spread");
    } else if (trade.ResultRetcode() == 10016) {
        Print("   → Possível solução: Stops inválidos (muito próximos)");
    }
}
```

---

## ⭐ CORREÇÃO 6: Tipo de Preenchimento

### ✅ ADICIONADO

```mql5
trade.SetTypeFilling(ORDER_FILLING_RETURN);
```

Define o modo de preenchimento para **RETURN** (padrão para ordens limitadas no WIN).

---

## 📊 Comparação: ANTES vs DEPOIS

### ❌ CÓDIGO ORIGINAL

```mql5
// Sem normalização de preços
// Sem validação de stops
// Parâmetros invertidos
trade.OrderOpen(_Symbol, tipo, contratos, nivelReferencia, 0, sl, tp, ...)
//                                        ↑ ERRADO
```

**Resultado:**
- ❌ Ordens com preço 0
- ❌ Stops inválidos
- ❌ Rejeição pelo broker
- ❌ Logs insuficientes para debug

---

### ✅ CÓDIGO CORRIGIDO

```mql5
// 1. Normalizar preço de entrada
double precoEntrada = NormalizarPreco(nivelReferencia);

// 2. Validar e ajustar stops
int stopLossAjustado = ValidarDistanciaStop(stopLoss, "Stop Loss");
int takeProfitAjustado = ValidarDistanciaStop(takeProfit, "Take Profit");

// 3. Calcular SL e TP
double tp = NormalizarPreco(precoEntrada + takeProfitAjustado);
double sl = NormalizarPreco(precoEntrada - stopLossAjustado);

// 4. Enviar ordem com parâmetros corretos
trade.OrderOpen(_Symbol, tipo, contratos, 0, precoEntrada, sl, tp, ...)
//                                        ↑ CORRETO
```

**Resultado:**
- ✅ Preços normalizados (múltiplos de 5)
- ✅ Stops validados automaticamente
- ✅ Parâmetros na ordem correta
- ✅ Logs detalhados para debug
- ✅ Ordens aceitas pelo broker

---

## 🎯 Principais Mudanças no Fluxo de Execução

### ANTES

1. Detectar nível de entrada
2. Calcular SL e TP (sem validação)
3. Enviar ordem ❌ (parâmetros errados)
4. Ordem rejeitada

### DEPOIS

1. Detectar nível de entrada
2. **Normalizar preço ao tick size**
3. **Validar stops contra mínimo do broker**
4. **Ajustar stops automaticamente se necessário**
5. Calcular SL e TP
6. **Normalizar SL e TP ao tick size**
7. **Validar distâncias finais**
8. **Enviar ordem com parâmetros corretos** ✅
9. Ordem aceita

---

## 📈 Códigos de Erro Comuns e Soluções

| Código | Descrição | Solução Aplicada |
|--------|-----------|------------------|
| 10013  | Invalid price | ✅ Normalização de preços ao tick size |
| 10016  | Invalid stops | ✅ Validação e ajuste automático de distâncias |
| 10030  | Invalid volume | ⚠️ Verificar contratos configurados |
| 10006  | Request rejected | ⚠️ Verificar conexão com servidor |

---

## 🔍 Como Testar as Correções

### 1. Compilar o Código

No MetaEditor:
- Abrir `RoboWIN_CORRIGIDO.mq5`
- Pressionar F7 ou clicar em "Compile"
- Verificar se não há erros

### 2. Configurar no Strategy Tester

- Símbolo: **WING26** (ou ativo WIN atual)
- Período: **M1** ou **M5**
- Modo: **Every tick** ou **1 minute OHLC**
- Datas: Período recente com volume

### 3. Parâmetros Recomendados para Teste

```
pontoCompra1: 189700
pontoCompra2: 189500
pontoVenda1: 190100
pontoVenda2: 190300
takeProfit: 600
stopLoss: 200
breakEvenPontos: 350
contratos: 1
horaInicio: "09:00"
horaFim: "17:00"
validarAbertura: false (para testes)
```

### 4. Verificar Logs

No Journal do Strategy Tester, procurar por:

✅ **Sinais de sucesso:**
```
✅ Ordem enviada com sucesso!
✅ POSIÇÃO ABERTA em 189700
✅ TAKE PROFIT ATINGIDO
```

❌ **Sinais de erro:**
```
❌ ERRO AO ENVIAR ORDEM: [código]
⚠️ Stop Loss abaixo do mínimo
```

---

## 📝 Checklist de Validação

- [x] Função `NormalizarPreco()` implementada
- [x] Função `ValidarDistanciaStop()` implementada
- [x] Parâmetros do `OrderOpen()` corrigidos (4º e 5º invertidos)
- [x] Tick size do WIN (5 pontos) respeitado
- [x] Validação de `SYMBOL_TRADE_STOPS_LEVEL` implementada
- [x] Logs detalhados antes/depois do envio
- [x] Tratamento de erros com códigos específicos
- [x] Break even normalizado ao tick size
- [x] Tipo de preenchimento configurado

---

## 🚀 Próximos Passos

1. **Testar em conta demo** antes de operar com dinheiro real
2. **Validar stops** de acordo com seu broker (mínimos podem variar)
3. **Ajustar parâmetros** de acordo com sua estratégia
4. **Monitorar logs** nas primeiras operações
5. **Verificar execuções** nos preços exatos definidos

---

## ⚠️ Avisos Importantes

### Sobre Stops Mínimos

Diferentes brokers têm **distâncias mínimas diferentes**:
- Alguns exigem 50 pontos
- Outros exigem 100 pontos
- O código se adapta automaticamente

Se seus stops configurados estiverem abaixo do mínimo, o robô **ajustará automaticamente** e registrará no log.

### Sobre Tick Size

O WIN opera com **tick size de 5 pontos**. Preços devem sempre ser múltiplos de 5:
- ✅ 189700, 189705, 189710
- ❌ 189702, 189703, 189708

O código **normaliza automaticamente**, mas é recomendado configurar os níveis já como múltiplos de 5.

### Sobre Horário de Operação

O horário padrão configurado é 09:00 às 12:00. Ajuste conforme sua estratégia e evite:
- Primeiros 5 minutos após abertura (volatilidade)
- Últimos 15 minutos antes do fechamento (pouca liquidez)

---

## 📞 Suporte Técnico

Se ainda encontrar erros após aplicar as correções:

1. **Verifique os logs** no Journal
2. **Copie o código do erro** (ex: 10016)
3. **Verifique se os níveis são múltiplos de 5**
4. **Confirme distâncias mínimas** com seu broker
5. **Teste primeiro em conta demo**

---

## 📜 Histórico de Versões

### v2.00 (2026-02-13) - **VERSÃO ATUAL**
✅ Correção dos parâmetros do `OrderOpen()`  
✅ Implementação de `NormalizarPreco()`  
✅ Implementação de `ValidarDistanciaStop()`  
✅ Logs detalhados adicionados  
✅ Validação automática de stops  

### v1.03 (anterior)
❌ Parâmetros invertidos  
❌ Sem normalização de preços  
❌ Validação incompleta de stops  

---

## 🎓 Referências

- [Documentação OrderOpen() - MQL5](https://www.mql5.com/en/docs/trading/ordersend)
- [Tipos de Ordens - MetaTrader 5](https://www.mql5.com/en/docs/constants/tradingconstants/orderproperties#enum_order_type)
- [Informações do Símbolo - MQL5](https://www.mql5.com/en/docs/marketinformation/symbolinfodouble)
- [Códigos de Erro - MQL5](https://www.mql5.com/en/docs/constants/errorswarnings/enum_trade_return_codes)

---

**Desenvolvido para operação segura e precisa no WIN** 🎯
