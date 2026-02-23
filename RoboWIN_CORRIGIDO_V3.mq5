//+------------------------------------------------------------------+
//|                     RoboWIN - VERSÃO CORRIGIDA V3               |
//|                     ✅ CORREÇÕES CRÍTICAS:                       |
//|                     1. Validação de ordens limitadas            |
//|                     2. Cálculo correto de SL (ABAIXO p/ compra) |
//|                     3. Ajuste de SL/TP após execução real       |
//|                     4. Detecção correta de TP vs SL             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 - V3 Correções Críticas"
#property version   "3.00"

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

//--- ⭐ V3: Controle de ordens pendentes
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
    bool stopsAjustados;  // ⭐ V3: Flag para indicar se SL/TP foram ajustados
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
    Print("║     ROBÔ WIN - VERSÃO CORRIGIDA V3.00                    ║");
    Print("║     ✅ Validação de ordens limitadas                      ║");
    Print("║     ✅ Cálculo correto de SL (ABAIXO para compra)         ║");
    Print("║     ✅ Ajuste de SL/TP após execução real                 ║");
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
            // ⭐ V3: Posição recém detectada - registrar e ajustar SL/TP
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
//| ⭐ V3: Registrar nova posição e ajustar SL/TP                    |
//+------------------------------------------------------------------+
void RegistrarNovaPosicao()
{
    posicaoAtual.temPosicao = true;
    posicaoAtual.precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
    posicaoAtual.tipo = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    posicaoAtual.stopsAjustados = false;
    breakEvenAtivado = false;
    
    // Resetar ordens pendentes
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
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    // ⭐ V3: CORREÇÃO CRÍTICA - Ajustar SL/TP baseado no preço REAL de entrada
    AjustarStopsAposExecucao();
}

//+------------------------------------------------------------------+
//| ⭐ V3: CORREÇÃO CRÍTICA - Ajustar SL/TP após execução real       |
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
    
    // ⭐⭐⭐ CORREÇÃO CRÍTICA DO SL ⭐⭐⭐
    // Para COMPRA: SL deve estar ABAIXO da entrada, TP ACIMA
    // Para VENDA: SL deve estar ACIMA da entrada, TP ABAIXO
    
    if (posicaoAtual.tipo == POSITION_TYPE_BUY) {
        novoSL = NormalizarPreco(precoReal - stopLossAjustado);  // SL ABAIXO
        novoTP = NormalizarPreco(precoReal + takeProfitAjustado); // TP ACIMA
        
        Print("   [COMPRA] SL = Entrada - ", stopLossAjustado, " = ", novoSL, " (ABAIXO)");
        Print("   [COMPRA] TP = Entrada + ", takeProfitAjustado, " = ", novoTP, " (ACIMA)");
        
        // ⭐ VALIDAÇÃO: SL deve ser MENOR que entrada
        if (novoSL >= precoReal) {
            Print("❌ ERRO CRÍTICO: SL (", novoSL, ") >= Entrada (", precoReal, ")!");
            Print("   Isso indica bug no cálculo. Corrigindo...");
            novoSL = NormalizarPreco(precoReal - MathMax(stopLossAjustado, 100));
        }
        
    } else { // VENDA
        novoSL = NormalizarPreco(precoReal + stopLossAjustado);  // SL ACIMA
        novoTP = NormalizarPreco(precoReal - takeProfitAjustado); // TP ABAIXO
        
        Print("   [VENDA] SL = Entrada + ", stopLossAjustado, " = ", novoSL, " (ACIMA)");
        Print("   [VENDA] TP = Entrada - ", takeProfitAjustado, " = ", novoTP, " (ABAIXO)");
        
        // ⭐ VALIDAÇÃO: SL deve ser MAIOR que entrada
        if (novoSL <= precoReal) {
            Print("❌ ERRO CRÍTICO: SL (", novoSL, ") <= Entrada (", precoReal, ")!");
            Print("   Isso indica bug no cálculo. Corrigindo...");
            novoSL = NormalizarPreco(precoReal + MathMax(stopLossAjustado, 100));
        }
    }
    
    // Atualizar posição com novos SL/TP
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
        Print("   Tentando novamente no próximo tick...");
    }
}

