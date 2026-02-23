//+------------------------------------------------------------------+
//|                     RoboWIN - VERSÃO CORRIGIDA COMPLETA          |
//|                     ✅ TODAS AS CORREÇÕES APLICADAS               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 - Versão Final Corrigida"
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Parâmetros
input double pontoCompra1    = 0.0;
input double pontoCompra2    = 0.0;
input double pontoVenda1     = 0.0;
input double pontoVenda2     = 0.0;
input int    takeProfit      = 600;
input int    stopLoss        = 200;
input int    breakEvenPontos = 350;
input int    contratos       = 1;
input string horaInicio      = "09:00";
input string horaFim         = "12:00";
input bool   validarAbertura = true;

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

//--- Controle de tentativas
int tentativasCompra = 0;
int tentativasVenda = 0;
datetime ultimaTentativaCompra = 0;
datetime ultimaTentativaVenda = 0;
const int MAX_TENTATIVAS = 3;
const int DELAY_ENTRE_TENTATIVAS = 3;

//--- ⭐ NOVO: Configurações do WIN
const double TICK_SIZE_WIN = 5.0;  // WIN trabalha com múltiplos de 5
double tickSize = 0.0;
double tickValue = 0.0;
long stopsLevelBroker = 0;

struct InfoPosicao {
    bool temPosicao;
    double precoEntrada;
    double takeProfit;
    double stopLoss;
    ENUM_POSITION_TYPE tipo;
};

InfoPosicao posicaoAtual;

//+------------------------------------------------------------------+
//| ⭐ NOVA FUNÇÃO: Normalizar preço ao tick size                    |
//+------------------------------------------------------------------+
double NormalizarPreco(double preco)
{
    // Arredonda para o múltiplo de 5 mais próximo
    double precoNormalizado = MathRound(preco / TICK_SIZE_WIN) * TICK_SIZE_WIN;
    
    Print("   [NORMALIZAÇÃO] ", preco, " → ", precoNormalizado);
    return precoNormalizado;
}

//+------------------------------------------------------------------+
//| ⭐ NOVA FUNÇÃO: Validar e ajustar distância de stops             |
//+------------------------------------------------------------------+
int ValidarDistanciaStop(int distancia, string tipoStop)
{
    // Converter stops level do broker para pontos (pode estar em ticks)
    int minimoPermitido = (int)(stopsLevelBroker * tickSize);
    
    if (minimoPermitido == 0) {
        minimoPermitido = 50; // Fallback seguro para WIN
    }
    
    // Garantir que seja múltiplo de 5
    minimoPermitido = (int)(MathCeil(minimoPermitido / TICK_SIZE_WIN) * TICK_SIZE_WIN);
    
    if (distancia < minimoPermitido) {
        Print("⚠️ ", tipoStop, " (", distancia, " pts) abaixo do mínimo (", minimoPermitido, " pts)");
        Print("   Ajustando para: ", minimoPermitido, " pts");
        return minimoPermitido;
    }
    
    // Garantir que seja múltiplo de 5
    int distanciaNormalizada = (int)(MathRound(distancia / TICK_SIZE_WIN) * TICK_SIZE_WIN);
    
    if (distanciaNormalizada != distancia) {
        Print("⚠️ ", tipoStop, " ajustado de ", distancia, " para ", distanciaNormalizada, " (múltiplo de 5)");
    }
    
    return distanciaNormalizada;
}

