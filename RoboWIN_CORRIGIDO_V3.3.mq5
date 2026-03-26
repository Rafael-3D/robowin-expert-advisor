//+------------------------------------------------------------------+
//|                     RoboWIN - VERSÃO CORRIGIDA V3.3              |
//|                     ✅ CORREÇÕES CRÍTICAS V3.3:                   |
//|                     1. Validação de execução vs preço configurado |
//|                     2. Tolerância máxima de 20 pontos de slippage |
//|                     3. Log de erro se execução fora do nível      |
//|                     4. Armazena preço original das ordens         |
//|                     5. Todas correções V3.2 mantidas              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 - V3.3 Validação Execução"
#property version   "3.30"

#include <Trade\Trade.mqh>
#include "RoboWIN_Stats.mqh"  // ⭐ Módulo de estatísticas

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
input int    toleranciaExecucao = 20;    // ⭐ V3.3: Tolerância máxima de slippage (pontos)

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

//--- ⭐ V3.3: Armazenar preço original das ordens pendentes
double precoOrdemCompraPendente = 0.0;
double precoOrdemVendaPendente = 0.0;

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
    double precoOrdemOriginal;  // ⭐ V3.3: Preço da ordem que originou a posição
    double takeProfit;
    double stopLoss;
    ENUM_POSITION_TYPE tipo;
    bool stopsAjustados;
    bool execucaoValidada;      // ⭐ V3.3: Se a execução foi validada
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
    Print("║     ROBÔ WIN - VERSÃO CORRIGIDA V3.30                     ║");
    Print("║     ✅ CORREÇÃO: Validação de execução vs preço config.    ║");
    Print("║     ✅ Tolerância máxima: ", toleranciaExecucao, " pontos de slippage        ║");
    Print("║     ✅ Log de erro se execução fora do nível              ║");
    Print("║     ✅ BREAKEVEN encerra o dia (mantido V3.2)              ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    stopsLevelBroker = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    Print("📊 INFORMAÇÕES DO SÍMBOLO:");
    Print("   Símbolo: ", _Symbol);
    Print("   Tick Size: ", tickSize);
    Print("   Tick Value: ", tickValue);
    Print("   Stops Level (broker): ", stopsLevelBroker, " pontos");
    Print("   Tolerância de execução: ", toleranciaExecucao, " pontos");
    
    if (!ValidarParametros()) {
        Print("❌ ERRO: Parâmetros inválidos!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    trade.SetExpertMagicNumber(12345);
    trade.SetDeviationInPoints(10);
    
    // ⭐ V3.3: Configurar filling mode adequado
    ConfigurarFillingMode();
    
    ResetarContadores();
    posicaoAtual.temPosicao = false;
    posicaoAtual.stopsAjustados = false;
    posicaoAtual.execucaoValidada = false;
    
    Print("═══════════════════════════════════════════════════════════");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ⭐ V3.3: Configurar filling mode baseado no que o símbolo suporta |
//+------------------------------------------------------------------+
void ConfigurarFillingMode()
{
    long fillingMode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    
    Print("📊 Modos de filling suportados pelo símbolo:");
    
    // ORDER_FILLING_FOK = 1, ORDER_FILLING_IOC = 2, ORDER_FILLING_RETURN = 4
    if ((fillingMode & 1) != 0) Print("   ✓ ORDER_FILLING_FOK (Fill or Kill)");
    if ((fillingMode & 2) != 0) Print("   ✓ ORDER_FILLING_IOC (Immediate or Cancel)");
    if ((fillingMode & 4) != 0) Print("   ✓ ORDER_FILLING_RETURN (Return)");
    
    // Preferir RETURN para ordens pendentes (comportamento padrão para ordens limitadas)
    trade.SetTypeFilling(ORDER_FILLING_RETURN);
    Print("   → Usando: ORDER_FILLING_RETURN (padrão para ordens pendentes)");
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
        Stats_OnTick();  // ⭐ STATS: Coletar métricas do tick
    } else {
        if (posicaoAtual.temPosicao) {
            // Posição foi fechada
            VerificarResultadoPosicao();
            posicaoAtual.temPosicao = false;
            posicaoAtual.stopsAjustados = false;
            posicaoAtual.execucaoValidada = false;
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
    precoOrdemCompraPendente = 0.0;  // ⭐ V3.3
    precoOrdemVendaPendente = 0.0;   // ⭐ V3.3
    Print("║     Tickets resetados");
    
    //--- 5. Resetar controle de posição
    Print("║  📍 Passo 5: Resetando controle de posição...");
    posicaoAtual.temPosicao = false;
    posicaoAtual.stopsAjustados = false;
    posicaoAtual.execucaoValidada = false;  // ⭐ V3.3
    posicaoAtual.precoOrdemOriginal = 0.0;  // ⭐ V3.3
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
    precoOrdemCompraPendente = 0.0;  // ⭐ V3.3
    precoOrdemVendaPendente = 0.0;   // ⭐ V3.3
    
    return canceladas;
}

//+------------------------------------------------------------------+
//| ⭐⭐⭐ V3.3: Registrar nova posição COM VALIDAÇÃO DE EXECUÇÃO     |
//+------------------------------------------------------------------+
void RegistrarNovaPosicao()
{
    posicaoAtual.temPosicao = true;
    posicaoAtual.precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
    posicaoAtual.tipo = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    posicaoAtual.stopsAjustados = false;
    posicaoAtual.execucaoValidada = false;
    breakEvenAtivado = false;
    
    // ⭐ V3.3: Identificar qual ordem foi executada e validar
    double precoOrdemOriginal = 0.0;
    string tipoOrdemStr = "";
    
    if (posicaoAtual.tipo == POSITION_TYPE_BUY) {
        compraExecutada = true;
        ordemCompraPendente = false;
        precoOrdemOriginal = precoOrdemCompraPendente;
        precoOrdemCompraPendente = 0.0;
        ticketOrdemCompra = 0;
        tipoOrdemStr = "COMPRA";
    } else {
        vendaExecutada = true;
        ordemVendaPendente = false;
        precoOrdemOriginal = precoOrdemVendaPendente;
        precoOrdemVendaPendente = 0.0;
        ticketOrdemVenda = 0;
        tipoOrdemStr = "VENDA";
    }
    
    posicaoAtual.precoOrdemOriginal = precoOrdemOriginal;
    
    Print("╔═══════════════════════════════════════════════════════════╗");
    Print("║              ✅ POSIÇÃO ABERTA DETECTADA                  ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  Tipo: ", tipoOrdemStr);
    Print("║  Preço Entrada REAL: ", posicaoAtual.precoEntrada);
    Print("║  Entrada nº: ", (stopsExecutados + 1), " de 2 possíveis");
    
    // ⭐⭐⭐ V3.3: VALIDAÇÃO CRÍTICA - Verificar se execução está dentro da tolerância
    if (precoOrdemOriginal > 0) {
        double diferencaExecucao = MathAbs(posicaoAtual.precoEntrada - precoOrdemOriginal);
        
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  🔍 VALIDAÇÃO DE EXECUÇÃO V3.3:                           ║");
        Print("║     Preço ordem original: ", precoOrdemOriginal);
        Print("║     Preço execução real:  ", posicaoAtual.precoEntrada);
        Print("║     Diferença: ", (int)diferencaExecucao, " pontos");
        Print("║     Tolerância máxima: ", toleranciaExecucao, " pontos");
        
        if (diferencaExecucao <= toleranciaExecucao) {
            Print("║     ✅ EXECUÇÃO VÁLIDA - Dentro da tolerância");
            posicaoAtual.execucaoValidada = true;
        } else {
            Print("║     ❌ EXECUÇÃO FORA DO NÍVEL CONFIGURADO!");
            Print("║     ⚠️ ALERTA: Slippage de ", (int)diferencaExecucao, " pontos!");
            Print("║     ⚠️ Isso pode indicar GAP de mercado ou problema");
            posicaoAtual.execucaoValidada = false;
            
            // Logar detalhes do erro para análise
            Print("\n╔═══════════════════════════════════════════════════════════╗");
            Print("║  ❌❌❌ ERRO CRÍTICO: EXECUÇÃO FORA DO PREÇO ❌❌❌        ║");
            Print("╠═══════════════════════════════════════════════════════════╣");
            Print("║  Ordem configurada em: ", precoOrdemOriginal);
            Print("║  Execução real em: ", posicaoAtual.precoEntrada);
            Print("║  Diferença: ", (int)diferencaExecucao, " pontos (", 
                  (posicaoAtual.precoEntrada < precoOrdemOriginal ? "ABAIXO" : "ACIMA"), ")");
            Print("║  Tolerância configurada: ", toleranciaExecucao, " pontos");
            Print("║  ");
            Print("║  POSSÍVEIS CAUSAS:");
            Print("║  1. GAP de mercado (preço pulou através do nível)");
            Print("║  2. Alta volatilidade no momento da execução");
            Print("║  3. Baixa liquidez no book de ofertas");
            Print("║  ");
            Print("║  AÇÃO: SL/TP serão calculados com base no preço REAL");
            Print("║        de execução para proteção da posição.");
            Print("╚═══════════════════════════════════════════════════════════╝\n");
        }
    } else {
        Print("║  ⚠️ Preço original da ordem não registrado (ordem manual?)");
        posicaoAtual.execucaoValidada = true;  // Assumir válida se não temos referência
    }
    
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    // ⭐ STATS: Registrar abertura do trade
    Stats_OnOpen(posicaoAtual.precoEntrada, posicaoAtual.tipo);
    
    // Ajustar SL/TP baseado no preço REAL de entrada (sempre, para proteção)
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
    
    // ⭐ V3.3: Informar se a execução estava fora do nível
    if (!posicaoAtual.execucaoValidada && posicaoAtual.precoOrdemOriginal > 0) {
        Print("   ⚠️ ATENÇÃO: Execução estava fora da tolerância!");
        Print("   ⚠️ Preço original: ", posicaoAtual.precoOrdemOriginal);
        Print("   ⚠️ SL/TP calculados com preço REAL para proteção");
    }
    
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
        if (!posicaoAtual.execucaoValidada && posicaoAtual.precoOrdemOriginal > 0) {
            Print("║  ⚠️ Preço Ordem Original: ", posicaoAtual.precoOrdemOriginal);
        }
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
            // NÃO resetar precoOrdemCompraPendente aqui - será usado na validação
        }
    }
    
    if (ordemVendaPendente && ticketOrdemVenda > 0) {
        if (!OrderSelect(ticketOrdemVenda)) {
            ordemVendaPendente = false;
            ticketOrdemVenda = 0;
            // NÃO resetar precoOrdemVendaPendente aqui - será usado na validação
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
    Print("   Tolerância Execução: ", toleranciaExecucao, " pts (V3.3)");
    
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
//| ⭐ V3.2/V3.3: Monitorar níveis com verificação de diaEncerrado   |
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
        else if (precoAtual <= pontoCompra2 && usarOrdemMercado) {
            // ⭐ V3.3: Só executa a mercado se usarOrdemMercado = true
            Print("\n⚠️ Preço (", precoAtual, ") já está ABAIXO/IGUAL ao nível de compra");
            Print("   Executando ordem a MERCADO (usarOrdemMercado = true)...");
            
            if (PodeEnviarOrdemCompra()) {
                ExecutarOrdemMercado(ORDER_TYPE_BUY);
            }
        }
        else if (precoAtual <= pontoCompra2 && !usarOrdemMercado) {
            // ⭐ V3.3: Se preço passou e usarOrdemMercado = false, aguardar retorno
            static datetime ultimoLogCompraAguardando = 0;
            if (TimeCurrent() - ultimoLogCompraAguardando > 300) {  // Log a cada 5 min
                Print("\n📍 Preço (", precoAtual, ") já passou do nível de compra (", pontoCompra2, ")");
                Print("   usarOrdemMercado = false - Aguardando preço VOLTAR ao nível");
                ultimoLogCompraAguardando = TimeCurrent();
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
        else if (precoAtual >= pontoVenda2 && usarOrdemMercado) {
            // ⭐ V3.3: Só executa a mercado se usarOrdemMercado = true
            Print("\n⚠️ Preço (", precoAtual, ") já está ACIMA/IGUAL ao nível de venda");
            Print("   Executando ordem a MERCADO (usarOrdemMercado = true)...");
            
            if (PodeEnviarOrdemVenda()) {
                ExecutarOrdemMercado(ORDER_TYPE_SELL);
            }
        }
        else if (precoAtual >= pontoVenda2 && !usarOrdemMercado) {
            // ⭐ V3.3: Se preço passou e usarOrdemMercado = false, aguardar retorno
            static datetime ultimoLogVendaAguardando = 0;
            if (TimeCurrent() - ultimoLogVendaAguardando > 300) {  // Log a cada 5 min
                Print("\n📍 Preço (", precoAtual, ") já passou do nível de venda (", pontoVenda2, ")");
                Print("   usarOrdemMercado = false - Aguardando preço VOLTAR ao nível");
                ultimoLogVendaAguardando = TimeCurrent();
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
//| ⭐ V3.3: Executar ordem limitada COM ARMAZENAMENTO DO PREÇO      |
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
            Print("❌ ERRO: BUY_LIMIT inválido! Preço limite (", precoLimite, ") >= Preço atual (", precoAtual, ")");
            Print("   → Condição BUY_LIMIT: preço limite deve ser MENOR que preço atual");
            tentativasCompra++;
            ultimaTentativaCompra = TimeCurrent();
            return false;
        }
    } else if (tipo == ORDER_TYPE_SELL_LIMIT) {
        if (precoLimite <= precoAtual) {
            Print("❌ ERRO: SELL_LIMIT inválido! Preço limite (", precoLimite, ") <= Preço atual (", precoAtual, ")");
            Print("   → Condição SELL_LIMIT: preço limite deve ser MAIOR que preço atual");
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
    Print("📋 Tolerância de execução configurada: ", toleranciaExecucao, " pts (V3.3)");
    
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
        "WIN-V3.3-Limitada"
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
    
    // ⭐⭐⭐ V3.3: ARMAZENAR O PREÇO ORIGINAL DA ORDEM
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        ticketOrdemCompra = ticket;
        ordemCompraPendente = true;
        precoOrdemCompraPendente = precoEntrada;  // ⭐ V3.3: Armazenar para validação
        Print("   📝 Preço original armazenado: ", precoEntrada, " (para validação V3.3)");
    } else {
        ticketOrdemVenda = ticket;
        ordemVendaPendente = true;
        precoOrdemVendaPendente = precoEntrada;  // ⭐ V3.3: Armazenar para validação
        Print("   📝 Preço original armazenado: ", precoEntrada, " (para validação V3.3)");
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
        precoOrdemCompraPendente = 0.0;  // ⭐ V3.3: Ordem a mercado não tem preço referência
    } else {
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
        precoOrdemVendaPendente = 0.0;  // ⭐ V3.3: Ordem a mercado não tem preço referência
    }
    
    bool resultado;
    if (tipo == ORDER_TYPE_BUY) {
        resultado = trade.Buy(contratos, _Symbol, 0, 0, 0, "WIN-V3.3-Mercado");
    } else {
        resultado = trade.Sell(contratos, _Symbol, 0, 0, 0, "WIN-V3.3-Mercado");
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
//| ⭐⭐⭐ V3.2/V3.3: Verificar resultado com LÓGICA CORRIGIDA        |
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
        // ⭐ V3.3: Informar se execução original estava fora
        if (!posicaoAtual.execucaoValidada && posicaoAtual.precoOrdemOriginal > 0) {
            Print("║  ⚠️ Preço ordem original: ", posicaoAtual.precoOrdemOriginal);
        }
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        takeProfitAtingido = true;
        diaEncerrado = true;  // ⭐ V3.2: Setar flag
        Stats_OnClose(profit, "TP");  // ⭐ STATS: Registrar fechamento
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
        // ⭐ V3.3: Informar se execução original estava fora
        if (!posicaoAtual.execucaoValidada && posicaoAtual.precoOrdemOriginal > 0) {
            Print("║  ⚠️ Preço ordem original: ", posicaoAtual.precoOrdemOriginal);
        }
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        // ⭐⭐⭐ V3.2: CORREÇÃO PRINCIPAL - BREAKEVEN ENCERRA O DIA
        // NÃO chama ResetarAposStop() - apenas encerra
        diaEncerrado = true;
        Stats_OnClose(profit, "BE");  // ⭐ STATS: Registrar fechamento
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
        // ⭐ V3.3: Informar se execução original estava fora
        if (!posicaoAtual.execucaoValidada && posicaoAtual.precoOrdemOriginal > 0) {
            Print("║  ⚠️ Preço ordem original: ", posicaoAtual.precoOrdemOriginal);
            Print("║  ⚠️ Execução fora do nível pode ter contribuído para stop");
        }
        Print("╚═══════════════════════════════════════════════════════════╝");
        
        Stats_OnClose(profit, "SL");  // ⭐ STATS: Registrar fechamento
        
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
    precoOrdemCompraPendente = 0.0;  // ⭐ V3.3
    precoOrdemVendaPendente = 0.0;   // ⭐ V3.3
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║              ROBÔ V3.3 FINALIZADO                         ║");
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
