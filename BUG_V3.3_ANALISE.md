# 🐛 Análise do Bug V3.3 - RoboWIN

**Data:** 27/02/2026  
**Versão com Bug:** V3.3  
**Versão Estável:** V3.2  
**Nova Versão:** V3.2.1 (V3.2 + Stats)

---

## 📋 Resumo Executivo

A V3.3 foi rejeitada devido a um bug crítico que causou preços incorretos nas ordens de compra, tornando o robô inoperante durante todo o pregão de 27/02/2026.

---

## 🔍 Problema Identificado

### Sintoma Principal
```
Preço configurado pelo usuário: 193950.0 (Compra 2)
Preço enviado na ordem:         19395.0  ❌ ERRO!

Resultado: Erro 10006 - rejected (preço inválido)
```

### Log do Usuário (09:00:00 - 27/02/2026)
```
✅ Parâmetros válidos:
   Compra 2: 19395.0 (nível mais baixo)    ❌ FALTA UM DÍGITO!
   Compra 1: 194105.0 (nível mais alto)    ✅ OK
   Venda 1: 195165.0 (nível mais baixo)    ✅ OK
   Venda 2: 195300.0 (nível mais alto)     ✅ OK
```

### Impacto
- **Ordem de compra:** Rejeitada continuamente (preço 19395.0 é inválido)
- **Ordem de venda:** Colocada corretamente em 195165.0 (ficou pendente)
- **Resultado:** Robô inoperante o dia todo
- **Oportunidade perdida:** Preço chegou em 193975 mas ordem estava em preço errado

---

## 🔬 Causa Raiz

A V3.3 introduziu mudanças para validação de slippage/GAP que inadvertidamente afetaram a leitura ou armazenamento dos parâmetros de entrada.

### Possíveis Causas Técnicas

1. **Bug na leitura de parâmetros de entrada**
   - O parâmetro `pontoCompra2` foi lido incorretamente
   - Possível truncamento ou erro de conversão de tipo

2. **Conflito com novos parâmetros da V3.3**
   - A V3.3 adicionou `toleranciaExecucao` como novo input
   - Possível desalinhamento na memória de parâmetros

3. **Erro de armazenamento de preço original**
   - Variáveis `precoOrdemCompraPendente` e `precoOrdemVendaPendente` foram adicionadas
   - Possível sobrescrita ou corrupção de valores

### Código Suspeito na V3.3
```cpp
// V3.3 adicionou estas variáveis (linhas 46-48)
double precoOrdemCompraPendente = 0.0;
double precoOrdemVendaPendente = 0.0;

// E este novo parâmetro de entrada (linha 29)
input int toleranciaExecucao = 20;  // ⭐ V3.3: Tolerância máxima de slippage
```

---

## 📊 Comparação de Versões

| Aspecto | V3.2 (Estável) | V3.3 (Bug) | V3.2.1 (Nova) |
|---------|----------------|------------|---------------|
| Leitura de preços | ✅ OK | ❌ Bug | ✅ OK |
| Normalização | ✅ OK | ✅ OK | ✅ OK |
| Validação de GAP | ❌ Não tem | ✅ Tem | ❌ Não tem |
| Módulo Stats | ❌ Não tem | ✅ Tem | ✅ Tem |
| Armazena preço original | ❌ Não | ✅ Sim | ❌ Não |
| Estabilidade | ✅ Estável | ❌ Instável | ✅ Estável |

---

## 💡 Solução Implementada

### V3.2.1 = V3.2 (base estável) + Stats (apenas)

1. **Base:** Código da V3.2 (última versão funcional)
2. **Adição:** Apenas 4 linhas para integração do módulo Stats
3. **Exclusão:** Toda a lógica de validação de GAP/slippage da V3.3

### Linhas Adicionadas na V3.2.1
```cpp
// Linha 15: Include do módulo Stats
#include "RoboWIN_Stats.mqh"

// Em RegistrarNovaPosicao() - após detectar posição:
Stats_OnOpen(posicaoAtual.precoEntrada, posicaoAtual.tipo);

// Em OnTick() - se posição aberta:
Stats_OnTick();

// Em VerificarResultadoPosicao() - ao fechar:
Stats_OnClose(profit, motivo);
```

### Correção de Logs Excessivos
```cpp
// V3.2.1: Log de limite de tentativas apenas UMA VEZ
bool jaLogouLimiteCompra = false;
bool jaLogouLimiteVenda = false;

// Na função PodeEnviarOrdemCompra():
if (!jaLogouLimiteCompra) {
    Print("⚠️ Máximo de tentativas de COMPRA atingido...");
    jaLogouLimiteCompra = true;
}
```

---

## ✅ Validações na V3.2.1

### Parâmetros do Usuário
- **Compra 1:** 194105.0 ✅
- **Compra 2:** 193950.0 ✅
- **Venda 1:** 195165.0 ✅
- **Venda 2:** 195300.0 ✅

### Normalização de Preços
```cpp
// Função NormalizarPreco() - IDÊNTICA à V3.2
double NormalizarPreco(double preco)
{
    double precoNormalizado = MathRound(preco / TICK_SIZE_WIN) * TICK_SIZE_WIN;
    return precoNormalizado;
}

// Exemplos:
// 194105.0 → 194105.0 (já múltiplo de 5)
// 193950.0 → 193950.0 (já múltiplo de 5)
// 193952.0 → 193950.0 (arredondado)
// 193953.0 → 193955.0 (arredondado)
```

---

## 📁 Arquivos Relacionados

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `RoboWIN_CORRIGIDO_V3.2.mq5` | Última versão estável | ✅ Base |
| `RoboWIN_CORRIGIDO_V3.3.mq5` | Versão com bug | ❌ Rejeitada |
| `RoboWIN_CORRIGIDO_V3.2.1.mq5` | Nova versão estável | ✅ **USAR ESTA** |
| `RoboWIN_Stats.mqh` | Módulo de estatísticas | ✅ Mantido |

---

## 🚀 Recomendações

1. **USAR:** `RoboWIN_CORRIGIDO_V3.2.1.mq5`
2. **EVITAR:** `RoboWIN_CORRIGIDO_V3.3.mq5`
3. **VALIDAÇÃO GAP:** Não é necessária neste momento
   - O MetaTrader já rejeita ordens limitadas em preços inválidos
   - Validação adicional só adicionou complexidade e bugs

---

## 📝 Lições Aprendidas

1. **Keep It Simple:** A correção de GAP não era necessária
2. **Testar em Demo:** Sempre testar novas versões em conta demo primeiro
3. **Mudanças Incrementais:** Adicionar features uma de cada vez
4. **Verificar Logs:** Parâmetros devem ser validados no início

---

*Documento gerado em 27/02/2026*