//+------------------------------------------------------------------+
int OnInit()
{
    Print("╔═══════════════════════════════════════════════════════════╗");
    Print("║     ROBÔ WIN - VERSÃO CORRIGIDA COMPLETA v2.00          ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    // ⭐ Obter informações do símbolo
    tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    stopsLevelBroker = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    Print("📊 INFORMAÇÕES DO SÍMBOLO:");
    Print("   Símbolo: ", _Symbol);
    Print("   Tick Size: ", tickSize);
    Print("   Tick Value: ", tickValue);
    Print("   Stops Level (broker): ", stopsLevelBroker, " pontos");
    Print("   Tick Size WIN esperado: ", TICK_SIZE_WIN);
    
    if (!ValidarParametros()) {
        Print("❌ ERRO: Parâmetros inválidos!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    trade.SetExpertMagicNumber(12345);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_RETURN);  // ⭐ NOVO: Tipo de preenchimento
    
    ResetarContadores();
    posicaoAtual.temPosicao = false;
    
    Print("✅ Iniciado com ORDENS LIMITADAS (preço exato!)");
    Print("✅ Validação de tick size ativada");
    Print("✅ Normalização automática de stops");
    Print("═══════════════════════════════════════════════════════════");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
    if (!parametrosValidos || !VerificarHorario()) {
        if (roboAtivo) EncerrarDia("Horário encerrado");
        return;
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
    
    if (posicaoAtual.temPosicao) {
        MonitorarPosicao();
    } else {
        if (!VerificarOrdemExecutada()) {
            MonitorarNiveisEntrada();
        }
    }
}

//+------------------------------------------------------------------+
bool VerificarOrdemExecutada()
{
    if (PositionSelect(_Symbol)) {
        posicaoAtual.temPosicao = true;
        posicaoAtual.precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
        posicaoAtual.takeProfit = PositionGetDouble(POSITION_TP);
        posicaoAtual.stopLoss = PositionGetDouble(POSITION_SL);
        posicaoAtual.tipo = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        breakEvenAtivado = false;
        
        Print("╔═══════════════════════════════════════════════════════════╗");
        Print("║              ✅ POSIÇÃO ABERTA                            ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Tipo: ", (posicaoAtual.tipo == POSITION_TYPE_BUY ? "COMPRA" : "VENDA"), "                                     ║");
        Print("║  Preço Entrada: ", posicaoAtual.precoEntrada, "                      ║");
        Print("║  Take Profit: ", posicaoAtual.takeProfit, "                        ║");
        Print("║  Stop Loss: ", posicaoAtual.stopLoss, "                          ║");
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        if (posicaoAtual.tipo == POSITION_TYPE_BUY) compraExecutada = true;
        else vendaExecutada = true;
        
        return true;
    }
    return false;
}

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
    
    // ⭐ Validar se os níveis são múltiplos de 5
    if (((int)pontoCompra1 % 5) != 0 || ((int)pontoCompra2 % 5) != 0 ||
        ((int)pontoVenda1 % 5) != 0 || ((int)pontoVenda2 % 5) != 0) {
        Print("⚠️ AVISO: Níveis devem ser múltiplos de 5 para WIN");
        Print("   Serão normalizados automaticamente");
    }
    
    Print("✅ Parâmetros válidos:");
    Print("   Compra 2: ", pontoCompra2);
    Print("   Compra 1: ", pontoCompra1);
    Print("   Venda 1: ", pontoVenda1);
    Print("   Venda 2: ", pontoVenda2);
    Print("   Take Profit: ", takeProfit, " pts");
    Print("   Stop Loss: ", stopLoss, " pts");
    Print("   Break Even: ", breakEvenPontos, " pts");
    
    parametrosValidos = true;
    return true;
}

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
double ObterPrecoAbertura()
{
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_D1, 0, 1, rates) != 1) return 0.0;
    return rates[0].open;
}

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
void MonitorarNiveisEntrada()
{
    double preco = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // COMPRA
    if (!compraExecutada && (preco <= pontoCompra1 || preco <= pontoCompra2)) {
        if (TimeCurrent() - ultimaTentativaCompra < DELAY_ENTRE_TENTATIVAS) return;
        if (tentativasCompra >= MAX_TENTATIVAS) {
            Print("⚠️ Máximo de tentativas de COMPRA atingido (", MAX_TENTATIVAS, ")");
            return;
        }
        
        double nivelEntrada = (preco <= pontoCompra2) ? pontoCompra2 : pontoCompra1;
        tentativasCompra++;
        ultimaTentativaCompra = TimeCurrent();
        
        Print("\n🎯 GATILHO DE COMPRA ATIVADO");
        Print("   Preço atual: ", preco);
        Print("   Nível de entrada: ", nivelEntrada);
        Print("   Tentativa: ", tentativasCompra, "/", MAX_TENTATIVAS);
        
        if (ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, nivelEntrada)) {
            Print("✅ Ordem de COMPRA LIMITADA enviada!");
        } else {
            Print("❌ Falha ao enviar ordem de COMPRA");
        }
    }
    // VENDA
    else if (!vendaExecutada && (preco >= pontoVenda1 || preco >= pontoVenda2)) {
        if (TimeCurrent() - ultimaTentativaVenda < DELAY_ENTRE_TENTATIVAS) return;
        if (tentativasVenda >= MAX_TENTATIVAS) {
            Print("⚠️ Máximo de tentativas de VENDA atingido (", MAX_TENTATIVAS, ")");
            return;
        }
        
        double nivelEntrada = (preco >= pontoVenda2) ? pontoVenda2 : pontoVenda1;
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
        
        Print("\n🎯 GATILHO DE VENDA ATIVADO");
        Print("   Preço atual: ", preco);
        Print("   Nível de entrada: ", nivelEntrada);
        Print("   Tentativa: ", tentativasVenda, "/", MAX_TENTATIVAS);
        
        if (ExecutarOrdemLimitada(ORDER_TYPE_SELL_LIMIT, nivelEntrada)) {
            Print("✅ Ordem de VENDA LIMITADA enviada!");
        } else {
            Print("❌ Falha ao enviar ordem de VENDA");
        }
    }
}

