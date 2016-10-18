//+------------------------------------------------------------------+
//|                                                 InvestflowTC.mq4 |
//|                                                  Investflow & Co |
//|                                             http://investflow.ru |
//+------------------------------------------------------------------+
#property copyright "Investflow & Co"
#property link      "http://investflow.ru"
#property version   "1.00"
#property strict

#include <stdlib.mqh> 

// ������� ���������:
input string usersInput = "AndreyB"; // ����� ���������� ��� ����������� ����� �������
input double lots = 0.1; // ����� ������ (��������)
input int defaultStopPoints = 50; // ������ �����, � ������ ���� ��� �� �������� �������.
input int slippage = 0; // �������� slippage ��� �������� �������
   
// ��� ����������� �� Investflow: EURUSD, GBPUSD, USDJPY, USDRUB, XAUUSD, BRENT
string iflowInstrument = "";

// ��������� ��� �������� Investflow points � ������ ��� ����
double pointsToPriceMultiplier = 0;

string users[];

int OnInit() {
    if (StringLen(usersInput) == 0 || StringSplit(usersInput, ',', users) == 0) {
        Print("�� ������ ����� ������������!");
        return INIT_PARAMETERS_INCORRECT;
    }
    if (lots <= 0 || lots > 10) {
        Print("������������ �������� ������!");
        return INIT_PARAMETERS_INCORRECT;
    }
    iflowInstrument = symbolToIflowInstrument();
    if (StringLen(iflowInstrument) == 0) {
        Print("���������� �� ��������� � ��������: ", Symbol());
        return INIT_PARAMETERS_INCORRECT;
    }
    pointsToPriceMultiplier = Digits() >= 4 ? 1/10000.0 : 1/100.0;
   
    Print("������������� ���������. ��������: ", iflowInstrument, 
        " �� [" , ArraySize(users) , "] �������������: " ,  usersInput);
   
    // ��� � 5 ����� ����� ��������� ������ � Investflow.
    //EventSetTimer(300);
    EventSetTimer(20);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    Print("OnDeinit, reason: ", reason);
}

void OnTick() {
    // ��� ������� ��������� ������ ��������� - �� ������ �� ����� ��� ������� �� ��������� ���.
    // TODO
}


void OnTimer() {
    // ��������� ��������� �� investflow, ��������� ����� �������, ���� �����.
    char request[], response[];
    string requestHeaders = "User-Agent: investflow-tc", responseHeaders;
    int rc = WebRequest("GET", "http://investflow.ru/api/get-tc-orders?mode=csv", requestHeaders, 30 * 1000, request, response, responseHeaders);
    if (rc < 0) {
        int err = GetLastError();
        Print("������ ��� ������� � investflow. ��� ������: ", ErrorDescription(err));
        return;
    }
    string csv = CharArrayToString(response, 0, WHOLE_ARRAY, CP_UTF8);
    string lines[];
    rc = StringSplit(csv, '\n', lines);
    if (rc < 0) {
        Print("������ ����� �� investflow. ��� ������: ", GetLastError());
        return;
    }
    if (StringCompare("order_id, user_id, user_login, instrument, order_type, open, close, stop", lines[0]) != 0) {
        Print("���������������� ������ ������: ", lines[0]);
        return;
    }
    for (int i = 1, n = ArraySize(lines); i < n; i++) {
        string line = lines[i];
        if (StringLen(line) == 0) {
            continue;
        }
        string tokens[];
        rc = StringSplit(line, ',', tokens);
        if (rc != 8) {
            Print("������ �������� ������: ", line);
            break;
        }
        int orderId = StrToInteger(tokens[0]);
        int userId = StrToInteger(tokens[1]);
        string userLogin = tokens[2];
        if (!isTrackedUser(userLogin)) {
            continue;
        }
        string instrument = tokens[3];
        if (StringCompare(instrument, iflowInstrument) != 0) {
            continue;
        }
        string orderType = tokens[4];
        double openPrice = StrToDouble(tokens[5]);
        // double closePrice = StrToDouble(tokens[6]);
        int stopPoints = StrToInteger(tokens[7]);
      
        int type = StringCompare("buy", orderType) == 0 ? OP_BUY : OP_SELL;
        openOrderIfNeeded(orderId, type, openPrice, stopPoints, userLogin);
    }
}

bool isTrackedUser(string login) {
    for (int i = 0, n = ArraySize(users); i < n; i++) {
        if (StringCompare(users[i], login) == 0) {
            return true;
        }
    }
    return false;
}

void openOrderIfNeeded(int magicNumber, int orderType, double openPrice, int stopPoints, string user) {
    for(int i = 0, n = OrdersTotal(); i < n; i++) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            continue;
        }
        if (magicNumber == OrderMagicNumber()) { // ����� ��� ������
            return;
        }
    }
    // ����� ��� �� ���������: ������� ��� ���� ������� ������� �� �� ��� ����� ��������� ���������
    bool isBuy = orderType == OP_BUY;
    double currentPrice = MarketInfo(Symbol(), isBuy ? MODE_ASK : MODE_BID);

    // ���������� ����� ������ ���� �������� �������� ���� �������� �� ��������
    // � ������� �������� �� ����� �� ����, ��� ����� ���������� ��������
    bool placeOrder  = openPrice <=0 || (isBuy ? openPrice <= currentPrice : openPrice >= currentPrice);
   
    string comment = "Investflow: " + user;
    double stopInPrice = (stopPoints <= 0 ? defaultStopPoints : stopPoints) * pointsToPriceMultiplier;
    double stopLoss = isBuy ? currentPrice - stopInPrice : currentPrice + stopInPrice;
    double takeProfit = isBuy ? currentPrice + stopInPrice : currentPrice - stopInPrice;
   
    Print("��������� �������, ����: ", currentPrice, 
        ", �����: ", lots, 
        ", ���: ", (isBuy ? "BUY" : "SELL"),
        ", SL: ", stopLoss, 
        ", TP: ", takeProfit, 
        ", iflow-���: ", magicNumber);
   
    int ticket = OrderSend(Symbol(), orderType, lots, currentPrice, slippage, stopLoss, takeProfit, comment, magicNumber);
    if (ticket == -1) {
        int err = GetLastError();
        Print("������ �������� ������� ", err, ": ", ErrorDescription(err));
    } else {
        Print("������� �������, �����: ", ticket);
    }
}

string IFLOW_INSTRUMENTS[] = {"EURUSD", "GBPUSD", "USDJPY", "USDRUB", "XAUUSD", "BRENT"};

string symbolToIflowInstrument() {
    string chartSymbol = getChartSymbol();
    for (int i = 0, n = ArraySize(IFLOW_INSTRUMENTS); i < n; i++) {
        string iflowSymbol = IFLOW_INSTRUMENTS[i];
        if (StringCompare(chartSymbol, iflowSymbol) == 0) {
            return iflowSymbol;
        }
    }
    
    return "EURUSD";
}

string getChartSymbol() {
    string symbol = Symbol();

    if (StringCompare(symbol, "UKOIL") == 0) {
        return "BRENT";
    }
        
    // ������ ��� AMarkets: ����������� ����� ����� ������� 'b'
    int len = StringLen(symbol);
    if (StringGetChar(symbol, len-1) == 'b') {
        return StringSubstr(symbol, 0, len - 1);
    }
    return symbol;
}
