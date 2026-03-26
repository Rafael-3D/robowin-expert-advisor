//+------------------------------------------------------------------+
//|                     RoboWIN - VERSÃO CORRIGIDA V3.2              |
//|                     ✅ CORREÇÕES CRÍTICAS V3.2:                   |
//|                     1. BREAKEVEN encerra o dia (NÃO reseta)      |
//|                     2. TAKE PROFIT encerra o dia                 |
//|                     3. Apenas STOP LOSS permite nova entrada     |
//|                     4. Flag diaEncerrado para controle           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 - V3.2 Correção Breakeven"
#property version   "3.20"

#include <Trade\Trade.mqh>

//--- Parâmetros
input double pontoCompra1    = 0.0;      // Nível de compra 1 (mais alto)
input double pontoCompra2    = 0.0;      // Nível de compra 2 (mais baixo)
input double pontoVenda1     = 0.0;      // Nível de venda 1 (mais baixo)
input double pontoVenda2     = 0.0;      // Nível de venda 2 (mais alto)
input int    takeProfit      = 600;      // Take Profit em pontos
input int    stopLoss        = 200;      // Stop Loss em pontos
input int    breakEvenPontos = 350;      // Break Even em pontos
input int    contratos       = 1;        // Quantidade de contratos
input string horaInicio      = "09:00";  // Hora início
input string horaFim         = "12:00";  // Hora fim
input bool   validarAbertura = true;     // Validar abertura no range
input bool   usarOrdemMercado = false;   // Usar ordem a mercado se nível já passou

//--- Variáveis globais
CTrade trade;
double precoAbertura = 0.0;
int stopsExecutados = 0;
bool takeProfitAtingido = false;
bool roboAtivo = false;
bool parametrosValidos = false;
bool jaLogouAbertura = false;
bool compraExecutada = false;
bool vendaExecutada = false;
bool breakEvenAtivado = false;

//--- ⭐ V3.2: Flag de controle para encerrar operações do dia
bool diaEncerrado = false;

//--- Controle de tentativas
int tentativasCompra = 0;
int tentativasVenda = 0;
datetime ultimaTentativaCompra = 0;
datetime ultimaTentativaVenda = 0;
const int MAX_TENTATIVAS = 3;
const int DELAY_ENTRE_TENTATIVAS = 3;

//--- Configurações do WIN
const double TICK_SIZE_WIN = 5.0;
double tickSize = 0.0;
double tickValue = 0.0;
long stopsLevelBroker = 0;

//--- Controle de ordens pendentes
ulong ticketOrdemCompra = 0;
ulong ticketOrdemVenda = 0;
bool ordemCompraPendente = false;
bool ordemVendaPendente = false;

struct InfoPosicao {
    bool temPosicao;
    double precoEntrada;
    double takeProfit;
    double stopLoss;
    ENUM_POSITION_TYPE tipo;
    bool stopsAjustados;
};

InfoPosicao posicaoAtual;

//+------------------------------------------------------------------+
//| Normalizar preço ao tick size                                    |
//+------------------------------------------------------------------+
double NormalizarPreco(double preco)
{
    double precoNormalizado = MathRound(preco / TICK_SIZE_WIN) * TICK_SIZE_WIN;
    if (MathAbs(preco - precoNormalizado) > 0.01) {
        Print("   [NORMALIZAÇÃO] ", preco, " → ", precoNormalizado);
    }
    return precoNormalizado;
}

