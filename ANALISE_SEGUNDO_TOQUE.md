# 🔍 Análise: Por que o Trade só Executa no Segundo Toque do Preço?

**Data da análise:** 17 de março de 2026  
**Arquivos analisados:**
- `RoboWIN_CORRIGIDO_V3.2.1.mq5` (1021 linhas)
- `RoboWIN_CORRIGIDO_V3.2.2.mq5` (1294 linhas)

---

## 📋 Resumo Executivo

**O robô NÃO executa no primeiro toque do preço devido a uma característica estrutural do design: ele utiliza ORDENS LIMITADAS (BUY_LIMIT / SELL_LIMIT).** Uma ordem limitada só pode ser posicionada quando o preço atual está **do lado oposto** ao nível desejado. Isso cria um ciclo natural de "dois toques":

1. **Primeiro toque** → preço chega ao nível, mas a ordem ainda não existe (não podia ser criada antes)
2. **Preço se afasta** → agora o robô consegue posicionar a ordem limitada
3. **Segundo toque** → preço retorna ao nível e a ordem pendente é executada

Este comportamento existe **igualmente** nas versões V3.2.1 e V3.2.2. A V3.2.2 pode **agravar** o problema com a validação de 10 ticks de estabilização.

---

## 🧠 Análise Detalhada

### 1. A Lógica de `MonitorarNiveisEntrada()` — A Causa Raiz

A função `MonitorarNiveisEntrada()` determina **quando** colocar uma ordem. Vejamos a lógica de compra (idêntica em ambas versões):

```mq5
// === COMPRA === (V3.2.1 linhas 521-548 / V3.2.2 linhas 683-722)
if (!compraExecutada && !ordemCompraPendente) {
    double nivelCompra = 0;
    if (precoAtual > pontoCompra1) {          // ⚠️ CONDIÇÃO-CHAVE #1
        nivelCompra = pontoCompra1;
    } else if (precoAtual > pontoCompra2) {   // ⚠️ CONDIÇÃO-CHAVE #2
        nivelCompra = pontoCompra2;
    }
    
    if (nivelCompra > 0) {
        // ... posicionar ordem BUY_LIMIT no nivelCompra
    }
}
```

#### ⚠️ O que estas condições significam na prática:

| Condição | Significado | Quando é verdadeira |
|----------|-------------|---------------------|
| `precoAtual > pontoCompra1` | Preço está **ACIMA** do nível de compra 1 | Preço ainda NÃO tocou o nível |
| `precoAtual > pontoCompra2` | Preço está **ACIMA** do nível de compra 2 | Preço ainda NÃO tocou o nível |

**O robô só posiciona a ordem quando o preço está ACIMA do nível.** Se o preço já está NO nível ou ABAIXO dele, `nivelCompra` fica `0` e nenhuma ordem é criada.

A mesma lógica se aplica à venda (invertida):

```mq5
// === VENDA ===
if (precoAtual < pontoVenda1) {     // Preço ABAIXO do nível → posicionar SELL_LIMIT
    nivelVenda = pontoVenda1;
} else if (precoAtual < pontoVenda2) {
    nivelVenda = pontoVenda2;
}
```

---

### 2. A Validação de `ExecutarOrdemLimitada()` — O Segundo Bloqueio

Mesmo que `MonitorarNiveisEntrada()` tentasse colocar a ordem quando o preço está no nível, `ExecutarOrdemLimitada()` tem uma **segunda barreira** de proteção (idêntica em ambas versões):

```mq5
// V3.2.1 linhas 632-646 / V3.2.2 linhas 817-831
if (tipo == ORDER_TYPE_BUY_LIMIT) {
    if (precoLimite >= precoAtual) {    // ⚠️ REJEITA se preço limite >= preço atual
        Print("❌ ERRO: BUY_LIMIT inválido! Preço limite >= Preço atual");
        tentativasCompra++;              // ⚠️ E ainda gasta uma tentativa!
        ultimaTentativaCompra = TimeCurrent();
        return false;
    }
} else if (tipo == ORDER_TYPE_SELL_LIMIT) {
    if (precoLimite <= precoAtual) {    // ⚠️ REJEITA se preço limite <= preço atual
        Print("❌ ERRO: SELL_LIMIT inválido! Preço limite <= Preço atual");
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
        return false;
    }
}
```

