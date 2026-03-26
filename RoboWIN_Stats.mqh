//+------------------------------------------------------------------+
//|                     RoboWIN Stats - Módulo de Estatísticas       |
//|                     Versão: 1.0 (compatível com V3.3+)           |
//+------------------------------------------------------------------+
//| DESCRIÇÃO:                                                       |
//| Módulo independente para coleta de métricas de trade.            |
//| Apenas observa, NUNCA decide ou interfere na lógica de trade.    |
//|                                                                  |
//| MÉTRICAS COLETADAS:                                              |
//| - Tempo até atingir Break Even                                   |
//| - MFE (Maximum Favorable Excursion)                              |
//| - MAE (Maximum Adverse Excursion)                                |
//| - Tempo médio de cada candle durante o trade                     |
//| - Volatilidade média (high-low)                                  |
//| - Spread médio durante o trade                                   |
//+------------------------------------------------------------------+
#property copyright "RoboWIN Stats Module v1.0"
#property strict

//--- Parâmetro para ativar/desativar estatísticas
input bool   statsAtivo      = true;   // ⭐ Ativar módulo de estatísticas
input string statsPasta      = "Stats"; // Pasta para salvar CSVs

//+------------------------------------------------------------------+
//| Estrutura de dados do trade atual                                |
//+------------------------------------------------------------------+
struct StatsData {
    // Identificação
    int         tradeNumero;
    datetime    dataAbertura;
    datetime    horaEntrada;
    datetime    horaSaida;
    string      tipo;              // "COMPRA" ou "VENDA"
    double      precoEntrada;
    double      resultado;
    string      motivo;            // "TP", "SL", "BE", "Manual"
    
    // Tempos (em segundos, convertidos para minutos no CSV)
    datetime    tempoBreakEven;    // Quando atingiu BE (0 se não atingiu)
    datetime    tempoMFE;          // Quando atingiu MFE máximo
    datetime    tempoMAE;          // Quando atingiu MAE máximo
    
    // Excursões
    double      mfeMaximo;         // Máximo lucro atingido (pontos)
    double      maeMaximo;         // Máxima perda atingida (pontos)
    
    // Métricas adicionais (coletadas a cada tick)
    int         totalTicks;
    double      somaVolatilidade;  // Soma de (high - low) de cada candle
    double      somaSpread;        // Soma dos spreads
    int         candlesCount;      // Quantidade de candles
    datetime    ultimoCandleTime;  // Para detectar novo candle
    
    // Estados
    bool        breakEvenAtingido;
    bool        ativo;
};

StatsData g_stats;
int g_contadorTrades = 0;

//+------------------------------------------------------------------+
//| Stats_OnOpen - Chamar ao abrir posição                           |
//| Inicializa todas as variáveis para novo trade                    |
//+------------------------------------------------------------------+
void Stats_OnOpen(double precoEntrada, ENUM_POSITION_TYPE tipoPos)
{
    if (!statsAtivo) return;
    
    // Validação: verificar se preço é válido
    if (precoEntrada <= 0) {
        Print("⚠️ [STATS] Preço de entrada inválido: ", precoEntrada);
        return;
    }
    
    // Resetar todos os dados
    ZeroMemory(g_stats);
    
    g_contadorTrades++;
    g_stats.tradeNumero = g_contadorTrades;
    g_stats.dataAbertura = TimeCurrent();
    g_stats.horaEntrada = TimeCurrent();
    g_stats.precoEntrada = precoEntrada;
    g_stats.tipo = (tipoPos == POSITION_TYPE_BUY) ? "COMPRA" : "VENDA";
    
    // Inicializar métricas
    g_stats.mfeMaximo = 0.0;
    g_stats.maeMaximo = 0.0;
    g_stats.tempoBreakEven = 0;
    g_stats.tempoMFE = 0;
    g_stats.tempoMAE = 0;
    g_stats.breakEvenAtingido = false;
    
    // Inicializar métricas adicionais
    g_stats.totalTicks = 0;
    g_stats.somaVolatilidade = 0.0;
    g_stats.somaSpread = 0.0;
    g_stats.candlesCount = 0;
    g_stats.ultimoCandleTime = 0;
    
    g_stats.ativo = true;
    
    Print("📊 [STATS] Trade #", g_stats.tradeNumero, " iniciado | ", 
          g_stats.tipo, " @ ", precoEntrada);
}

