# 📊 Módulo de Estatísticas - RoboWIN Stats v1.0

## O que é?

O **RoboWIN_Stats.mqh** é um módulo independente que coleta métricas detalhadas de cada trade realizado pelo robô. Ele **apenas observa** - nunca interfere na lógica de trading.

### Características
- ✅ **Zero impacto na performance** - coleta otimizada
- ✅ **Totalmente modular** - fácil ativar/desativar
- ✅ **Dados fiéis** - timestamps precisos com validações
- ✅ **CSV bem formatado** - fácil análise em Excel

---

## 🎯 Métricas Coletadas

### Básicas
| Métrica | Descrição |
|---------|-----------|
| **Tempo até BE** | Quanto tempo levou para atingir break even |
| **MFE (Maximum Favorable Excursion)** | Máximo lucro atingido durante o trade |
| **MAE (Maximum Adverse Excursion)** | Máxima perda atingida durante o trade |
| **Tempo até MFE** | Quando atingiu o lucro máximo |
| **Tempo até MAE** | Quando atingiu a perda máxima |

### Adicionais
| Métrica | Descrição |
|---------|-----------|
| **Candles Total** | Quantidade de candles durante o trade |
| **Tempo Médio Candle** | Duração média de cada candle (minutos) |
| **Volatilidade Média** | High-Low médio dos candles (pontos) |
| **Spread Médio** | Spread médio durante o trade (pontos) |

---

## ⚙️ Como Ativar/Desativar

O módulo é controlado pelo parâmetro `statsAtivo` no EA:

```
✅ statsAtivo = true   → Módulo ATIVO (coleta dados)
❌ statsAtivo = false  → Módulo INATIVO (não faz nada)
```

### Parâmetros do Módulo
| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| `statsAtivo` | true | Ativa/desativa coleta de dados |
| `statsPasta` | "Stats" | Pasta onde os CSVs são salvos |

---

## 📁 Formato do CSV

Os dados são salvos em arquivos CSV na pasta `Stats/` com nome no formato:
```
trades_YYYYMMDD.csv
```

### Colunas do CSV

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| Trade | int | Número sequencial do trade |
| Data | date | Data do trade (YYYY-MM-DD) |
| Hora_Entrada | time | Horário de entrada (HH:MM:SS) |
| Hora_Saida | time | Horário de saída (HH:MM:SS) |
| Tipo | string | "COMPRA" ou "VENDA" |
| Preco_Entrada | double | Preço de entrada |
| Resultado_BRL | double | Resultado em R$ |
| Motivo | string | "TP", "SL", "BE" ou "Manual" |
| Duracao_Min | double | Duração total em minutos |
| Tempo_BE_Min | double | Tempo até break even (minutos) ou "N/A" |
| Tempo_MFE_Min | double | Tempo até MFE máximo (minutos) |
| Tempo_MAE_Min | double | Tempo até MAE máximo (minutos) |
| MFE_Max_Pts | int | MFE máximo em pontos |
| MAE_Max_Pts | int | MAE máximo em pontos |
| Candles_Total | int | Quantidade de candles |
| Tempo_Medio_Candle_Min | double | Tempo médio por candle (minutos) |
| Volatilidade_Media_Pts | double | Volatilidade média (pontos) |
| Spread_Medio_Pts | double | Spread médio (pontos) |

### Exemplo de Linha
```csv
Trade,Data,Hora_Entrada,Hora_Saida,Tipo,Preco_Entrada,Resultado_BRL,Motivo,Duracao_Min,Tempo_BE_Min,Tempo_MFE_Min,Tempo_MAE_Min,MFE_Max_Pts,MAE_Max_Pts,Candles_Total,Tempo_Medio_Candle_Min,Volatilidade_Media_Pts,Spread_Medio_Pts
1,2026-02-26,09:15:30,09:45:22,COMPRA,193500,120.00,TP,29.87,2.50,25.30,5.20,620,85,30,0.99,45.5,5.0
```

---

## 📈 Como Analisar os Dados

### 1. Abrir no Excel
1. Vá em `Arquivo > Abrir`
2. Navegue até `C:\Users\[Seu Usuário]\AppData\Roaming\MetaQuotes\Terminal\[ID]\Common Files\Stats\`
3. Abra o arquivo `trades_YYYYMMDD.csv`

### 2. Insights Importantes

#### MFE vs Resultado
```
Se MFE >> Resultado → O trade chegou a dar mais lucro mas devolveu
Ação: Considerar ajustar stop móvel ou take profit parcial
```

#### MAE vs Stop Loss
```
Se MAE < Stop Loss → O trade nunca chegou perto do stop
Ação: Stop pode estar muito largo (desperdiçando margem de segurança)