#### Regras do MetaTrader 5 para ordens limitadas:
- **BUY_LIMIT**: o preço da ordem **deve ser menor** que o preço atual (comprar abaixo do mercado)
- **SELL_LIMIT**: o preço da ordem **deve ser maior** que o preço atual (vender acima do mercado)

Isso é uma **regra do próprio MetaTrader**, não apenas do robô. Quando o preço já está NO nível ou passou dele, uma ordem limitada **é impossível**.

---

### 3. Diagrama do Ciclo de Dois Toques

Exemplo para **COMPRA** no nível 130.000:

```
Preço
  ↑
131.000 ─── ① Robô ATIVO: precoAtual(131.000) > pontoCompra1(130.000) ✓
  │              → Coloca BUY_LIMIT em 130.000
  │
130.500 ─── Ordem pendente esperando...
  │
130.000 ═══ ② SEGUNDO TOQUE: Preço atinge 130.000
  │              → BUY_LIMIT executada automaticamente pelo MetaTrader ✅
  │
  │         ─── MAS NO CENÁRIO DO "PRIMEIRO TOQUE":
  │
130.000 ═══ ① PRIMEIRO TOQUE: Preço chega a 130.000
  │              → precoAtual(130.000) > pontoCompra1(130.000) → FALSO (é igual, não maior)
  │              → nivelCompra = 0 → NENHUMA ordem criada ❌
  │
130.500 ─── Preço sobe de volta (se afasta)
  │              → Agora precoAtual(130.500) > pontoCompra1(130.000) → VERDADEIRO ✓
  │              → BUY_LIMIT posicionada em 130.000
  │
130.000 ═══ ② SEGUNDO TOQUE: Preço retorna a 130.000
  │              → Ordem executada ✅
  ↓
```

---

### 4. Fatores Agravantes — Controle de Tentativas

O sistema tem um **limite de 3 tentativas** com **delay de 3 segundos** entre cada:

```mq5
// Ambas versões
const int MAX_TENTATIVAS = 3;
const int DELAY_ENTRE_TENTATIVAS = 3;  // segundos

bool PodeEnviarOrdemCompra()
{
    if (TimeCurrent() - ultimaTentativaCompra < DELAY_ENTRE_TENTATIVAS) return false;  // ⚠️ Delay
    if (tentativasCompra >= MAX_TENTATIVAS) {                                          // ⚠️ Limite
        return false;
    }
    return true;
}
```

**Problema combinado:** Se o preço oscila rapidamente no nível e a validação de `ExecutarOrdemLimitada()` rejeita a ordem (porque `precoLimite >= precoAtual`), cada rejeição:
1. **Gasta uma tentativa** (`tentativasCompra++`)
2. **Impõe um delay de 3 segundos** (`ultimaTentativaCompra = TimeCurrent()`)

Com o mercado WIN se movendo rápido, **3 tentativas podem se esgotar em 9 segundos** sem nunca conseguir posicionar a ordem.

---

### 5. O Parâmetro `usarOrdemMercado` — A Solução Parcial Existente (mas desligada)

O robô já possui uma solução parcial para o primeiro toque, **mas está desativada por padrão**:

```mq5
input bool usarOrdemMercado = false;  // ⚠️ DESLIGADO por padrão

// Na MonitorarNiveisEntrada():
else if (precoAtual <= pontoCompra1 && usarOrdemMercado) {
    Print("⚠️ Preço já está ABAIXO/IGUAL ao nível de compra");
    Print("   Executando ordem a MERCADO...");
    ExecutarOrdemMercado(ORDER_TYPE_BUY);
}
```

Com `usarOrdemMercado = true`, quando o preço **já está no nível ou abaixo**, o robô envia uma **ordem a mercado** em vez de tentar uma ordem limitada impossível. Isso resolveria o primeiro toque, **mas com o risco de slippage** (execução em preço diferente do desejado).

---

## 🆚 Comparação V3.2.1 vs V3.2.2

### O que é IDÊNTICO (não mudou):

| Aspecto | V3.2.1 | V3.2.2 |
|---------|--------|--------|
| Lógica de `MonitorarNiveisEntrada()` para detecção de nível | `precoAtual > pontoCompra1` | **Idêntico** |
| Validação em `ExecutarOrdemLimitada()` | `precoLimite >= precoAtual` rejeita | **Idêntico** |
| Limite de tentativas | 3 tentativas, delay 3s | **Idêntico** |
| Parâmetro `usarOrdemMercado` | `false` por padrão | **Idêntico** |
| Problema do segundo toque | **SIM** | **SIM** |