//+------------------------------------------------------------------+
//| Stats_OnTick - Chamar a cada tick se posição aberta              |
//| Função otimizada para não impactar performance                   |
//+------------------------------------------------------------------+
void Stats_OnTick()
{
    if (!statsAtivo || !g_stats.ativo) return;
    
    // Validação: verificar se posição existe
    if (!PositionSelect(_Symbol)) {
        g_stats.ativo = false;
        return;
    }
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Validação de preço
    if (precoAtual <= 0) return;
    
    // Calcular excursão atual
    double excursao = 0.0;
    if (g_stats.tipo == "COMPRA") {
        excursao = precoAtual - g_stats.precoEntrada;
    } else {
        excursao = g_stats.precoEntrada - precoAtual;
    }
    
    // Atualizar MFE (lucro máximo)
    if (excursao > g_stats.mfeMaximo) {
        g_stats.mfeMaximo = excursao;
        g_stats.tempoMFE = TimeCurrent();
    }
    
    // Atualizar MAE (perda máxima) - negativo
    if (excursao < 0 && MathAbs(excursao) > g_stats.maeMaximo) {
        g_stats.maeMaximo = MathAbs(excursao);
        g_stats.tempoMAE = TimeCurrent();
    }
    
    // Detectar Break Even (excursão passou de negativo/zero para positivo)
    if (!g_stats.breakEvenAtingido && excursao > 0) {
        g_stats.breakEvenAtingido = true;
        g_stats.tempoBreakEven = TimeCurrent();
    }
    
    // Coletar spread
    double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
    g_stats.somaSpread += spread;
    g_stats.totalTicks++;
    
    // Coletar volatilidade (apenas quando muda o candle para eficiência)
    datetime candleAtual = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (candleAtual != g_stats.ultimoCandleTime) {
        g_stats.ultimoCandleTime = candleAtual;
        
        // Coletar high-low do candle anterior (completo)
        double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
        double low = iLow(_Symbol, PERIOD_CURRENT, 1);
        
        if (high > 0 && low > 0) {
            g_stats.somaVolatilidade += (high - low);
            g_stats.candlesCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Stats_OnClose - Chamar ao fechar posição                         |
//| Finaliza coleta e salva CSV                                      |
//+------------------------------------------------------------------+
void Stats_OnClose(double lucro, string motivo)
{
    if (!statsAtivo || !g_stats.ativo) return;
    
    g_stats.horaSaida = TimeCurrent();
    g_stats.resultado = lucro;
    g_stats.motivo = motivo;
    g_stats.ativo = false;
    
    // Salvar dados
    Stats_SalvarCSV();
    
    Print("📊 [STATS] Trade #", g_stats.tradeNumero, " finalizado | ",
          "Resultado: ", DoubleToString(lucro, 2), " | ",
          "MFE: ", (int)g_stats.mfeMaximo, " pts | ",
          "MAE: ", (int)g_stats.maeMaximo, " pts");
}

//+------------------------------------------------------------------+
//| Stats_SalvarCSV - Salvar dados em CSV bem formatado              |
//+------------------------------------------------------------------+
void Stats_SalvarCSV()
{
    if (!statsAtivo) return;
    
    // Montar nome do arquivo com data
    MqlDateTime dt;
    TimeToStruct(g_stats.dataAbertura, dt);
    string nomeArquivo = statsPasta + "\\trades_" + 
                         IntegerToString(dt.year) + 
                         StringFormat("%02d", dt.mon) + 
                         StringFormat("%02d", dt.day) + ".csv";
    
    // Verificar se precisa criar cabeçalho
    bool arquivoNovo = !FileIsExist(nomeArquivo, FILE_COMMON);
    
    int handle = FileOpen(nomeArquivo, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
    if (handle == INVALID_HANDLE) {
        Print("⚠️ [STATS] Erro ao abrir arquivo: ", nomeArquivo);
        return;
    }
    
    // Se arquivo novo, escrever cabeçalho
    if (arquivoNovo) {
        string cabecalho = "Trade,Data,Hora_Entrada,Hora_Saida,Tipo,Preco_Entrada,Resultado_BRL,Motivo," +
                           "Duracao_Min,Tempo_BE_Min,Tempo_MFE_Min,Tempo_MAE_Min," +
                           "MFE_Max_Pts,MAE_Max_Pts," +
                           "Candles_Total,Tempo_Medio_Candle_Min," +
                           "Volatilidade_Media_Pts,Spread_Medio_Pts";
        FileWrite(handle, cabecalho);
    } else {
        // Ir para o final do arquivo
        FileSeek(handle, 0, SEEK_END);
    }
    
    // Calcular métricas derivadas
    double duracaoMin = (g_stats.horaSaida > 0 && g_stats.horaEntrada > 0) ? 
                        (double)(g_stats.horaSaida - g_stats.horaEntrada) / 60.0 : 0.0;
    
    // Validar duração
    if (duracaoMin < 0) {
        Print("⚠️ [STATS] Duração negativa detectada! Corrigindo...");
        duracaoMin = 0.0;
    }
    
    double tempoBEMin = (g_stats.tempoBreakEven > 0 && g_stats.horaEntrada > 0) ?
                        (double)(g_stats.tempoBreakEven - g_stats.horaEntrada) / 60.0 : -1.0;
    
    double tempoMFEMin = (g_stats.tempoMFE > 0 && g_stats.horaEntrada > 0) ?
                         (double)(g_stats.tempoMFE - g_stats.horaEntrada) / 60.0 : 0.0;
    
    double tempoMAEMin = (g_stats.tempoMAE > 0 && g_stats.horaEntrada > 0) ?
                         (double)(g_stats.tempoMAE - g_stats.horaEntrada) / 60.0 : 0.0;
    
    // Tempo médio por candle
    double tempoMedioCandle = (g_stats.candlesCount > 0 && duracaoMin > 0) ?
                              duracaoMin / g_stats.candlesCount : 0.0;
    
    // Volatilidade média
    double volatilidade = (g_stats.candlesCount > 0) ?
                          g_stats.somaVolatilidade / g_stats.candlesCount : 0.0;
    
    // Spread médio
    double spreadMedio = (g_stats.totalTicks > 0) ?
                         g_stats.somaSpread / g_stats.totalTicks : 0.0;
    
    // Formatar datas
    MqlDateTime dtEntrada, dtSaida;
    TimeToStruct(g_stats.horaEntrada, dtEntrada);
    TimeToStruct(g_stats.horaSaida, dtSaida);
    
    string dataStr = StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);
    string horaEntradaStr = StringFormat("%02d:%02d:%02d", dtEntrada.hour, dtEntrada.min, dtEntrada.sec);
    string horaSaidaStr = StringFormat("%02d:%02d:%02d", dtSaida.hour, dtSaida.min, dtSaida.sec);
    
    // Montar linha do CSV
    string linha = IntegerToString(g_stats.tradeNumero) + "," +
                   dataStr + "," +
                   horaEntradaStr + "," +
                   horaSaidaStr + "," +
                   g_stats.tipo + "," +
                   DoubleToString(g_stats.precoEntrada, 0) + "," +
                   DoubleToString(g_stats.resultado, 2) + "," +
                   g_stats.motivo + "," +
                   DoubleToString(duracaoMin, 2) + "," +
                   (tempoBEMin >= 0 ? DoubleToString(tempoBEMin, 2) : "N/A") + "," +
                   DoubleToString(tempoMFEMin, 2) + "," +
                   DoubleToString(tempoMAEMin, 2) + "," +
                   IntegerToString((int)g_stats.mfeMaximo) + "," +
                   IntegerToString((int)g_stats.maeMaximo) + "," +
                   IntegerToString(g_stats.candlesCount) + "," +
                   DoubleToString(tempoMedioCandle, 2) + "," +
                   DoubleToString(volatilidade, 1) + "," +
                   DoubleToString(spreadMedio, 1);
    
    FileWrite(handle, linha);
    FileClose(handle);
    
    Print("📊 [STATS] Dados salvos em: ", nomeArquivo);
}

//+------------------------------------------------------------------+
//| Stats_Resetar - Resetar para novo trade (chamado internamente)   |
//+------------------------------------------------------------------+
void Stats_Resetar()
{
    ZeroMemory(g_stats);
}
//+------------------------------------------------------------------+