//+------------------------------------------------------------------+
//| ⭐⭐⭐ FUNÇÃO PRINCIPAL CORRIGIDA - ORDEM LIMITADA ⭐⭐⭐          |
//+------------------------------------------------------------------+
bool ExecutarOrdemLimitada(ENUM_ORDER_TYPE tipo, double nivelReferencia)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║         EXECUTANDO ORDEM LIMITADA                        ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    string tipoStr = (tipo == ORDER_TYPE_BUY_LIMIT ? "COMPRA" : "VENDA");
    Print("📋 Tipo: ", tipoStr);
    Print("📋 Preço de entrada (original): ", nivelReferencia);
    
    // ⭐ PASSO 1: Normalizar preço de entrada ao tick size
    double precoEntrada = NormalizarPreco(nivelReferencia);
    Print("📋 Preço de entrada (normalizado): ", precoEntrada);
    
    // ⭐ PASSO 2: Validar e ajustar stops
    int stopLossAjustado = ValidarDistanciaStop(stopLoss, "Stop Loss");
    int takeProfitAjustado = ValidarDistanciaStop(takeProfit, "Take Profit");
    
    Print("📋 Stop Loss: ", stopLossAjustado, " pts");
    Print("📋 Take Profit: ", takeProfitAjustado, " pts");
    
    // ⭐ PASSO 3: Calcular preços de SL e TP
    double tp, sl;
    
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        tp = precoEntrada + takeProfitAjustado;
        sl = precoEntrada - stopLossAjustado;
    } else {
        tp = precoEntrada - takeProfitAjustado;
        sl = precoEntrada + stopLossAjustado;
    }
    
    // ⭐ PASSO 4: Normalizar SL e TP ao tick size
    tp = NormalizarPreco(tp);
    sl = NormalizarPreco(sl);
    
    Print("📋 Take Profit final: ", tp);
    Print("📋 Stop Loss final: ", sl);
    
    // ⭐ PASSO 5: Validar distâncias finais
    double distanciaTP = MathAbs(tp - precoEntrada);
    double distanciaSL = MathAbs(sl - precoEntrada);
    
    Print("\n🔍 VALIDAÇÃO FINAL:");
    Print("   Distância TP: ", distanciaTP, " pts");
    Print("   Distância SL: ", distanciaSL, " pts");
    Print("   Mínimo broker: ", stopsLevelBroker, " pts");
    
    if (distanciaTP < stopsLevelBroker || distanciaSL < stopsLevelBroker) {
        Print("❌ ERRO: Stops muito próximos do preço de entrada!");
        Print("   Aumente os valores de Stop Loss ou Take Profit");
        return false;
    }
    
    // ⭐⭐⭐ CORREÇÃO CRÍTICA: Parâmetros corretos para OrderOpen ⭐⭐⭐
    // ORDEM ANTIGA (ERRADA):
    // trade.OrderOpen(_Symbol, tipo, contratos, nivelReferencia, 0, sl, tp, ...)
    //                                          ↑ 4º parâmetro    ↑ 5º parâmetro
    //
    // ORDEM NOVA (CORRETA):
    // trade.OrderOpen(_Symbol, tipo, contratos, 0, precoEntrada, sl, tp, ...)
    //                                          ↑ 4º (stop_limit) ↑ 5º (price)
    
    Print("\n📤 ENVIANDO ORDEM...");
    Print("   Símbolo: ", _Symbol);
    Print("   Tipo: ", EnumToString(tipo));
    Print("   Volume: ", contratos);
    Print("   Parâmetro 4 (stop_limit): 0");
    Print("   Parâmetro 5 (price): ", precoEntrada);
    Print("   Stop Loss: ", sl);
    Print("   Take Profit: ", tp);
    
    // ⭐ CORREÇÃO PRINCIPAL: Inverter parâmetros 4 e 5
    bool resultado = trade.OrderOpen(
        _Symbol,              // Símbolo
        tipo,                 // Tipo de ordem (BUY_LIMIT ou SELL_LIMIT)
        contratos,            // Volume
        0,                    // ⭐ 4º PARÂMETRO: stop_limit price (0 para ordem limitada simples)
        precoEntrada,         // ⭐ 5º PARÂMETRO: price (preço de entrada)
        sl,                   // Stop Loss
        tp,                   // Take Profit
        ORDER_TIME_DAY,       // Validade
        0,                    // Expiração
        "WIN-Limitada"        // Comentário
    );
    
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
        
        return false;
    }
    
    Print("\n✅ ORDEM ENVIADA COM SUCESSO!");
    Print("   Ticket: ", trade.ResultOrder());
    Print("   Aguardando execução no preço: ", precoEntrada);
    Print("═══════════════════════════════════════════════════════════\n");
    
    return true;
}