//+------------------------------------------------------------------+
//| Validar e ajustar distância de stops                            |
//+------------------------------------------------------------------+
int ValidarDistanciaStop(int distancia, string tipoStop)
{
    int minimoPermitido = (int)(stopsLevelBroker * tickSize);
    if (minimoPermitido == 0) minimoPermitido = 50;
    minimoPermitido = (int)(MathCeil(minimoPermitido / TICK_SIZE_WIN) * TICK_SIZE_WIN);
    
    if (distancia < minimoPermitido) {
        Print("⚠️ ", tipoStop, " (", distancia, " pts) abaixo do mínimo (", minimoPermitido, " pts)");
        return minimoPermitido;
    }
    
    return (int)(MathRound(distancia / TICK_SIZE_WIN) * TICK_SIZE_WIN);
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("╔═══════════════════════════════════════════════════════════╗");
    Print("║     ROBÔ WIN - VERSÃO CORRIGIDA V3.20                     ║");
    Print("║     ✅ BREAKEVEN encerra o dia (NÃO permite nova entrada)  ║");
    Print("║     ✅ TAKE PROFIT encerra o dia                           ║");
    Print("║     ✅ Apenas STOP LOSS permite nova entrada (se < 2)      ║");
    Print("║     ✅ Flag diaEncerrado para controle rigoroso            ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    stopsLevelBroker = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    Print("📊 INFORMAÇÕES DO SÍMBOLO:");
    Print("   Símbolo: ", _Symbol);
    Print("   Tick Size: ", tickSize);
    Print("   Tick Value: ", tickValue);
    Print("   Stops Level (broker): ", stopsLevelBroker, " pontos");
    
    if (!ValidarParametros()) {
        Print("❌ ERRO: Parâmetros inválidos!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    trade.SetExpertMagicNumber(12345);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_RETURN);
    
    ResetarContadores();
    posicaoAtual.temPosicao = false;
    posicaoAtual.stopsAjustados = false;
    
    Print("═══════════════════════════════════════════════════════════");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnTick - Loop principal                                         |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!parametrosValidos || !VerificarHorario()) {
        if (roboAtivo) EncerrarDia("Horário encerrado");
        return;
    }
    
    //--- ⭐ V3.2: Verificar se o dia já foi encerrado
    if (diaEncerrado) {
        return;  // Não fazer mais nada se o dia foi encerrado
    }
    
    if (!jaLogouAbertura) {
        precoAbertura = ObterPrecoAbertura();
        if (precoAbertura > 0) {
            jaLogouAbertura = true;
            Print("📈 Preço de abertura: ", precoAbertura);
            
            if (validarAbertura && !VerificarCondicaoAbertura()) {
                EncerrarDia("Abertura fora do range");
                return;
            }
            roboAtivo = true;
            Print("🟢 Robô ATIVO - Monitorando níveis de entrada");
        }
    }
    
    if (!roboAtivo || takeProfitAtingido || stopsExecutados >= 2) return;
    
    // Verificar se há posição aberta
    if (PositionSelect(_Symbol)) {
        if (!posicaoAtual.temPosicao) {
            // Posição recém detectada - registrar e ajustar SL/TP
            RegistrarNovaPosicao();
        }
        MonitorarPosicao();
    } else {
        if (posicaoAtual.temPosicao) {
            // Posição foi fechada
            VerificarResultadoPosicao();
            posicaoAtual.temPosicao = false;
            posicaoAtual.stopsAjustados = false;
        }
        
        // Verificar ordens pendentes
        VerificarOrdensPendentes();
        
        // Monitorar níveis para novas entradas
        MonitorarNiveisEntrada();
    }
}

//+------------------------------------------------------------------+
//| ⭐ V3.2: RESET APENAS APÓS STOP LOSS                             |
//| Esta função SÓ é chamada após STOP LOSS para permitir nova       |
//| entrada nos níveis originais                                     |
//+------------------------------------------------------------------+
void ResetarAposStop()
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║           🔄 RESETANDO APÓS STOP LOSS                     ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    
    //--- 1. Cancelar TODAS as ordens pendentes
    Print("║  📍 Passo 1: Cancelando ordens pendentes...");
    int ordensCanceladas = CancelarTodasOrdensPendentes();
    Print("║     Ordens canceladas: ", ordensCanceladas);
    
    //--- 2. Resetar flags de controle de execução
    Print("║  📍 Passo 2: Resetando flags de controle...");
    compraExecutada = false;
    vendaExecutada = false;
    Print("║     compraExecutada = false");
    Print("║     vendaExecutada = false");
    
    //--- 3. Resetar tentativas de entrada
    Print("║  📍 Passo 3: Resetando tentativas...");
    tentativasCompra = 0;
    tentativasVenda = 0;
    ultimaTentativaCompra = 0;
    ultimaTentativaVenda = 0;
    Print("║     tentativasCompra = 0");
    Print("║     tentativasVenda = 0");
    
    //--- 4. Resetar controle de ordens pendentes
    Print("║  📍 Passo 4: Resetando controle de ordens...");
    ordemCompraPendente = false;
    ordemVendaPendente = false;
    ticketOrdemCompra = 0;
    ticketOrdemVenda = 0;
    Print("║     Tickets resetados");
    
    //--- 5. Resetar controle de posição
    Print("║  📍 Passo 5: Resetando controle de posição...");
    posicaoAtual.temPosicao = false;
    posicaoAtual.stopsAjustados = false;
    breakEvenAtivado = false;
    Print("║     posicaoAtual resetada");
    Print("║     breakEvenAtivado = false");
    
    //--- 6. Informar estado atual
    int stopsRestantes = 2 - stopsExecutados;
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  ✅ RESET CONCLUÍDO                                       ║");
    Print("║     Stops executados: ", stopsExecutados, "/2");
    Print("║     Stops restantes: ", stopsRestantes);
    Print("║     Pronto para nova entrada nos níveis originais");
    Print("║     Compra 1: ", pontoCompra1, " / Compra 2: ", pontoCompra2);
    Print("║     Venda 1: ", pontoVenda1, " / Venda 2: ", pontoVenda2);
    Print("╚═══════════════════════════════════════════════════════════╝\n");
}

//+------------------------------------------------------------------+
//| Cancelar TODAS as ordens pendentes (retorna quantidade)          |
//+------------------------------------------------------------------+
int CancelarTodasOrdensPendentes()
{
    int canceladas = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol) {
            ENUM_ORDER_TYPE tipoOrdem = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double precoOrdem = OrderGetDouble(ORDER_PRICE_OPEN);
            
            if (trade.OrderDelete(ticket)) {
                canceladas++;
                Print("   🗑️ Ordem cancelada: Ticket ", ticket, 
                      " | Tipo: ", EnumToString(tipoOrdem),
                      " | Preço: ", precoOrdem);
            }
        }
    }
    
    // Resetar flags
    ordemCompraPendente = false;
    ordemVendaPendente = false;
    ticketOrdemCompra = 0;
    ticketOrdemVenda = 0;
    
    return canceladas;
}

