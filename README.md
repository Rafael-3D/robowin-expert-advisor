# 🤖 RoboWIN - Expert Advisor para MT5



\# RoboWIN V3.2.5 - Correção Trailing Stop



\## 📊 Resumo das Alterações V3.2.5



\### Problema Corrigido

A versão V3.2.4 permitia entradas não planejadas quando uma posição era fechada pelo \*\*Trailing Stop\*\*. A flag `diaEncerrado` não era setada, possibilitando uma nova entrada após o trailing stop atingir.



\### Função Modificada

\*\*`GerenciarTrailingStop()`\*\* - Função que agora \*\*encerra o dia\*\* quando o trailing stop é alcançado.



\### Mudança Técnica

Na função `GerenciarTrailingStop()`, adicionada verificação para setar `diaEncerrado = true` quando:

\- Trailing Stop atinge o novo Stop Loss calculado

\- A posição é fechada pelo SL ajustado do trailing



\### Impacto

✅ \*\*Comportamento correto\*\*: Trailing Stop agora encerra o dia (assim como TP e BE)  

✅ \*\*Segurança\*\*: Nenhuma nova entrada após trailing stop  

✅ \*\*Consistência\*\*: Todas as formas de saída com lucro respeitam a regra de máximo 2 entradas/dia



\---



\## 📈 Exemplo com Trade #2 - V3.2.4 vs V3.2.5



\### V3.2.4 (COMPORTAMENTO BUG - NÃO RECOMENDADO)



```

09:03:54 - Trade #2 iniciado | VENDA @ 178530.0

&#x20;         SL: 178730.0 | TP: 177730.0

&#x20;         

09:05:12 - 🎯 Trailing Stop Nível 1 ativado (+450 pts = 178080.0)

&#x20;         Novo SL: 178080.0

&#x20;         

09:06:45 - ✅ Trailing Stop executado! Lucro: +650 pts

&#x20;         Posição fechada.

&#x20;         

❌ BUG: diaEncerrado NÃO foi setado!

&#x20;       

09:07:00 - 🔴 NOVA ENTRADA INDESEJADA: 

&#x20;         Ordem BUY\_LIMIT colocada em 177325.0 (INCORRETO!)

&#x20;         Deveria ter encerrado o dia.

```



\### V3.2.5 (COMPORTAMENTO CORRIGIDO - ATUAL)



```

09:03:54 - Trade #2 iniciado | VENDA @ 178530.0

&#x20;         SL: 178730.0 | TP: 177730.0

&#x20;         

09:05:12 - 🎯 Trailing Stop Nível 1 ativado (+450 pts = 178080.0)

&#x20;         Novo SL: 178080.0

&#x20;         

09:06:45 - ✅ Trailing Stop executado! Lucro: +650 pts

&#x20;         Posição fechada.

&#x20;         

✅ CORRETO: diaEncerrado = true

&#x20;           

09:07:00 - ✅ DIA ENCERRADO CORRETAMENTE

&#x20;         Nenhuma nova entrada permitida.

&#x20;         Limite de 2 entradas/dia respeitado.

```



\---



\## 🔍 Resumo das Mudanças



| Aspecto | V3.2.4 | V3.2.5 |

|---------|--------|--------|

| \*\*Trailing Stop\*\* | Executa, mas não encerra dia | Executa \*\*e encerra dia\*\* |

| \*\*Após Trailing\*\* | Permite nova entrada | ✅ Bloqueia nova entrada |

| \*\*Flag diaEncerrado\*\* | Não setada | ✅ Setada quando trailing executa |

| \*\*Comportamento\*\* | Bugado | ✅ Correto |



\---



\## ✅ Validação



Para confirmar que a V3.2.5 está funcionando corretamente:



1\. Verifique os logs em MetaTrader 5

2\. Procure por: `"║  ✅ TRAILING STOP EXECUTADO E DIA ENCERRADO"`

3\. Confirme que `diaEncerrado = true` aparece no log

4\. Valide que nenhuma nova entrada é feita após trailing stop



\---



\## 📌 Notas Importantes



\- Esta é uma \*\*correção crítica\*\* recomendada para todos os usuários

\- Substitui completamente a V3.2.4

\- Mantém todas as funcionalidades: Validação de Ticks, Kill Switch, Margem, Filtro Proximidade