### O que MUDOU na V3.2.2 (e agrava o problema):

#### 🆕 Correção #1: Validação de Ticks do Leilão (V3.2.2, linhas 578-625)

```mq5
// V3.2.2 — NOVO em MonitorarNiveisEntrada():
if (!ValidarTickMercado()) {
    return;  // ⚠️ BLOQUEIO ADICIONAL: ignora os primeiros 10 ticks
}
```

A V3.2.2 adicionou `ValidarTickMercado()` que **ignora os primeiros 10 ticks válidos após 09:00**:

```mq5
bool ValidarTickMercado()
{
    if (mercadoEstabilizado) return true;
    
    // Ignora ticks antes das 09:00
    if (agora.hour < 9) return false;
    
    // Ignora ticks com preço fora do range razoável
    if (precoAtual < limiteInferior || precoAtual > limiteSuperior) return false;
    
    ticksValidosApos09++;
    if (ticksValidosApos09 < TICKS_PARA_ESTABILIZAR) {  // TICKS_PARA_ESTABILIZAR = 10
        return false;  // ⚠️ Ainda não estabilizou — ignora o tick
    }
    
    mercadoEstabilizado = true;
    return true;
}
```

**Impacto:** Se o preço atingir o nível de entrada nos **primeiros 10 ticks do dia**, a V3.2.2 **ignora completamente**, mesmo que fosse uma oportunidade válida. Isso **adiciona mais um motivo** para perder o primeiro toque.

#### 🆕 Correção #3: Verificação de Margem (V3.2.2, linhas 631-653)

```mq5
// Antes de enviar qualquer ordem:
if (!VerificarMargemDisponivel(contratos)) {
    Print("❌ Ordem não enviada - margem insuficiente");
    return;  // ⚠️ Mais um bloqueio potencial
}
```

Embora esta seja uma verificação sensata, é **mais um ponto de bloqueio** que pode impedir a execução no primeiro toque.

---

## 📊 Resumo dos Bloqueios que Impedem Execução no Primeiro Toque

| # | Bloqueio | V3.2.1 | V3.2.2 | Impacto |
|---|----------|--------|--------|---------|
| 1 | `precoAtual > nível` exigido em `MonitorarNiveisEntrada()` | ✅ | ✅ | **CAUSA RAIZ** — não posiciona ordem quando preço está no nível |
| 2 | `precoLimite >= precoAtual` rejeita em `ExecutarOrdemLimitada()` | ✅ | ✅ | Reforça bloqueio #1 e gasta tentativas |
| 3 | Limite de 3 tentativas com delay de 3s | ✅ | ✅ | Esgota tentativas rapidamente em mercado volátil |
| 4 | `usarOrdemMercado = false` por padrão | ✅ | ✅ | Solução existente mas desativada |
| 5 | Validação de 10 ticks de estabilização | ❌ | ✅ | **NOVO** — ignora primeiro toque se for nos primeiros ticks |
| 6 | Verificação de margem | ❌ | ✅ | **NOVO** — pode bloquear se margem estiver apertada |

---

## 🎯 Conclusão

### Por que o trade só executa no segundo toque?

**Porque o design usa ordens limitadas (BUY_LIMIT/SELL_LIMIT), que por natureza requerem que o preço esteja do lado oposto ao nível desejado ANTES de o preço chegar ao nível.** Quando o preço toca o nível pela primeira vez, o robô ainda não teve a oportunidade de posicionar a ordem, pois a condição `precoAtual > pontoCompra` (ou `precoAtual < pontoVenda`) precisa ser verdadeira ANTES do toque.

### Isso é um bug ou é por design?

É uma **consequência do design**, não um bug acidental. Ordens limitadas são o tipo de ordem mais adequado para entrar em um preço específico (sem slippage), mas inerentemente exigem que a ordem seja posicionada ANTES do preço chegar ao nível. O parâmetro `usarOrdemMercado` existe justamente como alternativa, mas está desligado por padrão para evitar slippage.

### A V3.2.2 piorou esse comportamento?

**Sim, marginalmente.** A validação de 10 ticks de estabilização (Correção #1) pode fazer o robô perder oportunidades nos primeiros segundos de negociação, quando frequentemente ocorrem movimentos rápidos de ida e volta nos níveis de preço.

---

*Relatório gerado automaticamente — Apenas análise, nenhuma alteração no código foi realizada.*