//+------------------------------------------------------------------+
//| Registrar nova posição e ajustar SL/TP                           |
//+------------------------------------------------------------------+
void RegistrarNovaPosicao()
{
    posicaoAtual.temPosicao = true;
    posicaoAtual.precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
    posicaoAtual.tipo = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    posicaoAtual.stopsAjustados = false;
    breakEvenAtivado = false;
    
    // Marcar tipo de ordem como executada
    if (posicaoAtual.tipo == POSITION_TYPE_BUY) {
        compraExecutada = true;
        ordemCompraPendente = false;
        ticketOrdemCompra = 0;
    } else {
        vendaExecutada = true;
        ordemVendaPendente = false;
        ticketOrdemVenda = 0;
    }
    
    Print("╔═══════════════════════════════════════════════════════════╗");
    Print("║              ✅ POSIÇÃO ABERTA DETECTADA                  ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  Tipo: ", (posicaoAtual.tipo == POSITION_TYPE_BUY ? "COMPRA" : "VENDA"));
    Print("║  Preço Entrada REAL: ", posicaoAtual.precoEntrada);
    Print("║  Entrada nº: ", (stopsExecutados + 1), " de 2 possíveis");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    // Ajustar SL/TP baseado no preço REAL de entrada
    AjustarStopsAposExecucao();
}