//+------------------------------------------------------------------+
//| Verificar ordens pendentes                                       |
//+------------------------------------------------------------------+
void VerificarOrdensPendentes()
{
    // Verificar se ordem de compra ainda existe
    if (ordemCompraPendente && ticketOrdemCompra > 0) {
        if (!OrderSelect(ticketOrdemCompra)) {
            ordemCompraPendente = false;
            ticketOrdemCompra = 0;
        }
    }
    
    // Verificar se ordem de venda ainda existe
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
//| ⭐ V3: Monitorar níveis com validação de ordem limitada          |
//+------------------------------------------------------------------+
void MonitorarNiveisEntrada()
{
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // === COMPRA ===
    if (!compraExecutada && !ordemCompraPendente) {
        // Verificar se preço está acima de algum nível de compra
        // Para BUY_LIMIT funcionar, preço atual deve estar ACIMA do nível
        
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
                
                if (ExecutarOrdemLimitada(ORDER_TYPE_BUY_LIMIT, nivelCompra)) {
                    Print("✅ Ordem BUY_LIMIT posicionada em ", nivelCompra);
                }
            }
        }
        // ⭐ V3: Se preço já está ABAIXO do nível, BUY_LIMIT não funciona
        else if (precoAtual <= pontoCompra1 && usarOrdemMercado) {
            Print("\n⚠️ Preço (", precoAtual, ") já está ABAIXO/IGUAL ao nível de compra");
            Print("   BUY_LIMIT não é válido nesta situação");
            Print("   Executando ordem a MERCADO...");
            
            if (PodeEnviarOrdemCompra()) {
                ExecutarOrdemMercado(ORDER_TYPE_BUY);
            }
        }
    }
    
    // === VENDA ===
    if (!vendaExecutada && !ordemVendaPendente) {
        // Para SELL_LIMIT funcionar, preço atual deve estar ABAIXO do nível
        
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
                
                if (ExecutarOrdemLimitada(ORDER_TYPE_SELL_LIMIT, nivelVenda)) {
                    Print("✅ Ordem SELL_LIMIT posicionada em ", nivelVenda);
                }
            }
        }
        // ⭐ V3: Se preço já está ACIMA do nível, SELL_LIMIT não funciona
        else if (precoAtual >= pontoVenda1 && usarOrdemMercado) {
            Print("\n⚠️ Preço (", precoAtual, ") já está ACIMA/IGUAL ao nível de venda");
            Print("   SELL_LIMIT não é válido nesta situação");
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
//| ⭐ V3: Executar ordem limitada com validações                    |
//+------------------------------------------------------------------+
bool ExecutarOrdemLimitada(ENUM_ORDER_TYPE tipo, double precoLimite)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║         EXECUTANDO ORDEM LIMITADA                        ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    string tipoStr = (tipo == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT");
    
    // ⭐⭐⭐ VALIDAÇÃO CRÍTICA V3: Verificar se ordem limitada é válida ⭐⭐⭐
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        if (precoLimite >= precoAtual) {
            Print("❌ ERRO: BUY_LIMIT inválido!");
            Print("   Preço limite (", precoLimite, ") >= Preço atual (", precoAtual, ")");
            Print("   Para BUY_LIMIT, preço limite deve ser MENOR que preço atual");
            Print("   Considere usar BUY_STOP ou ordem a mercado");
            tentativasCompra++;
            ultimaTentativaCompra = TimeCurrent();
            return false;
        }
    } else if (tipo == ORDER_TYPE_SELL_LIMIT) {
        if (precoLimite <= precoAtual) {
            Print("❌ ERRO: SELL_LIMIT inválido!");
            Print("   Preço limite (", precoLimite, ") <= Preço atual (", precoAtual, ")");
            Print("   Para SELL_LIMIT, preço limite deve ser MAIOR que preço atual");
            Print("   Considere usar SELL_STOP ou ordem a mercado");
            tentativasVenda++;
            ultimaTentativaVenda = TimeCurrent();
            return false;
        }
    }
    
    Print("📋 Tipo: ", tipoStr);
    Print("📋 Preço atual: ", precoAtual);
    Print("📋 Preço limite: ", precoLimite);
    
    // Normalizar preço
    double precoEntrada = NormalizarPreco(precoLimite);
    
    // Para ordem limitada, NÃO definir SL/TP na ordem
    // SL/TP serão definidos quando a posição for aberta (AjustarStopsAposExecucao)
    Print("📋 Preço de entrada (normalizado): ", precoEntrada);
    Print("📋 SL/TP serão definidos após execução da ordem");
    
    // Atualizar contadores
    if (tipo == ORDER_TYPE_BUY_LIMIT) {
        tentativasCompra++;
        ultimaTentativaCompra = TimeCurrent();
    } else {
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
    }
    
    Print("\n📤 ENVIANDO ORDEM...");
    
    // Enviar ordem SEM SL/TP (serão ajustados depois)
    bool resultado = trade.OrderOpen(
        _Symbol,
        tipo,
        contratos,
        0,              // stop_limit (0 para ordem limitada simples)
        precoEntrada,   // price
        0,              // SL = 0 (será definido depois)
        0,              // TP = 0 (será definido depois)
        ORDER_TIME_DAY,
        0,
        "WIN-V3-Limitada"
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
    
    // Registrar ordem pendente
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
//| ⭐ V3: Executar ordem a mercado                                  |
//+------------------------------------------------------------------+
bool ExecutarOrdemMercado(ENUM_ORDER_TYPE tipo)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║         EXECUTANDO ORDEM A MERCADO                       ║");
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    string tipoStr = (tipo == ORDER_TYPE_BUY ? "COMPRA" : "VENDA");
    Print("📋 Tipo: ", tipoStr);
    
    // Atualizar contadores
    if (tipo == ORDER_TYPE_BUY) {
        tentativasCompra++;
        ultimaTentativaCompra = TimeCurrent();
    } else {
        tentativasVenda++;
        ultimaTentativaVenda = TimeCurrent();
    }
    
    bool resultado;
    if (tipo == ORDER_TYPE_BUY) {
        resultado = trade.Buy(contratos, _Symbol, 0, 0, 0, "WIN-V3-Mercado");
    } else {
        resultado = trade.Sell(contratos, _Symbol, 0, 0, 0, "WIN-V3-Mercado");
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
            Print("   → Possível causa: Preço inválido para o tipo de ordem");
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
    // Se SL/TP ainda não foram ajustados, ajustar agora
    if (!posicaoAtual.stopsAjustados) {
        AjustarStopsAposExecucao();
    }
    
    // Gerenciar break even
    GerenciarBreakEven();
}

//+------------------------------------------------------------------+
//| GerenciarBreakEven                                               |
//+------------------------------------------------------------------+
void GerenciarBreakEven()
{
    if (breakEvenAtivado) return;
    if (!PositionSelect(_Symbol)) return;
    if (!posicaoAtual.stopsAjustados) return;  // Só ativar BE após SL/TP ajustados
    
    double precoAtual = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lucro = (posicaoAtual.tipo == POSITION_TYPE_BUY) ?
                   precoAtual - posicaoAtual.precoEntrada :
                   posicaoAtual.precoEntrada - precoAtual;
    
    if (lucro >= breakEvenPontos) {
        double novoSL = NormalizarPreco(posicaoAtual.precoEntrada);
        
        // Validar que BE faz sentido
        if (posicaoAtual.tipo == POSITION_TYPE_BUY && novoSL >= precoAtual) {
            Print("⚠️ Break even não aplicado: SL seria >= preço atual");
            return;
        }
        if (posicaoAtual.tipo == POSITION_TYPE_SELL && novoSL <= precoAtual) {
            Print("⚠️ Break even não aplicado: SL seria <= preço atual");
            return;
        }
        
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
//| ⭐ V3: Verificar resultado com detecção correta de TP/SL         |
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
    
    // ⭐ V3: Detecção correta de TP vs SL vs outros
    bool foiTP = false;
    bool foiSL = false;
    bool foiBE = false;
    
    if (posicaoAtual.stopsAjustados) {
        double distanciaDoTP = MathAbs(precoFechamento - posicaoAtual.takeProfit);
        double distanciaDoSL = MathAbs(precoFechamento - posicaoAtual.stopLoss);
        double distanciaDoEntrada = MathAbs(precoFechamento - posicaoAtual.precoEntrada);
        
        // Tolerância de 20 pontos para considerar que atingiu o nível
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
    
    if (foiTP || (profit > (takeProfit * 0.8) && profit > 0)) {
        Print("║           ✅ TAKE PROFIT ATINGIDO                        ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Lucro: R$ ", DoubleToString(profit, 2));
        Print("║  Preço entrada: ", posicaoAtual.precoEntrada);
        Print("║  Preço fechamento: ", precoFechamento);
        Print("║  TP configurado: ", posicaoAtual.takeProfit);
        Print("╚═══════════════════════════════════════════════════════════╝");
        takeProfitAtingido = true;
        EncerrarDia("Meta atingida - Take Profit");
    }
    else if (foiBE || (breakEvenAtivado && MathAbs(profit) < 10)) {
        Print("║           ⚪ BREAKEVEN - Zero a Zero                    ║");
        Print("╠═══════════════════════════════════════════════════════════╣");
        Print("║  Resultado: R$ ", DoubleToString(profit, 2));
        Print("║  Preço entrada: ", posicaoAtual.precoEntrada);
        Print("║  Preço fechamento: ", precoFechamento);
        Print("╚═══════════════════════════════════════════════════════════╝");
    }
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
        
        if (stopsExecutados >= 2) {
            EncerrarDia("Limite de 2 stops atingido");
        }
    }
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
    
    CancelarOrdensPendentes();
    roboAtivo = false;
}

//+------------------------------------------------------------------+
//| CancelarOrdensPendentes                                          |
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
    
    ordemCompraPendente = false;
    ordemVendaPendente = false;
    ticketOrdemCompra = 0;
    ticketOrdemVenda = 0;
    
    if (canceladas > 0) {
        Print("   ", canceladas, " ordem(ns) pendente(s) cancelada(s)");
    }
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
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("\n╔═══════════════════════════════════════════════════════════╗");
    Print("║              ROBÔ V3 FINALIZADO                          ║");
    Print("╠═══════════════════════════════════════════════════════════╣");
    Print("║  Motivo: ", GetUninitReasonText(reason));
    Print("╚═══════════════════════════════════════════════════════════╝");
    
    CancelarOrdensPendentes();
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