Se MAE ≈ Stop Loss → Stop bem calibrado ou trades vieram perto de stopar
```

#### Tempo até BE
```
Se Tempo_BE = N/A → Trade nunca passou para lucro
Se Tempo_BE < 5 min → Entrada precisa, mercado moveu rápido a favor
Se Tempo_BE > 15 min → Entrada "travou", considerar revisar níveis
```

#### Volatilidade vs Resultado
```
Alta volatilidade + Stop Loss → Possível whipsaw
Baixa volatilidade + Take Profit → Movimento direcional limpo
```

---

## 🔍 Exemplos de Análise

### Análise de Eficiência de Saída
```
Eficiência = Resultado / MFE_Max

< 50%  → Devolvendo muito lucro - revisar gerenciamento
50-80% → Normal para mercados voláteis
> 80%  → Excelente timing de saída
```

### Análise de Risco
```
Risco Real = MAE_Max / Stop_Configurado

< 50%  → Stop pode estar muito largo
50-80% → Stop adequado
> 90%  → Trades passando perto do stop - cuidado
```

### Média de Duração por Motivo
```
Agrupar por Motivo e calcular média de Duracao_Min:
- TP: Se muito longo, mercado está lento
- SL: Se muito curto, possível entrada contra tendência
- BE: Tempo de proteção do capital
```

---

## ⚠️ Validações de Dados

O módulo implementa as seguintes validações:

1. **Timestamps válidos**: Verifica se hora de entrada < hora de saída
2. **Duração não-negativa**: Se duração calculada for negativa, corrige para 0
3. **Posição existe**: Verifica se há posição antes de coletar dados
4. **Preço válido**: Valida preço de entrada > 0
5. **Reset entre trades**: Todas variáveis são zeradas ao iniciar novo trade

### Logs de Erro
```
⚠️ [STATS] Preço de entrada inválido: X
⚠️ [STATS] Duração negativa detectada! Corrigindo...
⚠️ [STATS] Erro ao abrir arquivo: X
```

---

## 📂 Arquitetura

```
/robowin_fix/
├── RoboWIN_CORRIGIDO_V3.3.mq5    # Código principal
├── RoboWIN_Stats.mqh              # Módulo de estatísticas
└── Stats/                         # Pasta para CSVs
    ├── .gitkeep                   # Mantém pasta no git
    └── trades_20260226.csv        # Arquivos gerados
```

### Integração (apenas 4 linhas no V3.3)
```cpp
// 1. Include no topo
#include "RoboWIN_Stats.mqh"

// 2. Ao abrir posição (em RegistrarNovaPosicao)
Stats_OnOpen(posicaoAtual.precoEntrada, posicaoAtual.tipo);

// 3. A cada tick (no OnTick, se posição aberta)
Stats_OnTick();

// 4. Ao fechar posição (em VerificarResultadoPosicao)
Stats_OnClose(profit, "TP");  // ou "SL" ou "BE"
```

---

## 🚀 Performance

O módulo foi projetado para **zero impacto** na execução:

- `Stats_OnTick()` é leve - apenas operações simples
- Volatilidade coletada apenas na mudança de candle (não a cada tick)
- CSV salvo apenas ao fechar trade (não durante)
- Verificações rápidas de `statsAtivo` no início de cada função

---

## 📅 Changelog

### v1.0 (2026-02-26)
- Lançamento inicial
- Métricas básicas: MFE, MAE, tempo até BE
- Métricas adicionais: volatilidade, spread, tempo médio candle
- CSV bem formatado com cabeçalhos em português
- Validações de dados fiéis
- Integração com V3.3

---

## ❓ FAQ

**P: O módulo interfere nas decisões de trade?**
R: Não. Ele apenas observa e registra dados.

**P: Onde ficam os arquivos CSV?**
R: Em `Common Files/Stats/` na pasta do MetaTrader.

**P: Posso usar os dados em Python/R?**
R: Sim! O CSV é padrão e pode ser lido por qualquer ferramenta.

**P: O que significa "N/A" em Tempo_BE?**
R: O trade nunca passou para lucro (foi direto para stop ou fechou no zero).

**P: Como desativo o módulo?**
R: Defina `statsAtivo = false` nos parâmetros do EA.