//+------------------------------------------------------------------+
//| Ajustar SL/TP após execução real                                 |
//+------------------------------------------------------------------+
void AjustarStopsAposExecucao()
{
    if (posicaoAtual.stopsAjustados) return;
    
    double precoReal = posicaoAtual.precoEntrada;
    double novoSL, novoTP;
    
    int stopLossAjustado = ValidarDistanciaStop(stopLoss, "Stop Loss");
    int takeProfitAjustado = ValidarDistanciaStop(takeProfit, "Take Profit");
    
    Print("\n🔧 AJUSTANDO SL/TP BASEADO NO PREÇO REAL DE ENTRADA:");
    Print("   Preço de entrada real: ", precoReal);
    
    if (posicaoAtual.tipo == POSITION_TYPE_BUY) {
        novoSL = NormalizarPreco(precoReal - stopLossAjustado);  // SL ABAIXO
        novoTP = NormalizarPreco(precoReal + takeProfitAjustado); // TP ACIMA
        
        Print("   [COMPRA] SL = Entrada - ", stopLossAjustado, " = ", novoSL, " (ABAIXO)");
        Print("   [COMPRA] TP = Entrada + ", takeProfitAjustado, " = ", novoTP, " (ACIMA)");
        
        if (novoSL >= precoReal) {
            Print("❌ ERRO CRÍTICO: SL (", novoSL, ") >= Entrada (", precoReal, ")!");
            novoSL = NormalizarPreco(precoReal - MathMax(stopLossAjustado, 100));
        }
        
    } else {
        novoSL = NormalizarPreco(precoReal + stopLossAjustado);  // SL ACIMA
        novoTP = NormalizarPreco(precoReal - takeProfitAjustado); // TP ABAIXO
        
        Print("   [VENDA] SL = Entrada + ", stopLossAjustado, " = ", novoSL, " (ACIMA)");
        Print("   [VENDA] TP = Entrada - ", takeProfitAjustado, " = ", novoTP, " (ABAIXO)");
        
        if (novoSL <= precoReal) {
            Print("❌ ERRO CRÍTICO: SL (", novoSL, ") <= Entrada (", precoReal, ")!");
            novoSL = NormalizarPreco(precoReal + MathMax(stopLossAjustado, 100));
        }
    }
    
    Print("\n📤 ENVIANDO MODIFICAÇÃO DE POSIÇÃO...");
    Print("   Novo Stop Loss: ", novoSL);
    Print("   Novo Take Profit: ", novoTP);
    
    if (trade.PositionModify(_Symbol, novoSL, novoTP)) {
        posicaoAtual.stopLoss = novoSL;
        posicaoAtual.takeProfit = novoTP;
        posicaoAtual.stopsAjustados = true;
        
        Print("\n╔═══════════════════════════════════════════════════════════╗");
        Print("║           ✅ SL/TP AJUSTADOS COM SUCESSO                  ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Preço Entrada: ", posicaoAtual.precoEntrada);
        Print("║  Stop Loss: ", novoSL, (posicaoAtual.tipo == POSITION_TYPE_BUY ? " (ABAIXO ✓)" : " (ACIMA ✓)"));
        Print("║  Take Profit: ", novoTP, (posicaoAtual.tipo == POSITION_TYPE_BUY ? " (ACIMA ✓)" : " (ABAIXO ✓)"));
        Print("╚═══════════════════════════════════════════════════════════╝");
    } else {
        Print("❌ Erro ao modificar posição: ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Verificar ordens pendentes                                       |
//+------------------------------------------------------------------+
void VerificarOrdensPendentes()
{
    if (ordemCompraPendente && ticketOrdemCompra > 0) {
        if (!OrderSelect(ticketOrdemCompra)) {
            ordemCompraPendente = false;
            ticketOrdemCompra = 0;
        }
    }
    
    if (ordemVendaPendente && ticketOrdemVenda > 0) {
        if (!OrderSelect(ticketOrdemVenda)) {
            ordemVendaPendente = false;
            ticketOrdemVenda = 0;
        }
    }
}

//+------------------------------------------------------------------+
//| ValidarParametros                                                |
//+------------------------------------------------------------------+
bool ValidarParametros()
{
    Print("\n🔍 VALIDANDO PARÂMETROS...");
    
    if (pontoCompra2 >= pontoCompra1) {
        Print("❌ ERRO: pontoCompra2 deve ser menor que pontoCompra1");
        return false;
    }
    if (pontoCompra1 >= pontoVenda1) {
        Print("❌ ERRO: pontoCompra1 deve ser menor que pontoVenda1");
        return false;
    }
    if (pontoVenda1 >= pontoVenda2) {
        Print("❌ ERRO: pontoVenda1 deve ser menor que pontoVenda2");
        return false;
    }
    if (pontoCompra1 == 0 || takeProfit <= 0 || stopLoss <= 0) {
        Print("❌ ERRO: Parâmetros zerados ou negativos");
        return false;
    }
    
    Print("✅ Parâmetros válidos:");
    Print("   Compra 2: ", pontoCompra2, " (nível mais baixo)");
    Print("   Compra 1: ", pontoCompra1, " (nível mais alto)");
    Print("   Venda 1: ", pontoVenda1, " (nível mais baixo)");
    Print("   Venda 2: ", pontoVenda2, " (nível mais alto)");
    Print("   Take Profit: ", takeProfit, " pts");
    Print("   Stop Loss: ", stopLoss, " pts");
    Print("   Break Even: ", breakEvenPontos, " pts");
    
    parametrosValidos = true;
    return true;
}

//+------------------------------------------------------------------+
//| VerificarHorario                                                 |
//+------------------------------------------------------------------+
bool VerificarHorario()
{
    MqlDateTime agora;
    TimeToStruct(TimeCurrent(), agora);
    
    string partesInicio[], partesFim[];
    StringSplit(horaInicio, ':', partesInicio);
    StringSplit(horaFim, ':', partesFim);
    
    int minInicio = (int)StringToInteger(partesInicio[0]) * 60 + (int)StringToInteger(partesInicio[1]);
    int minFim = (int)StringToInteger(partesFim[0]) * 60 + (int)StringToInteger(partesFim[1]);
    int minAtual = agora.hour * 60 + agora.min;
    
    return (minAtual >= minInicio && minAtual <= minFim);
}

//+------------------------------------------------------------------+
//| ObterPrecoAbertura                                               |
//+------------------------------------------------------------------+
double ObterPrecoAbertura()
{
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_D1, 0, 1, rates) != 1) return 0.0;
    return rates[0].open;
}

//+------------------------------------------------------------------+
//| VerificarCondicaoAbertura                                        |
//+------------------------------------------------------------------+
bool VerificarCondicaoAbertura()
{
    bool valido = (precoAbertura >= pontoCompra2 && precoAbertura <= pontoVenda2);
    if (!valido) {
        Print("⚠️ Abertura (", precoAbertura, ") fora do range [", pontoCompra2, " - ", pontoVenda2, "]");
    }
    return valido;
}

//+------------------------------------------------------------------+
//| ⭐ V3.2: Monitorar níveis com verificação de diaEncerrado        |
//+------------------------------------------------------------------+
void MonitorarNiveisEntrada()
{
    //--- ⭐ V3.2: Verificar se o dia já foi encerrado
    if (diaEncerrado) {
        return;  // Não monitorar se o dia foi encerrado
    }
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Log de status (apenas a cada minuto para não poluir)
    static datetime ultimoLogStatus = 0;
    if (TimeCurrent() - ultimoLogStatus > 60) {
        Print("📊 Status: Compra=", (compraExecutada ? "✓" : "aguardando"),
              " | Venda=", (vendaExecutada ? "✓" : "aguardando"),
              " | Stops: ", stopsExecutados, "/2",
              " | Preço: ", precoAtual);
        ultimoLogStatus = TimeCurrent();
    }
    
    // === COMPRA ===
    if (!compraExecutada && !ordemCompraPendente) {
        double nivelCompra = 0;
        if (precoAtual > pontoCompra1) {
            nivelCompra = pontoCompra1;
        } else if (precoAtual > pontoCompra2) {
            nivelCompra = pontoCompra2;
        }
        
        if (nivelCompra > 0) {
            if (PodeEnviarOrdemCompra()) {
                Print("\n🎯 CONFIGURANDO ORDEM DE COMPRA LIMITADA");
                Print("   Preço atual: ", precoAtual, " (ACIMA do nível)");
                Print("   Nível de compra: ", nivelCompra, " (ordem será executada quando preço CAIR)");
                Print("   Esta será a entrada nº ", (stopsExecutados + 1), " de 2 possíveis");
                
                if (ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, nivelCompra)) {
                    Print("✅ Ordem BUY_LIMIT posicionada em ", nivelCompra);
                }
            }
        }
        else if (precoAtual <= pontoCompra1 && usarOrdemMercado) {
            Print("\n⚠️ Preço (", precoAtual, ") já está ABAIXO/IGUAL ao nível de compra");
            Print("   Executando ordem a MERCADO...");
            
            if (PodeEnviarOrdemCompra()) {
                ExecutarOrdemMercado(ORDER_TYPE_BUY);
            }
        }
    }
    
    // === VENDA ===
    if (!vendaExecutada && !ordemVendaPendente) {
        double nivelVenda = 0;
        if (precoAtual < pontoVenda1) {
            nivelVenda = pontoVenda1;
        } else if (precoAtual < pontoVenda2) {
            nivelVenda = pontoVenda2;
        }
        
        if (nivelVenda > 0) {
            if (PodeEnviarOrdemVenda()) {
                Print("\n🎯 CONFIGURANDO ORDEM DE VENDA LIMITADA");
                Print("   Preço atual: ", precoAtual, " (ABAIXO do nível)");
                Print("   Nível de venda: ", nivelVenda, " (ordem será executada quando preço SUBIR)");
                Print("   Esta será a entrada nº ", (stopsExecutados + 1), " de 2 possíveis");
                
                if (ExecutarOrdemLimitada(ORDER_TYPE_SELL_LIMIT, nivelVenda)) {
                    Print("✅ Ordem SELL_LIMIT posicionada em ", nivelVenda);
                }
            }
        }
        else if (precoAtual >= pontoVenda1 && usarOrdemMercado) {
            Print("\n⚠️ Preço (", precoAtual, ") já está ACIMA/IGUAL ao nível de venda");
            Print("   Executando ordem a MERCADO...");
            
            if (PodeEnviarOrdemVenda()) {
                ExecutarOrdemMercado(ORDER_TYPE_SELL);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Verificar se pode enviar ordem de compra                         |
//+------------------------------------------------------------------+
bool PodeEnviarOrdemCompra()
{
    if (TimeCurrent() - ultimaTentativaCompra < DELAY_ENTRE_TENTATIVAS) return false;
    if (tentativasCompra >= MAX_TENTATIVAS) {
        static datetime ultimoLogCompra = 0;
        if (TimeCurrent() - ultimoLogCompra > 60) {
            Print("⚠️ Máximo de tentativas de COMPRA atingido (", MAX_TENTATIVAS, ")");
            ultimoLogCompra = TimeCurrent();
        }
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Verificar se pode enviar ordem de venda                          |
//+------------------------------------------------------------------+
bool PodeEnviarOrdemVenda()
{
    if (TimeCurrent() - ultimaTentativaVenda < DELAY_ENTRE_TENTATIVAS) return false;
    if (tentativasVenda >= MAX_TENTATIVAS) {
        static datetime ultimoLogVenda = 0;
        if (TimeCurrent() - ultimoLogVenda > 60) {
            Print("⚠️ Máximo de tentativas de VENDA atingido (", MAX_TENTATIVAS, ")");
            ultimoLogVenda = TimeCurrent();
        }
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Executar ordem limitada com validações                           |
//+------------------------------------------------------------------+
bool ExecutarOrdemLimitada(ENUM_ORDER_TYPE tipo, double precoLimite)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║         EXECUTANDO ORDEM LIMITADA                        ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    string tipoStr = (tipo == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT");
    
    // Validação de ordem limitada
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        if (precoLimite >= precoAtual) {
            Print("❌ ERRO: BUY_LIMIT inválido! Preço limite >= Preço atual");
            tentativasCompra++;
            ultimaTentativaCompra = TimeCurrent();
            return false;
        }
    } else if (tipo == ORDER_TYPE_SELL_LIMIT) {
        if (precoLimite <= precoAtual) {
            Print("❌ ERRO: SELL_LIMIT inválido! Preço limite <= Preço atual");
            tentativasVenda++;
            ultimaTentativaVenda = TimeCurrent();
            return false;
        }
    }
    
    Print("📋 Tipo: ", tipoStr);
    Print("📋 Preço atual: ", precoAtual);
    Print("📋 Preço limite: ", precoLimite);
    
    double precoEntrada = NormalizarPreco(precoLimite);
    Print("📋 Preço de entrada (normalizado): ", precoEntrada);
    Print("📋 SL/TP serão definidos após execução da ordem");
    
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        tentativasCompra++;
        ultimaTentativaCompra = TimeCurrent();
    } else {
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
    }
    
    Print("\n📤 ENVIANDO ORDEM...");
    
    bool resultado = trade.OrderOpen(
        _Symbol,
        tipo,
        contratos,
        0,
        precoEntrada,
        0,
        0,
        ORDER_TIME_DAY,
        0,
        "WIN-V3.2-Limitada"
    );
    
    if (!resultado) {
        Print("\n❌ ERRO AO ENVIAR ORDEM:");
        Print("   Código: ", trade.ResultRetcode());
        Print("   Descrição: ", trade.ResultRetcodeDescription());
        DiagnosticarErro(trade.ResultRetcode());
        return false;
    }
    
    ulong ticket = trade.ResultOrder();
    Print("\n✅ ORDEM ENVIADA COM SUCESSO!");
    Print("   Ticket: ", ticket);
    Print("   Aguardando execução no preço: ", precoEntrada);
    
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        ticketOrdemCompra = ticket;
        ordemCompraPendente = true;
    } else {
        ticketOrdemVenda = ticket;
        ordemVendaPendente = true;
    }
    
    Print("═══════════════════════════════════════════════════════════\n");
    return true;
}

//+------------------------------------------------------------------+
//| Executar ordem a mercado                                         |
//+------------------------------------------------------------------+
bool ExecutarOrdemMercado(ENUM_ORDER_TYPE tipo)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║         EXECUTANDO ORDEM A MERCADO                       ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    string tipoStr = (tipo == ORDER_TYPE_BUY ? "COMPRA" : "VENDA");
    Print("📋 Tipo: ", tipoStr);
    
    if (tipo == ORDER_TYPE_BUY) {
        tentativasCompra++;
        ultimaTentativaCompra = TimeCurrent();
    } else {
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
    }
    
    bool resultado;
    if (tipo == ORDER_TYPE_BUY) {
        resultado = trade.Buy(contratos, _Symbol, 0, 0, 0, "WIN-V3.2-Mercado");
    } else {
        resultado = trade.Sell(contratos, _Symbol, 0, 0, 0, "WIN-V3.2-Mercado");
    }
    
    if (!resultado) {
        Print("❌ ERRO: ", trade.ResultRetcodeDescription());
        return false;
    }
    
    Print("✅ Ordem a mercado enviada!");
    return true;
}

//+------------------------------------------------------------------+
//| Diagnóstico de erro                                              |
//+------------------------------------------------------------------+
void DiagnosticarErro(int codigo)
{
    switch(codigo) {
        case 10006:
            Print("   → Erro 10006: Ordem rejeitada pelo servidor");
            break;
        case 10013:
            Print("   → Erro 10013: Preço inválido");
            break;
        case 10016:
            Print("   → Erro 10016: Stops inválidos");
            break;
        case 10014:
            Print("   → Erro 10014: Volume inválido");
            break;
        case 10015:
            Print("   → Erro 10015: Preço incorreto");
            break;
    }
}

//+------------------------------------------------------------------+
//| MonitorarPosicao                                                 |
//+------------------------------------------------------------------+
void MonitorarPosicao()
{
    if (!posicaoAtual.stopsAjustados) {
        AjustarStopsAposExecucao();
    }
    GerenciarBreakEven();
}

//+------------------------------------------------------------------+
//| GerenciarBreakEven                                               |
//+------------------------------------------------------------------+
void GerenciarBreakEven()
{
    if (breakEvenAtivado) return;
    if (!PositionSelect(_Symbol)) return;
    if (!posicaoAtual.stopsAjustados) return;
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lucro = (posicaoAtual.tipo == POSITION_TYPE_BUY) ?
                   precoAtual - posicaoAtual.precoEntrada :
                   posicaoAtual.precoEntrada - precoAtual;
    
    if (lucro >= breakEvenPontos) {
        double novoSL = NormalizarPreco(posicaoAtual.precoEntrada);
        
        if (posicaoAtual.tipo == POSITION_TYPE_BUY && novoSL >= precoAtual) return;
        if (posicaoAtual.tipo == POSITION_TYPE_SELL && novoSL <= precoAtual) return;
        
        if (trade.PositionModify(_Symbol, novoSL, posicaoAtual.takeProfit)) {
            breakEvenAtivado = true;
            posicaoAtual.stopLoss = novoSL;
            
            Print("\n╔═══════════════════════════════════════════════════════════╗");
            Print("║           🎯 BREAKEVEN ATIVADO                           ║");
            Print("╠═══════════════════════════════════════════════════════════╣");
            Print("║  Lucro atual: ", (int)lucro, " pts");
            Print("║  Novo Stop Loss: ", novoSL, " (no preço de entrada)");
            Print("╚═══════════════════════════════════════════════════════════╝");
        }
    }
}

//+------------------------------------------------------------------+
//| ⭐⭐⭐ V3.2: Verificar resultado com LÓGICA CORRIGIDA            |
//| CORREÇÃO PRINCIPAL:                                              |
//| - BREAKEVEN: Encerra o dia (NÃO permite nova entrada)            |
//| - TAKE PROFIT: Encerra o dia                                     |
//| - STOP LOSS: Permite nova entrada APENAS se stopsExecutados < 2  |
//+------------------------------------------------------------------+
void VerificarResultadoPosicao()
{
    HistorySelect(TimeCurrent() - 86400, TimeCurrent());
    int total = HistoryDealsTotal();
    if (total == 0) return;
    
    ulong ticket = HistoryDealGetTicket(total - 1);
    if (ticket == 0) return;
    
    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
    double precoFechamento = HistoryDealGetDouble(ticket, DEAL_PRICE);
    
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    
    // Detecção de TP vs SL
    bool foiTP = false;
    bool foiSL = false;
    bool foiBE = false;
    
    if (posicaoAtual.stopsAjustados) {
        double distanciaDoTP = MathAbs(precoFechamento - posicaoAtual.takeProfit);
        double distanciaDoSL = MathAbs(precoFechamento - posicaoAtual.stopLoss);
        double distanciaDoEntrada = MathAbs(precoFechamento - posicaoAtual.precoEntrada);
        double tolerancia = 20;
        
        if (distanciaDoTP < tolerancia) {
            foiTP = true;
        } else if (distanciaDoSL < tolerancia) {
            if (breakEvenAtivado && distanciaDoEntrada < tolerancia) {
                foiBE = true;
            } else {
                foiSL = true;
            }
        } else if (breakEvenAtivado && distanciaDoEntrada < tolerancia) {
            foiBE = true;
        }
    }
    
    //--- ⭐ V3.2: TAKE PROFIT - ENCERRA O DIA
    if (foiTP || (profit > (takeProfit * 0.8) && profit > 0)) {
        Print("║           ✅ TAKE PROFIT ATINGIDO                        ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Lucro: R$ ", DoubleToString(profit, 2));
        Print("║  Preço entrada: ", posicaoAtual.precoEntrada);
        Print("║  Preço fechamento: ", precoFechamento);
        Print("║  TP configurado: ", posicaoAtual.takeProfit);
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        takeProfitAtingido = true;
        diaEncerrado = true;  // ⭐ V3.2: Setar flag
        Print("\n🔴 Dia encerrado após take profit - Não haverá mais entradas");
        CancelarTodasOrdensPendentes();
        EncerrarDia("Meta atingida - Take Profit");
    }
    //--- ⭐⭐⭐ V3.2: BREAKEVEN - ENCERRA O DIA (NÃO RESETA!)
    else if (foiBE || (breakEvenAtivado && MathAbs(profit) < 10)) {
        Print("║           ⚪ BREAKEVEN - Zero a Zero                    ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Resultado: R$ ", DoubleToString(profit, 2));
        Print("║  Preço entrada: ", posicaoAtual.precoEntrada);
        Print("║  Preço fechamento: ", precoFechamento);
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        // ⭐⭐⭐ V3.2: CORREÇÃO PRINCIPAL - BREAKEVEN ENCERRA O DIA
        // NÃO chama ResetarAposStop() - apenas encerra
        diaEncerrado = true;
        Print("\n🔴 Dia encerrado após breakeven - Não haverá mais entradas");
        Print("   (V3.2: Breakeven NÃO permite nova entrada, diferente da V3.1)");
        CancelarTodasOrdensPendentes();
        EncerrarDia("Breakeven atingido - Dia encerrado");
    }
    //--- ⭐ V3.2: STOP LOSS - PERMITE NOVA ENTRADA SE < 2
    else if (foiSL || profit < 0) {
        stopsExecutados++;
        
        Print("║           ❌ STOP LOSS EXECUTADO                        ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Prejuízo: R$ ", DoubleToString(profit, 2));
        Print("║  Preço entrada: ", posicaoAtual.precoEntrada);
        Print("║  Preço fechamento: ", precoFechamento);
        Print("║  SL configurado: ", posicaoAtual.stopLoss);
        Print("║  Stops executados: ", stopsExecutados, "/2");
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        // ⭐ V3.2: Verificar se ainda pode operar
        if (stopsExecutados >= 2) {
            // Limite de stops atingido - encerrar
            diaEncerrado = true;
            Print("\n🔴 Dia encerrado após 2 stops loss - Não haverá mais entradas");
            CancelarTodasOrdensPendentes();
            EncerrarDia("Limite de 2 stops atingido");
        } else {
            // Ainda tem entrada disponível - RESETAR PARA NOVA ENTRADA
            // ⭐ APENAS o STOP LOSS permite reset!
            Print("\n🔄 Ainda tem ", (2 - stopsExecutados), " entrada(s) disponível(is)!");
            Print("   (V3.2: Apenas stop loss permite nova entrada)");
            ResetarAposStop();
        }
    }
    //--- OUTRO FECHAMENTO
    else {
        Print("║           ⚪ POSIÇÃO FECHADA                            ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Resultado: R$ ", DoubleToString(profit, 2));
        Print("║  Preço fechamento: ", precoFechamento);
        Print("╚═══════════════════════════════════════════════════════════╝");
    }
}

//+------------------------------------------------------------------+
//| EncerrarDia                                                      |
//+------------------------------------------------------------------+
void EncerrarDia(string motivo)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║              🔴 ENCERRANDO OPERAÇÕES                     ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  Motivo: ", motivo);
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    if (PositionSelect(_Symbol)) {
        Print("   Fechando posição aberta...");
        trade.PositionClose(_Symbol);
    }
    
    CancelarTodasOrdensPendentes();
    roboAtivo = false;
    diaEncerrado = true;  // ⭐ V3.2: Garantir que flag está setada
}

//+------------------------------------------------------------------+
//| CancelarOrdensPendentes (compatibilidade)                        |
//+------------------------------------------------------------------+
void CancelarOrdensPendentes()
{
    CancelarTodasOrdensPendentes();
}

//+------------------------------------------------------------------+
//| ResetarContadores                                                |
//+------------------------------------------------------------------+
void ResetarContadores()
{
    stopsExecutados = 0;
    takeProfitAtingido = false;
    roboAtivo = false;
    jaLogouAbertura = false;
    precoAbertura = 0.0;
    compraExecutada = false;
    vendaExecutada = false;
    breakEvenAtivado = false;
    tentativasCompra = 0;
    tentativasVenda = 0;
    ordemCompraPendente = false;
    ordemVendaPendente = false;
    ticketOrdemCompra = 0;
    ticketOrdemVenda = 0;
    diaEncerrado = false;  // ⭐ V3.2: Resetar flag
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║              ROBÔ V3.2 FINALIZADO                         ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  Motivo: ", GetUninitReasonText(reason));
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    CancelarTodasOrdensPendentes();
}

//+------------------------------------------------------------------+
//| GetUninitReasonText                                              |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reason)
{
    switch(reason) {
        case REASON_PROGRAM:     return "Programa encerrado";
        case REASON_REMOVE:      return "Removido do gráfico";
        case REASON_RECOMPILE:   return "Recompilado";
        case REASON_CHARTCHANGE: return "Mudança de símbolo/timeframe";
        case REASON_CHARTCLOSE:  return "Gráfico fechado";
        case REASON_PARAMETERS:  return "Parâmetros alterados";
        case REASON_ACCOUNT:     return "Conta alterada";
        default:                 return "Razão desconhecida";
    }
}
//+------------------------------------------------------------------+
