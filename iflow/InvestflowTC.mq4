//+------------------------------------------------------------------+
//|                                                 InvestflowTC.mq4 |
//|                                                  Investflow & Co |
//|                                             http://investflow.ru |
//+------------------------------------------------------------------+
#property copyright "Investflow & Co"
#property link      "http://investflow.ru"
#property version   "1.00"
#property strict

// входные параметры:
input string login; // логин участника

int OnInit() {
   // раз в 5 минут будем проверять данные с Investflow.
   //EventSetTimer(300);
   EventSetTimer(5);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   Print("OnDeinit");
   EventKillTimer();
}

void OnTick() {
   // для каждого открытого ордера проверяем - не пришло ли время его закрыть по стопу.
}


void OnTimer() {
   // проверяем состояние на investflow, открываем новые позиции, если нужно.
   char request[], response[];
   string requestHeaders = "User-Agent: investflow-tc", responseHeaders;
   int rc = WebRequest("GET", "http://investflow.ru/api/get-tc-orders?mode=csv", requestHeaders, 30 * 1000, request, response, responseHeaders);
   if (rc < 0) {
      Print("Ошибка при доступе к investflow. Код ошибки: ", GetLastError());
      return;
   }
   string csv = CharArrayToString(response, 0, WHOLE_ARRAY, CP_UTF8);
   string lines[];
   rc = StringSplit(csv, '\n', lines);
   if (rc < 0) {
      Print("Пустой ответ от investflow. Код ошибки: ", GetLastError());
      return;
   }
   if (StringCompare("order_id, user_id, user_login, instrument, order_type, open, close, stop", lines[0]) != 0) {
      Print("Неподдерживаемый формат ответа: ", lines[0]);
      return;
   }
   for (int i = 1, n = ArraySize(lines); i < n; i++) {
      string line = lines[i];
      string tokens[];
      rc = StringSplit(line, ',', tokens);
      if (rc != 8) {
         Print("Ошибка парсинга строки: ", line);
         break;
      }
      int orderId = StrToInteger(tokens[0]);
      int userId = StrToInteger(tokens[1]);
      string userLogin = tokens[2];
      string instrument = tokens[3];
      string order_type = tokens[4];
      double openPrice = StrToDouble(tokens[5]);
      double closePrice = StrToDouble(tokens[6]);
      int stopPoints = StrToInteger(tokens[7]);
   }
}