\- Compatível com o módulo de estatísticas `RoboWIN\_Stats.mqh`



\---



\*\*Versão\*\*: 3.25  

\*\*Data\*\*: 26/03/2026  

\*\*Status\*\*: ✅ Produção



> \*\*Versão 3.00 - Correções Críticas de Stop Loss e Validação de Ordens\*\*

[!\[MQL5](https://img.shields.io/badge/MQL5-Compatible-blue)](https://www.mql5.com/)
[!\[MT5](https://img.shields.io/badge/MetaTrader-5-green)](https://www.metatrader5.com/)
[!\[WIN](https://img.shields.io/badge/Asset-WIN-orange)](https://www.b3.com.br/)
\[!\[Version](https://img.shields.io/badge/Version-3.00-red)]()

\---

## 🚨 ATENÇÃO: USE APENAS A VERSÃO 3.00!

> ⚠️ \*\*A versão 2.00 contém BUGs CRÍTICOS que causam perdas financeiras!\*\*
>
> Se você está usando a V2.00 ou anterior, \*\*PARE IMEDIATAMENTE\*\* e atualize para V3.00.
> 
> Leia \[AVISOS\_IMPORTANTES.md](AVISOS\_IMPORTANTES.md) para detalhes.

\---

## 🚨 CORREÇÕES CRÍTICAS DA V3

### ❌ BUG 1: Stop Loss Invertido (V2.00)

**O problema mais grave da V2.00:** O Stop Loss era calculado com base no preço da ORDEM LIMITADA, não no preço REAL de execução.

```
┌─────────────────────────────────────────────────────────────┐
│  EXEMPLO DO BUG (V2.00):                                    │
├─────────────────────────────────────────────────────────────┤
│  Ordem BUY\_LIMIT configurada em: 187620                     │
│  Posição executada em: 187300 (preço de mercado)            │
│                                                             │
│  V2.00 (ERRADO):                                            │
│  ├─ SL calculado: 187620 - 200 = 187420                     │
│  └─ SL ficou 120 pontos ACIMA da entrada! 😱                │
│                                                             │
│  V3.00 (CORRETO):                                           │
│  ├─ SL recalculado: 187300 - 200 = 187100                   │
│  └─ SL corretamente ABAIXO da entrada ✅                    │
└─────────────────────────────────────────────────────────────┘
```

**Resultado da V2.00:** Stop Loss executado imediatamente após abertura da posição!

### ❌ BUG 2: Ordens Limitadas Inválidas (V2.00)

```
┌─────────────────────────────────────────────────────────────┐
│  REGRAS DE ORDENS LIMITADAS:                                │
├─────────────────────────────────────────────────────────────┤
│  BUY\_LIMIT:  Preço limite < Preço atual (comprar na queda)  │
│  SELL\_LIMIT: Preço limite > Preço atual (vender na alta)    │
├─────────────────────────────────────────────────────────────┤
│  V2.00: Enviava ordens inválidas → Erro 10006 (rejected)    │
│  V3.00: Valida ANTES de enviar → Sem rejeições              │
└─────────────────────────────────────────────────────────────┘
```

### ❌ BUG 3: Detecção Incorreta de TP/SL (V2.00)

```
┌─────────────────────────────────────────────────────────────┐
│  V2.00: if (profit > 0) → "TAKE PROFIT ATINGIDO"            │
│         Lucro de R$ 8,00 mostrava como TP atingido! ❌      │
│                                                             │
│  V3.00: Verifica proximidade real com TP/SL/BE              │
│         Detecta corretamente o motivo do fechamento ✅      │
└─────────────────────────────────────────────────────────────┘
```

\---

## 📊 Comparação V2.00 vs V3.00

|Funcionalidade|V2.00 ❌|V3.00 ✅|
|-|-|-|
|**Cálculo do Stop Loss**|Baseado no preço da ordem|Baseado no preço real de execução|
|**Validação de Ordens**|Não valida, envia inválidas|Valida antes de enviar|
|**Ajuste de SL/TP**|Na criação da ordem|Após execução da posição|
|**Detecção de TP/SL**|Qualquer lucro = TP|Verifica proximidade real|
|**Ordens Rejeitadas**|\~80% rejeitadas|\~5% rejeitadas|
|**Risco de Perda**|ALTO (SL invertido)|Controlado corretamente|

\---

## 📋 Descrição

Expert Advisor profissional para operar o **WIN (Mini-Índice Bovespa)** utilizando **ordens limitadas** para entradas precisas em níveis pré-definidos.

### ✨ Características Principais

* ✅ **Ordens Limitadas** - Entrada no preço exato, sem slippage
* ✅ **Validação Inteligente** - Só envia ordens válidas (V3)
* ✅ **SL/TP Dinâmicos** - Ajustados após execução real (V3)
* ✅ **Tick Size Automático** - Normalização para múltiplos de 5
* ✅ **Break Even Inteligente** - Proteção automática do capital
* ✅ **Gestão de Risco** - Limite de 2 stops por dia
* ✅ **Logs Detalhados** - Debug completo de todas as operações
* ✅ **Detecção Correta** - Identifica TP/SL/BE corretamente (V3)

\---

## 🚀 Instalação

### Passo 1: Download

Baixe o arquivo `RoboWIN\_CORRIGIDO\_V3.mq5` deste repositório.

> ⚠️ \*\*IMPORTANTE:\*\* Use APENAS o arquivo V3! NÃO use `RoboWIN\_CORRIGIDO.mq5` (V2.00).

### Passo 2: Copiar para MT5

Copie o arquivo para a pasta de Expert Advisors do MT5:

```
C:\\Users\\\[SeuUsuário]\\AppData\\Roaming\\MetaQuotes\\Terminal\\\[ID\_Instalação]\\MQL5\\Experts\\
```

**Atalho rápido:**

1. Abra o MetaEditor (F4 no MT5)
2. Menu: **File → Open Data Folder**
3. Navegue até `MQL5\\Experts\\`
4. Cole o arquivo `.mq5`

### Passo 3: Compilar

1. Abra o MetaEditor (F4)
2. Abra o arquivo `RoboWIN\_CORRIGIDO\_V3.mq5`
3. Pressione **F7** ou clique em **Compile**
4. Verifique se não há erros no log

\---

## ⚙️ Configuração

### Parâmetros Principais

|Parâmetro|Descrição|Exemplo|Obrigatório|
|-|-|-|-|
|**pontoCompra2**|Nível mais baixo de compra|189500|✅|
|**pontoCompra1**|Nível intermediário de compra|189700|✅|
|**pontoVenda1**|Nível intermediário de venda|190100|✅|
|**pontoVenda2**|Nível mais alto de venda|190300|✅|
|**takeProfit**|Ganho alvo em pontos|600|✅|
|**stopLoss**|Perda máxima em pontos|200|✅|
|**breakEvenPontos**|Pontos para ativar break even|350|✅|
|**contratos**|Quantidade de contratos|1|✅|
|**horaInicio**|Horário de início|"09:00"|✅|
|**horaFim**|Horário de término|"17:00"|✅|
|**validarAbertura**|Validar preço de abertura|true|❌|
|**usarOrdemMercado**|Executar a mercado se nível passou|false|❌|

### 📐 Regras de Níveis

Os níveis devem seguir esta ordem:

```
pontoCompra2 < pontoCompra1 < pontoVenda1 < pontoVenda2
```

**Exemplo válido:**

```
189500 < 189700 < 190100 < 190300
```

**❗ Importante:** Use sempre múltiplos de 5 (tick size do WIN).

\---

## 📊 Ordem Limitada vs Ordem a Mercado

### 🔄 O Parâmetro `usarOrdemMercado`

Este parâmetro controla o comportamento quando o preço **já ultrapassou** o nível da ordem limitada antes dela ser enviada.

```
input bool usarOrdemMercado = false; // Usar ordem a mercado se nível já passou
```

### ⚖️ Comparação: `false` vs `true`

|Aspecto|`usarOrdemMercado = false`|`usarOrdemMercado = true`|
|-|-|-|
|**Comportamento**|Não envia ordem|Executa a mercado|
|**Perfil**|🛡️ Conservador|⚡ Agressivo|
|**Slippage**|Nenhum|Possível|
|**Entradas**|Apenas no preço exato|Pode entrar em qualquer preço|
|**Risco**|Menor|Maior (pode entrar longe do nível)|

### 🎯 Exemplos Visuais

```
┌─────────────────────────────────────────────────────────────────┐
│  CENÁRIO: Nível de COMPRA em 187620, preço atual em 187300      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  187620 ─────────── Nível de Compra Configurado                 │
│     ↑                                                           │
│     │ 320 pts                                                   │
│     ↓                                                           │
│  187300 ─────────── Preço Atual (já passou!)                    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  usarOrdemMercado = false:                                      │
│  ├─ ❌ Ordem NÃO enviada                                        │
│  └─ 📝 Log: "Preço já passou do nível, aguardando..."           │
│                                                                 │
│  usarOrdemMercado = true:                                       │
│  ├─ ✅ COMPRA A MERCADO executada em 187300                     │
│  └─ 📝 Log: "Nível ultrapassado, executando a mercado"          │
│                                                                 │
│  ⚠️ ATENÇÃO: Entrada 320 pontos abaixo do nível planejado!      │
└─────────────────────────────────────────────────────────────────┘
```

### 📋 Quando Usar Cada Opção

#### 🛡️ `usarOrdemMercado = false` (Recomendado)

**Use quando:**

* Quer entradas APENAS no preço exato configurado
* Prefere perder uma entrada do que entrar em preço ruim
* Opera com margens apertadas de SL/TP
* É mais conservador

**Logs esperados:**

```
09:15:42 ❌ BUY\_LIMIT inválido: preço 187620 > preço atual 187300
09:15:42 📝 Aguardando preço retornar ao nível...
```

#### ⚡ `usarOrdemMercado = true` (Agressivo)

**Use quando:**

* Não quer perder nenhuma entrada
* Aceita slippage para garantir participação
* Opera com margens maiores de SL/TP
* Prefere estar posicionado do que fora do mercado

**Logs esperados:**

```
09:15:42 ⚠️ Nível 187620 já ultrapassado (atual: 187300)
09:15:42 🔄 Executando COMPRA A MERCADO...
09:15:42 ✅ Posição aberta em 187300 (320 pts abaixo do nível)
```

### ⚠️ Riscos do `usarOrdemMercado = true`

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚠️ ATENÇÃO: RISCOS DE SLIPPAGE                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. ENTRADA LONGE DO NÍVEL                                      │
│     Você pode entrar centenas de pontos longe do planejado      │
│                                                                 │
│  2. SL/TP DESPROPORCIONAIS                                      │
│     Se entrar muito abaixo do nível de compra:                  │
│     - TP fica mais longe (precisa subir mais)                   │
│     - SL fica mais perto (pode ser acionado rápido)             │
│                                                                 │
│  3. MERCADOS VOLÁTEIS                                           │
│     Em alta volatilidade, o preço pode estar muito longe        │
│     do nível quando a ordem for processada                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 💡 Recomendação

> \*\*🛡️ Para a maioria dos traders, recomendamos `usarOrdemMercado = false`\*\*
>
> Isso garante que você só entrará no preço exato planejado, mantendo sua estratégia intacta.
> 
> Use `true` apenas se você tem uma estratégia específica que exige estar sempre posicionado.

\---

## 🎯 Estratégia de Operação

### Lógica de Entrada

O robô monitora 4 níveis de preço:

```
┌─────────────────────────────────────┐
│  190300  ←─── pontoVenda2 (Venda)   │  ← Venda mais agressiva
├─────────────────────────────────────┤
│  190100  ←─── pontoVenda1 (Venda)   │
├─────────────────────────────────────┤
│         ZONA NEUTRA                 │
├─────────────────────────────────────┤
│  189700  ←─── pontoCompra1 (Compra) │
├─────────────────────────────────────┤
│  189500  ←─── pontoCompra2 (Compra) │  ← Compra mais agressiva
└─────────────────────────────────────┘
```

### Regras de Execução

1. **COMPRA** quando o preço toca:

   * `pontoCompra1` OU
   * `pontoCompra2` (entrada mais agressiva)
2. **VENDA** quando o preço toca:

   * `pontoVenda1` OU
   * `pontoVenda2` (entrada mais agressiva)
3. **Break Even** ativado quando lucro ≥ `breakEvenPontos`
4. **Encerramento** automático quando:

   * Take profit atingido ✅
   * 2 stop loss executados ❌
   * Horário de operação encerrado ⏰

\---

## 📊 Gestão de Risco (V3.00)

### Take Profit e Stop Loss - CORRIGIDO!

```mql5
Entrada REAL: 189700

COMPRA (V3.00 - CORRETO):
├─ Take Profit: 189700 + 600 = 190300 (ACIMA da entrada)
└─ Stop Loss:   189700 - 200 = 189500 (ABAIXO da entrada)

VENDA (V3.00 - CORRETO):
├─ Take Profit: 189700 - 600 = 189100 (ABAIXO da entrada)
└─ Stop Loss:   189700 + 200 = 189900 (ACIMA da entrada)
```

### Ajuste Dinâmico de Stops (NOVO na V3)

```
┌─────────────────────────────────────────────────────────────┐
│  FLUXO V3.00:                                               │
├─────────────────────────────────────────────────────────────┤
│  1. Envia ordem limitada (SL/TP provisórios)                │
│  2. Ordem é executada pelo broker                           │
│  3. Detecta preço REAL de execução                          │
│  4. Função AjustarStopsAposExecucao() recalcula SL/TP       │
│  5. SL/TP corretos são aplicados na posição                 │
└─────────────────────────────────────────────────────────────┘
```

### Break Even

Quando o lucro atingir `breakEvenPontos`, o Stop Loss é movido para o preço de entrada.

**Exemplo:**

```
Entrada COMPRA: 189700
Break Even: 350 pontos

Quando preço ≥ 190050:
→ Stop Loss movido de 189500 para 189700
```

### Limite de Perdas

* **Máximo:** 2 stop loss por dia
* Após 2 stops, o robô **encerra automaticamente**
* Evita sequências de perdas em dias desfavoráveis

\---

## 🔧 Correções Aplicadas (v3.00)

### 1\. ✅ Validação de Ordens Limitadas (NOVO)

```mql5
// V3.00 valida ANTES de enviar
double precoAtual = SymbolInfoDouble(\_Symbol, SYMBOL\_BID);

if (tipo == ORDER\_TYPE\_BUY\_LIMIT \&\& precoLimite >= precoAtual) {
    Print("❌ BUY\_LIMIT inválido: preço limite deve ser < preço atual");
    return false;
}

if (tipo == ORDER\_TYPE\_SELL\_LIMIT \&\& precoLimite <= precoAtual) {
    Print("❌ SELL\_LIMIT inválido: preço limite deve ser > preço atual");
    return false;
}
```

### 2\. ✅ Ajuste de Stops Após Execução (NOVO - CRÍTICO)

```mql5
void AjustarStopsAposExecucao() {
    double precoReal = PositionGetDouble(POSITION\_PRICE\_OPEN);
    double novoSL, novoTP;
    
    if (posicaoAtual.tipo == POSITION\_TYPE\_BUY) {
        novoSL = precoReal - stopLoss;  // SL ABAIXO da entrada
        novoTP = precoReal + takeProfit; // TP ACIMA da entrada
    } else {
        novoSL = precoReal + stopLoss;  // SL ACIMA da entrada  
        novoTP = precoReal - takeProfit; // TP ABAIXO da entrada
    }
    
    trade.PositionModify(\_Symbol, novoSL, novoTP);
    Print("✅ Stops ajustados para preço real: SL=", novoSL, " TP=", novoTP);
}
```

### 3\. ✅ Detecção Correta de Resultados (NOVO)

```mql5
// V3.00 verifica proximidade com níveis reais
double precoFechamento = HistoryDealGetDouble(ticket, DEAL\_PRICE);
double distanciaDoTP = MathAbs(precoFechamento - posicaoAtual.takeProfit);
double distanciaDoSL = MathAbs(precoFechamento - posicaoAtual.stopLoss);

if (distanciaDoTP <= 20 \&\& profit > 0) {      // Tolerância de 20 pontos
    Print("✅ TAKE PROFIT ATINGIDO");
} else if (distanciaDoSL <= 20 \&\& profit < 0) {
    Print("❌ STOP LOSS EXECUTADO");
} else if (profit >= 0) {
    Print("⚪ BREAK EVEN ou FECHAMENTO MANUAL");
}
```

### 4\. ✅ Normalização de Preços (Tick Size)

Função `NormalizarPreco()` garante que todos os preços sejam múltiplos de 5:

```mql5
189702 → 189700
189703 → 189705
189708 → 189710
```

### 5\. ✅ Validação Automática de Stops

Função `ValidarDistanciaStop()` ajusta stops automaticamente se estiverem abaixo do mínimo do broker:

```
Stop Loss configurado: 100 pontos
Mínimo do broker: 150 pontos
→ Ajustado para: 150 pontos
```

\---

## 📈 Exemplo de Operação V3.00

### Log Completo de uma Operação CORRETA

```
09:05:23 ╔═══════════════════════════════════════════════════════════╗
09:05:23 ║     ROBÔ WIN - VERSÃO CORRIGIDA COMPLETA v3.00           ║
09:05:23 ╚═══════════════════════════════════════════════════════════╝
09:05:23 📊 INFORMAÇÕES DO SÍMBOLO:
09:05:23    Símbolo: WING26
09:05:23    Tick Size: 5.0
09:05:23    Stops Level (broker): 100 pontos
09:05:23 ✅ Iniciado com ORDENS LIMITADAS (preço exato!)

09:15:42 ╔═══════════════════════════════════════════════════════════╗
09:15:42 ║         VALIDANDO ORDEM LIMITADA                          ║
09:15:42 ╚═══════════════════════════════════════════════════════════╝
09:15:42 📋 Tipo: BUY\_LIMIT
09:15:42 📋 Preço limite: 189700
09:15:42 📋 Preço atual: 189750
09:15:42 ✅ BUY\_LIMIT válido (preço limite < preço atual)

09:15:42 📤 ENVIANDO ORDEM...
09:15:42 ✅ ORDEM ENVIADA COM SUCESSO! Ticket: 123456

09:17:23 ╔═══════════════════════════════════════════════════════════╗
09:17:23 ║              ✅ POSIÇÃO ABERTA                            ║
09:17:23 ╠═══════════════════════════════════════════════════════════╣
09:17:23 ║  Preço Real de Execução: 189700                          ║
09:17:23 ╚═══════════════════════════════════════════════════════════╝

09:17:23 🔄 AJUSTANDO STOPS PARA PREÇO REAL...
09:17:23 📋 Stop Loss: 189700 - 200 = 189500 (ABAIXO da entrada ✅)
09:17:23 📋 Take Profit: 189700 + 600 = 190300 (ACIMA da entrada ✅)
09:17:23 ✅ Stops ajustados com sucesso!

09:35:18 🎯 BREAKEVEN ATIVADO (Lucro: 350 pts)
09:35:18 📋 Novo SL: 189700 (entrada)

09:42:55 ╔═══════════════════════════════════════════════════════════╗
09:42:55 ║           ✅ TAKE PROFIT ATINGIDO                        ║
09:42:55 ╠═══════════════════════════════════════════════════════════╣
09:42:55 ║  Lucro: R$ 3.000,00                                      ║
09:42:55 ║  Preço Fechamento: 190300                                ║
09:42:55 ║  Distância do TP: 0 pontos (TP real atingido)            ║
09:42:55 ╚═══════════════════════════════════════════════════════════╝
```

\---

## 🧪 Testes

### Teste em Strategy Tester

1. **Abra o MT5**
2. Pressione **Ctrl+R** (Strategy Tester)
3. Configure:

   * Expert Advisor: `RoboWIN\_CORRIGIDO\_V3`
   * Símbolo: `WING26` (ou contrato atual)
   * Período: `M1` ou `M5`
   * Datas: Últimos 30 dias
4. Clique em **Start**

### Verificar Logs V3

No **Journal** do Strategy Tester, procure por:

✅ **Sucesso V3:**

```
✅ BUY\_LIMIT válido (preço limite < preço atual)
✅ Stops ajustados para preço real
✅ TAKE PROFIT ATINGIDO (distância: 0 pts)
```

⚠️ **Validação V3:**

```
❌ BUY\_LIMIT inválido: preço limite deve ser < preço atual
🔄 Aguardando condições válidas...
```

\---

## ⚠️ Avisos Importantes

### 🚨 Por que a V3 é Essencial

|Cenário|V2.00|V3.00|
|-|-|-|
|Ordem BUY\_LIMIT com preço acima do mercado|Envia e é rejeitada|Detecta e não envia|
|Posição executada em preço diferente|SL fica invertido|SL recalculado corretamente|
|Fechamento com lucro mínimo|Mostra "TP Atingido"|Identifica corretamente|
|Risco de perda inesperada|ALTO|Controlado|

### Sobre Stops Mínimos

Diferentes brokers têm distâncias mínimas diferentes:

* Clear: \~50 pontos
* XP: \~100 pontos
* Modal: \~100 pontos

O robô **detecta e ajusta automaticamente**.

### Sobre Conta Demo

⚠️ **SEMPRE TESTE EM CONTA DEMO PRIMEIRO!**

Antes de operar com dinheiro real:

1. Teste por **pelo menos 1 semana** em demo
2. Verifique se as ordens são executadas corretamente
3. Valide os stops e take profit **após abertura da posição**
4. Confirme que os logs mostram ajustes corretos de SL/TP

\---

## 🐛 Solução de Problemas

### Problema: "Invalid stops"

**Causa:** Stops muito próximos do preço de entrada

**Solução:**

1. Aumente `stopLoss` ou `takeProfit`
2. Verifique o mínimo do seu broker nos logs
3. Use valores acima de 100 pontos para segurança

### Problema: "BUY\_LIMIT inválido"

**Causa:** Preço limite está acima do preço atual (V3 detecta e bloqueia)

**Solução:**

* Isso é comportamento CORRETO da V3
* Aguarde o preço subir acima do nível de compra
* A ordem será enviada quando válida

### Problema: Ordem não executada

**Causa:** Preço não atingiu o nível

**Solução:**

* Ordens limitadas só executam no preço exato
* Aguarde o preço tocar o nível configurado
* Verifique se há ordens pendentes no MT5

\---

## 📚 Documentação Adicional

* [**AVISOS\_IMPORTANTES.md**](AVISOS_IMPORTANTES.md) - Por que NÃO usar V2
* [**CHANGELOG.md**](CHANGELOG.md) - Histórico completo de versões
* [**ANALISE\_LOG.md**](ANALISE_LOG.md) - Análise detalhada dos bugs da V2
* [**CORRECOES\_DETALHADAS.md**](CORRECOES_DETALHADAS.md) - Detalhes técnicos

\---

## 🔄 Histórico de Versões

### v3.00 (2026-02-19) - **ATUAL** ⭐

* ✅ **CRÍTICO:** Correção do Stop Loss invertido
* ✅ Função `AjustarStopsAposExecucao()` para SL/TP corretos
* ✅ Validação de ordens limitadas antes do envio
* ✅ Detecção correta de TP/SL/BE no fechamento
* ✅ Logs aprimorados com ajustes de stops

### v2.00 (2026-02-13) - ⚠️ OBSOLETA

* ❌ **BUG CRÍTICO:** Stop Loss invertido
* ❌ Ordens limitadas inválidas rejeitadas
* ❌ Detecção incorreta de TP/SL
* ✅ Correção dos parâmetros do OrderOpen()
* ✅ Normalização de preços implementada

### v1.03 (anterior) - ❌ OBSOLETA

* ❌ Parâmetros invertidos (bug crítico)
* ❌ Sem normalização de preços
* ❌ Validação incompleta de stops

\---

## 📞 Suporte

Se encontrar problemas:

1. ✅ Verifique se está usando **V3.00**
2. ✅ Leia [AVISOS\_IMPORTANTES.md](AVISOS_IMPORTANTES.md)
3. ✅ Consulte [ANALISE\_LOG.md](ANALISE_LOG.md)
4. ✅ Verifique os logs no Journal
5. ✅ Teste em conta demo primeiro

\---

## ⭐ Características Técnicas

* **Linguagem:** MQL5
* **Plataforma:** MetaTrader 5
* **Ativo:** WIN (Mini-Índice Bovespa)
* **Tipo de Ordem:** Limitada (Limit)
* **Tick Size:** 5 pontos
* **Timeframe:** Qualquer (robô opera por preço, não por tempo)
* **Versão:** 3.00 (com correções críticas)

\---

## 📄 Licença

Este Expert Advisor é fornecido "como está", sem garantias.

**Uso por conta e risco do operador.**

\---

**🚀 Desenvolvido para operação profissional no WIN**

**⚠️ Use apenas V3.00!**

**Bons trades!** 📈