//+------------------------------------------------------------------+
void MonitorarPosicao()
{
    if (!PositionSelect(_Symbol)) {
        VerificarResultadoPosicao();
        posicaoAtual.temPosicao = false;
        breakEvenAtivado = false;
    } else {
        GerenciarBreakEven();
    }
}

//+------------------------------------------------------------------+
void GerenciarBreakEven()
{
    if (breakEvenAtivado) return;
    if (!PositionSelect(_Symbol)) return;
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lucro = (posicaoAtual.tipo == POSITION_TYPE_BUY) ?
                   precoAtual - posicaoAtual.precoEntrada :
                   posicaoAtual.precoEntrada - precoAtual;
    
    if (lucro >= breakEvenPontos) {
        // ⭐ Normalizar preço de break even
        double novoSL = NormalizarPreco(posicaoAtual.precoEntrada);
        
        if (trade.PositionModify(_Symbol, novoSL, posicaoAtual.takeProfit)) {
            breakEvenAtivado = true;
            Print("\n╔═══════════════════════════════════════════════════════════╗");
            Print("║           🎯 BREAKEVEN ATIVADO                           ║");
            Print("╠═══════════════════════════════════════════════════════════╣");
            Print("║  Lucro atual: ", (int)lucro, " pts                              ║");
            Print("║  Novo Stop Loss: ", novoSL, "                           ║");
            Print("╚═══════════════════════════════════════════════════════════╝");
        } else {
            Print("❌ Falha ao mover para break even: ", trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
void VerificarResultadoPosicao()
{
    HistorySelect(TimeCurrent() - 86400, TimeCurrent());
    int total = HistoryDealsTotal();
    if (total == 0) return;
    
    ulong ticket = HistoryDealGetTicket(total - 1);
    if (ticket == 0) return;
    
    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
    double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
    double preco = HistoryDealGetDouble(ticket, DEAL_PRICE);
    
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    
    if (profit > 0) {
        Print("║           ✅ TAKE PROFIT ATINGIDO                        ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Lucro: R$ ", DoubleToString(profit, 2), "                              ║");
        Print("║  Preço: ", preco, "                                      ║");
        Print("╚═══════════════════════════════════════════════════════════╝");
        takeProfitAtingido = true;
        EncerrarDia("Meta atingida - Take Profit");
    } 
    else if (profit == 0 && breakEvenAtivado) {
        Print("║           ⚪ BREAKEVEN - Zero a Zero                    ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Resultado: R$ 0,00                                      ║");
        Print("╚═══════════════════════════════════════════════════════════╝");
    } 
    else {
        stopsExecutados++;
        Print("║           ❌ STOP LOSS EXECUTADO                        ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Prejuízo: R$ ", DoubleToString(profit, 2), "                           ║");
        Print("║  Preço: ", preco, "                                      ║");
        Print("║  Stops executados: ", stopsExecutados, "/2                          ║");
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        if (stopsExecutados >= 2) {
            EncerrarDia("Limite de 2 stops atingido");
        }
    }
}

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
    
    CancelarOrdensPendentes();
    roboAtivo = false;
}

//+------------------------------------------------------------------+
void CancelarOrdensPendentes()
{
    int canceladas = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol) {
            if (trade.OrderDelete(ticket)) {
                canceladas++;
            }
        }
    }
    
    if (canceladas > 0) {
        Print("   ", canceladas, " ordem(ns) pendente(s) cancelada(s)");
    }
}

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
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║              ROBÔ FINALIZADO                             ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  Motivo: ", GetUninitReasonText(reason));
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    CancelarOrdensPendentes();
}
