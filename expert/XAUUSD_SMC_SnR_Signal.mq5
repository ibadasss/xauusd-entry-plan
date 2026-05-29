//+------------------------------------------------------------------+
//|                                   XAUUSD_SMC_SnR_Signal.mq5       |
//|              Signal-only EA (NO auto-entry) for XAU/USD           |
//|                                                                  |
//|  REVISI v3.0:                                                    |
//|   - Jalur A (SMC) : BOS/CHoCH (anti-repaint, close) -> retrace   |
//|                     -> mitigasi Order Block ber-FVG.             |
//|   - Jalur B (SnR) : level Support/Resistance horizontal kuat     |
//|                     -> rejection valid (Buy@Support, Sell@Resist).|
//|   - DUA strategi BERDIRI SENDIRI (tidak dikombinasikan).         |
//|   - 24 jam nonstop (TANPA session filter).                       |
//|   - TP DINAMIS ke key-level berikutnya; RR dihitung otomatis.    |
//|   - SL konsisten 30-60 pips (geser entry bila terlalu lebar).    |
//|   - Deduplikasi: anti kirim sinyal sama berulang di zona sama.   |
//|   - Tes koneksi Telegram di OnInit() (untuk cek token/chat id).  |
//|   - Notifikasi Telegram via WebRequest.                          |
//+------------------------------------------------------------------+
#property copyright "XAUUSD Entry Plan"
#property link      "https://github.com/ibadasss/xauusd-entry-plan"
#property version   "3.00"
#property strict

//==================================================================
//  INPUTS
//==================================================================
input group "=== Strategi ==="
input bool   InpEnableSMC      = true;            // Aktifkan Jalur A (SMC)
input bool   InpEnableSnR      = true;            // Aktifkan Jalur B (SnR)

input group "=== Market Structure (SMC) ==="
input int    InpSwingLen       = 10;              // Swing Length (pivot kiri/kanan)
input int    InpOBLookback     = 30;             // Max bar mundur cari Order Block
input int    InpZoneMaxAge     = 80;             // Max umur zona OB (bar) utk valid

input group "=== Support & Resistance (SnR) ==="
input int    InpSnRPivotLen    = 12;              // Pivot length level SnR
input int    InpSnRMinTouch    = 2;               // Minimal sentuhan agar level 'kuat'
input int    InpSnRMaxLevels   = 20;              // Maksimal level SnR disimpan
input double InpRejectionPips  = 8.0;             // Min ukuran ekor rejection (pips)

input group "=== Risk Management (Pips) ==="
input double InpPipSize        = 0.10;            // Nilai 1 pip XAUUSD (0.10 harga)
input double InpMinSLPips       = 30.0;           // SL minimal (pips)
input double InpMaxSLPips       = 60.0;           // SL maksimal (pips)
input double InpSLBufferPips    = 3.0;            // Buffer SL di luar zona (pips)

input group "=== Take Profit Dinamis ==="
input double InpMinRR          = 1.0;             // RR minimal agar sinyal dikirim
input int    InpKeyLevelScan   = 200;             // Bar di-scan utk cari key-level TP

input group "=== Anti Over-Trading ==="
input int    InpCooldownBars   = 5;               // Cooldown antar sinyal (bar)

input group "=== Deduplikasi Sinyal ==="
input bool   InpUseDedup       = true;            // Anti kirim sinyal sama di zona yang sama
input double InpDedupPips       = 25.0;           // Jarak min antar sinyal sejenis (pips)
input int    InpDedupExpiryBars = 300;            // Umur memori dedup (bar); 0 = selamanya

input group "=== Telegram ==="
input bool   InpUseTelegram    = true;            // Kirim ke Telegram
input string InpBotToken       = "";              // Token bot (dari @BotFather)
input string InpChatID         = "";              // Chat ID tujuan
input bool   InpAlsoAlert      = true;            // Tampilkan Alert() terminal juga
input bool   InpSendTestOnInit = true;            // Kirim pesan TES saat EA dipasang/refresh

//==================================================================
//  KONSTANTA & STATE GLOBAL
//==================================================================
#define DIR_BUY   1
#define DIR_SELL -1

// Struktur pasar (anti-repaint berbasis bar tertutup)
double  g_swingHigh = 0.0;
double  g_swingLow  = 0.0;
int     g_trend     = 0;          // 1 bull, -1 bear
bool    g_brokeHigh = false;
bool    g_brokeLow  = false;

// Order Block aktif (yang menghasilkan break, ber-FVG)
bool    g_obBullActive = false;   double g_obBullTop=0, g_obBullBot=0; int g_obBullBar=0;
bool    g_obBearActive = false;   double g_obBearTop=0, g_obBearBot=0; int g_obBearBar=0;

// Cooldown per jalur
datetime g_lastSMCTime = 0;
datetime g_lastSnRTime = 0;
int      g_lastBarCount = 0;

// Level SnR
double   g_snr[];                 // harga level
int      g_snrTouch[];            // jumlah sentuhan
bool     g_snrIsRes[];            // true=resistance, false=support

// Memori deduplikasi sinyal (sidik jari sinyal yang sudah dikirim)
string   g_dedupStrat[];          // "SMC" / "SnR"
int      g_dedupDir[];            // DIR_BUY / DIR_SELL
double   g_dedupRef[];            // harga referensi zona (sumbu zona/level)
int      g_dedupBar[];            // Bars() saat sinyal dikirim (utk expiry)

//==================================================================
//  UTIL
//==================================================================
double PipsToPrice(double pips){ return pips * InpPipSize; }
double PriceToPips(double price){ return (InpPipSize>0 ? price / InpPipSize : 0.0); }

string DirText(int dir){ return (dir==DIR_BUY ? "BUY" : "SELL"); }

//+------------------------------------------------------------------+
//| Kirim pesan ke Telegram via WebRequest                           |
//| return true bila HTTP 200 (Telegram menerima pesan).             |
//+------------------------------------------------------------------+
bool SendTelegram(const string text)
{
   if(!InpUseTelegram) return false;
   if(InpBotToken=="" || InpChatID=="")
   {
      Print("Telegram: token/chat id kosong, lewati pengiriman.");
      return false;
   }

   string url = "https://api.telegram.org/bot" + InpBotToken + "/sendMessage";
   // URL-encode minimal untuk newline & spasi ditangani oleh payload form
   string payload = "chat_id=" + InpChatID + "&text=" + text;

   char post[]; char result[]; string resultHeaders;
   StringToCharArray(payload, post, 0, StringLen(payload), CP_UTF8);
   // Hilangkan null terminator agar Content-Length akurat
   int len = ArraySize(post); if(len>0 && post[len-1]==0) ArrayResize(post, len-1);

   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   ResetLastError();
   int code = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
   if(code == -1)
   {
      int err = GetLastError();
      PrintFormat("WebRequest GAGAL (err %d). Allowlist 'https://api.telegram.org' di Tools>Options>Expert Advisors & aktifkan Algo Trading.", err);
      return false;
   }

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(code == 200)
   {
      PrintFormat("Telegram OK (HTTP 200). Respons: %s", body);
      return true;
   }
   // Respons selain 200 biasanya token/chat id salah -> tampilkan body API utk diagnosa
   PrintFormat("Telegram DITOLAK (HTTP %d). Periksa Token/Chat ID. Respons: %s", code, body);
   return false;
}

//+------------------------------------------------------------------+
//| Susun & kirim notifikasi sinyal (format Telegram revisi)         |
//+------------------------------------------------------------------+
void NotifySignal(const string strat, int dir, double entry, double slPrice,
                  double tpPrice, double slPips, double rr)
{
   string msg =
      "\xF0\x9F\x9A\xA8 [XAUUSD LIVE SIGNAL] \xF0\x9F\x9A\xA8\n" +
      "Strategi: " + strat + "\n" +
      "Aksi: " + DirText(dir) + "\n" +
      "Harga Entry: " + DoubleToString(entry, _Digits) + "\n" +
      "Target SL: " + DoubleToString(slPips, 1) + " pips (" + DoubleToString(slPrice, _Digits) + ")\n" +
      "Target TP: " + DoubleToString(tpPrice, _Digits) + "\n" +
      "Dinamis RR: 1:" + DoubleToString(rr, 2);

   SendTelegram(msg);
   if(InpAlsoAlert) Alert(strat + " " + DirText(dir) + " @ " + DoubleToString(entry,_Digits) +
                          "  SL " + DoubleToString(slPips,1) + "p  RR 1:" + DoubleToString(rr,2));
   Print(msg);
}

//+------------------------------------------------------------------+
//| Pesan TES koneksi Telegram (dipanggil dari OnInit)               |
//+------------------------------------------------------------------+
void SendConnectionTest()
{
   string msg =
      "\xF0\x9F\x9A\x80 [XAUUSD BOT TEST KONEKSI] \xF0\x9F\x9A\x80\n" +
      "Status: Bot Berhasil Aktif di MT5!\n" +
      "Pesan: Sistem SMC & SnR siap berpatroli hari Senin.\n" +
      "Waktu Lokal: " + TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);

   bool ok = SendTelegram(msg);
   if(InpAlsoAlert)
      Alert(ok ? "TES TELEGRAM: BERHASIL terkirim! Cek HP Anda."
               : "TES TELEGRAM: GAGAL. Lihat tab Experts untuk detail (token/chat id/allowlist).");
}

//==================================================================
//  AKSES DATA (bar tertutup => index mulai 1 utk anti-repaint)
//==================================================================
double HighAt(int shift){ return iHigh(_Symbol, _Period, shift); }
double LowAt (int shift){ return iLow (_Symbol, _Period, shift); }
double OpenAt(int shift){ return iOpen(_Symbol, _Period, shift); }
double CloseAt(int shift){ return iClose(_Symbol, _Period, shift); }
datetime TimeAt(int shift){ return iTime(_Symbol, _Period, shift); }

//+------------------------------------------------------------------+
//| Pivot high/low terkonfirmasi (anti-repaint).                     |
//| Mengembalikan harga pivot bila bar (shift=len+1.. ) adalah pivot,|
//| dengan 'len' bar di kiri & kanan. Cek pada bar yang sudah pasti. |
//+------------------------------------------------------------------+
bool IsPivotHigh(int centerShift, int len, double &outPrice)
{
   double c = HighAt(centerShift);
   for(int i=1; i<=len; i++)
   {
      if(HighAt(centerShift+i) >= c) return false;   // kiri (lebih lama)
      if(HighAt(centerShift-i) >= c) return false;   // kanan (lebih baru)
   }
   outPrice = c;
   return true;
}

bool IsPivotLow(int centerShift, int len, double &outPrice)
{
   double c = LowAt(centerShift);
   for(int i=1; i<=len; i++)
   {
      if(LowAt(centerShift+i) <= c) return false;
      if(LowAt(centerShift-i) <= c) return false;
   }
   outPrice = c;
   return true;
}

//==================================================================
//  JALUR A : SMC  (BOS/CHoCH -> OB ber-FVG -> mitigasi)
//==================================================================

//--- update struktur saat ada pivot baru terkonfirmasi (pada bar tertutup)
void UpdateSwings()
{
   double p;
   // pivot terkonfirmasi berpusat di shift = InpSwingLen+1 (butuh InpSwingLen bar kanan)
   int center = InpSwingLen + 1;
   if(IsPivotHigh(center, InpSwingLen, p)){ g_swingHigh = p; g_brokeHigh = false; }
   if(IsPivotLow (center, InpSwingLen, p)){ g_swingLow  = p; g_brokeLow  = false; }
}

//--- cek FVG bullish dalam rentang impuls (gap: low[k] > high[k+2])
bool HasBullFVG(int fromShift, int span)
{
   for(int k=fromShift; k<=fromShift+span; k++)
      if(LowAt(k) > HighAt(k+2)) return true;
   return false;
}
bool HasBearFVG(int fromShift, int span)
{
   for(int k=fromShift; k<=fromShift+span; k++)
      if(HighAt(k) < LowAt(k+2)) return true;
   return false;
}

//--- cari index candle Order Block (candle berlawanan terakhir sebelum impuls)
int FindBullOB(){ for(int i=1;i<=InpOBLookback;i++) if(CloseAt(i)<OpenAt(i)) return i; return -1; }
int FindBearOB(){ for(int i=1;i<=InpOBLookback;i++) if(CloseAt(i)>OpenAt(i)) return i; return -1; }

//--- deteksi BOS/CHoCH pada bar tertutup terakhir (shift=1)
//    return: set flag struktur & buat OB ber-FVG.
void DetectStructureAndOB()
{
   double c = CloseAt(1);
   bool bosBull=false, bosBear=false, chochBull=false, chochBear=false;

   if(g_swingHigh>0 && c>g_swingHigh && !g_brokeHigh)
   {
      if(g_trend==DIR_SELL) chochBull=true; else bosBull=true;
      g_trend=DIR_BUY; g_brokeHigh=true;
   }
   if(g_swingLow>0 && c<g_swingLow && !g_brokeLow)
   {
      if(g_trend==DIR_BUY) chochBear=true; else bosBear=true;
      g_trend=DIR_SELL; g_brokeLow=true;
   }

   if(bosBull || chochBull)
   {
      int obi = FindBullOB();
      if(obi>0 && HasBullFVG(1, obi))
      {
         g_obBullActive=true; g_obBullTop=HighAt(obi); g_obBullBot=LowAt(obi); g_obBullBar=Bars(_Symbol,_Period);
      }
   }
   if(bosBear || chochBear)
   {
      int obj = FindBearOB();
      if(obj>0 && HasBearFVG(1, obj))
      {
         g_obBearActive=true; g_obBearTop=HighAt(obj); g_obBearBot=LowAt(obj); g_obBearBar=Bars(_Symbol,_Period);
      }
   }
}

//--- TP dinamis utk SMC: swing/level berikutnya searah arah trade
double NextKeyLevelSMC(int dir, double entry)
{
   double best = 0.0; double p;
   // scan pivot terkonfirmasi ke belakang untuk cari target searah
   for(int s=InpSwingLen+1; s<=InpKeyLevelScan; s++)
   {
      if(dir==DIR_BUY)
      {
         if(IsPivotHigh(s, InpSwingLen, p) && p>entry)
            if(best==0.0 || p<best) best=p;   // swing high terdekat di atas entry
      }
      else
      {
         if(IsPivotLow(s, InpSwingLen, p) && p<entry)
            if(best==0.0 || p>best) best=p;    // swing low terdekat di bawah entry
      }
   }
   return best;
}

//==================================================================
//  JALUR B : SnR  (level horizontal kuat -> rejection)
//==================================================================

//--- daftarkan/agregasi level SnR (dedupe by toleransi, hitung sentuhan)
void RegisterSnR(double price, bool isRes)
{
   double tol = PipsToPrice(InpRejectionPips*1.5);
   for(int i=0;i<ArraySize(g_snr);i++)
   {
      if(MathAbs(g_snr[i]-price)<=tol)
      {
         g_snrTouch[i]++;
         g_snr[i] = (g_snr[i]*0.7 + price*0.3); // rata-rata tertimbang agar stabil
         return;
      }
   }
   int n=ArraySize(g_snr);
   ArrayResize(g_snr, n+1); ArrayResize(g_snrTouch, n+1); ArrayResize(g_snrIsRes, n+1);
   g_snr[n]=price; g_snrTouch[n]=1; g_snrIsRes[n]=isRes;

   // trim level tertua bila melebihi batas
   if(ArraySize(g_snr) > InpSnRMaxLevels)
   {
      for(int k=0;k<ArraySize(g_snr)-1;k++){ g_snr[k]=g_snr[k+1]; g_snrTouch[k]=g_snrTouch[k+1]; g_snrIsRes[k]=g_snrIsRes[k+1]; }
      ArrayResize(g_snr, ArraySize(g_snr)-1); ArrayResize(g_snrTouch, ArraySize(g_snrTouch)-1); ArrayResize(g_snrIsRes, ArraySize(g_snrIsRes)-1);
   }
}

void UpdateSnRLevels()
{
   double p;
   int center = InpSnRPivotLen + 1;
   if(IsPivotHigh(center, InpSnRPivotLen, p)) RegisterSnR(p, true);
   if(IsPivotLow (center, InpSnRPivotLen, p)) RegisterSnR(p, false);
}

//--- cari level SnR kuat terdekat dgn harga (kembalikan index, -1 bila tak ada)
int NearestStrongSnR(double price, bool wantRes)
{
   int best=-1; double bestDist=DBL_MAX;
   for(int i=0;i<ArraySize(g_snr);i++)
   {
      if(g_snrTouch[i] < InpSnRMinTouch) continue;
      if(g_snrIsRes[i] != wantRes) continue;
      double d = MathAbs(g_snr[i]-price);
      if(d<bestDist){ bestDist=d; best=i; }
   }
   return best;
}

//--- TP dinamis utk SnR: garis SnR berikutnya searah arah trade
double NextKeyLevelSnR(int dir, double entry)
{
   double best=0.0;
   for(int i=0;i<ArraySize(g_snr);i++)
   {
      if(dir==DIR_BUY && g_snr[i]>entry){ if(best==0.0 || g_snr[i]<best) best=g_snr[i]; }
      if(dir==DIR_SELL&& g_snr[i]<entry){ if(best==0.0 || g_snr[i]>best) best=g_snr[i]; }
   }
   return best;
}

//==================================================================
//  RISK MODULE 30-60 PIPS (geser entry bila terlalu lebar)
//  return true bila valid; isi entryOut, slOut, slPipsOut.
//==================================================================
bool ApplyRisk(int dir, double rawEntry, double zoneTop, double zoneBot,
               double &entryOut, double &slOut, double &slPipsOut)
{
   double buf = PipsToPrice(InpSLBufferPips);
   double e   = rawEntry;
   double s   = (dir==DIR_BUY) ? (zoneBot - buf) : (zoneTop + buf);
   double dist= MathAbs(e - s);
   double pips= PriceToPips(dist);

   // --- terlalu lebar: geser entry ke 50% zona (equilibrium / lebih dekat sumbu) ---
   if(pips > InpMaxSLPips)
   {
      e    = (zoneTop + zoneBot) / 2.0;
      s    = (dir==DIR_BUY) ? (zoneBot - buf) : (zoneTop + buf);
      dist = MathAbs(e - s);
      pips = PriceToPips(dist);
      if(pips > InpMaxSLPips) return false;   // tetap terlalu lebar -> batalkan
   }
   // --- terlalu sempit: genapkan ke minimal ---
   if(pips < InpMinSLPips)
   {
      dist = PipsToPrice(InpMinSLPips);
      s    = (dir==DIR_BUY) ? (e - dist) : (e + dist);
      pips = InpMinSLPips;
   }

   entryOut=e; slOut=s; slPipsOut=pips;
   return true;
}

//--- hitung RR dari entry, sl, tp; return 0 bila tak valid
double ComputeRR(int dir, double entry, double sl, double tp)
{
   double risk   = MathAbs(entry - sl);
   double reward = (dir==DIR_BUY) ? (tp - entry) : (entry - tp);
   if(risk<=0 || reward<=0) return 0.0;
   return reward / risk;
}

//==================================================================
//  DEDUPLIKASI SINYAL (anti kirim sinyal sama di zona yang sama)
//==================================================================
//--- buang entri memori yang sudah kedaluwarsa (berbasis umur bar)
void PurgeDedup()
{
   if(InpDedupExpiryBars<=0) return;          // 0 = simpan selamanya
   int barsNow = Bars(_Symbol,_Period);
   int i=0;
   while(i<ArraySize(g_dedupRef))
   {
      if(barsNow - g_dedupBar[i] > InpDedupExpiryBars)
      {
         int last = ArraySize(g_dedupRef)-1;
         g_dedupStrat[i]=g_dedupStrat[last];
         g_dedupDir[i]  =g_dedupDir[last];
         g_dedupRef[i]  =g_dedupRef[last];
         g_dedupBar[i]  =g_dedupBar[last];
         ArrayResize(g_dedupStrat,last); ArrayResize(g_dedupDir,last);
         ArrayResize(g_dedupRef,last);   ArrayResize(g_dedupBar,last);
      }
      else i++;
   }
}

//--- true bila sinyal sejenis (strategi+arah) sudah pernah dikirim
//    di sekitar harga referensi yang sama (dalam toleransi pips).
bool IsDuplicate(const string strat, int dir, double refPrice)
{
   if(!InpUseDedup) return false;
   double tol = PipsToPrice(InpDedupPips);
   for(int i=0;i<ArraySize(g_dedupRef);i++)
   {
      if(g_dedupDir[i]==dir && g_dedupStrat[i]==strat &&
         MathAbs(g_dedupRef[i]-refPrice)<=tol)
         return true;
   }
   return false;
}

//--- catat sinyal ke memori dedup
void RememberSignal(const string strat, int dir, double refPrice)
{
   if(!InpUseDedup) return;
   int n=ArraySize(g_dedupRef);
   ArrayResize(g_dedupStrat,n+1); ArrayResize(g_dedupDir,n+1);
   ArrayResize(g_dedupRef,n+1);   ArrayResize(g_dedupBar,n+1);
   g_dedupStrat[n]=strat; g_dedupDir[n]=dir; g_dedupRef[n]=refPrice;
   g_dedupBar[n]=Bars(_Symbol,_Period);
}

//==================================================================
//  EVALUASI SINYAL PER JALUR (dipanggil sekali tiap bar baru)
//==================================================================
void EvaluateSMC()
{
   if(!InpEnableSMC) return;
   int barsNow = Bars(_Symbol,_Period);

   // BUY: tren bullish + OB bull aktif + harga (bar tertutup) menyentuh zona
   if(g_obBullActive && g_trend==DIR_BUY)
   {
      bool fresh = (barsNow - g_obBullBar) <= InpZoneMaxAge;
      bool touch = (LowAt(1) <= g_obBullTop && HighAt(1) >= g_obBullBot);
      if(fresh && touch)
      {
         double entry = CloseAt(1);
         double e,s,sp;
         if(ApplyRisk(DIR_BUY, entry, g_obBullTop, g_obBullBot, e,s,sp))
         {
            double tp = NextKeyLevelSMC(DIR_BUY, e);
            double rr = (tp>0) ? ComputeRR(DIR_BUY, e, s, tp) : 0.0;
            double ref = (g_obBullTop + g_obBullBot)/2.0;
            if(tp>0 && rr>=InpMinRR && !IsDuplicate("SMC", DIR_BUY, ref))
            {
               NotifySignal("SMC", DIR_BUY, e, s, tp, sp, rr);
               RememberSignal("SMC", DIR_BUY, ref);
               g_obBullActive=false;       // konsumsi zona setelah sinyal
               g_lastSMCTime=TimeAt(1);
            }
         }
      }
   }

   // SELL: tren bearish + OB bear aktif + sentuh zona
   if(g_obBearActive && g_trend==DIR_SELL)
   {
      bool fresh = (barsNow - g_obBearBar) <= InpZoneMaxAge;
      bool touch = (LowAt(1) <= g_obBearTop && HighAt(1) >= g_obBearBot);
      if(fresh && touch)
      {
         double entry = CloseAt(1);
         double e,s,sp;
         if(ApplyRisk(DIR_SELL, entry, g_obBearTop, g_obBearBot, e,s,sp))
         {
            double tp = NextKeyLevelSMC(DIR_SELL, e);
            double rr = (tp>0) ? ComputeRR(DIR_SELL, e, s, tp) : 0.0;
            double ref = (g_obBearTop + g_obBearBot)/2.0;
            if(tp>0 && rr>=InpMinRR && !IsDuplicate("SMC", DIR_SELL, ref))
            {
               NotifySignal("SMC", DIR_SELL, e, s, tp, sp, rr);
               RememberSignal("SMC", DIR_SELL, ref);
               g_obBearActive=false;
               g_lastSMCTime=TimeAt(1);
            }
         }
      }
   }
}

void EvaluateSnR()
{
   if(!InpEnableSnR) return;

   double o=OpenAt(1), c=CloseAt(1), h=HighAt(1), l=LowAt(1);
   double bodyHi = MathMax(o,c), bodyLo = MathMin(o,c);
   double lowerWick = bodyLo - l;     // ekor bawah
   double upperWick = h - bodyHi;     // ekor atas
   double minWick = PipsToPrice(InpRejectionPips);

   // BUY @ Support: candle bullish dgn ekor bawah panjang menyentuh support kuat
   if(c>o && lowerWick>=minWick)
   {
      int idx = NearestStrongSnR(l, false);   // support
      if(idx>=0)
      {
         double lvl = g_snr[idx];
         // rejection valid: low menembus/menyentuh level lalu close balik di atas
         if(l<=lvl && c>lvl)
         {
            double entry=c;
            // zona "OB-like" utk risk: dari level support ke low candle
            double e,s,sp;
            if(ApplyRisk(DIR_BUY, entry, MathMax(lvl,bodyLo), l, e,s,sp))
            {
               double tp = NextKeyLevelSnR(DIR_BUY, e);
               double rr = (tp>0) ? ComputeRR(DIR_BUY, e, s, tp) : 0.0;
               if(tp>0 && rr>=InpMinRR && !IsDuplicate("SnR", DIR_BUY, lvl))
               {
                  NotifySignal("SnR", DIR_BUY, e, s, tp, sp, rr);
                  RememberSignal("SnR", DIR_BUY, lvl);
                  g_lastSnRTime=TimeAt(1);
               }
            }
         }
      }
   }

   // SELL @ Resistance: candle bearish dgn ekor atas panjang menyentuh resistance kuat
   if(c<o && upperWick>=minWick)
   {
      int idx = NearestStrongSnR(h, true);     // resistance
      if(idx>=0)
      {
         double lvl = g_snr[idx];
         if(h>=lvl && c<lvl)
         {
            double entry=c;
            double e,s,sp;
            if(ApplyRisk(DIR_SELL, entry, h, MathMin(lvl,bodyHi), e,s,sp))
            {
               double tp = NextKeyLevelSnR(DIR_SELL, e);
               double rr = (tp>0) ? ComputeRR(DIR_SELL, e, s, tp) : 0.0;
               if(tp>0 && rr>=InpMinRR && !IsDuplicate("SnR", DIR_SELL, lvl))
               {
                  NotifySignal("SnR", DIR_SELL, e, s, tp, sp, rr);
                  RememberSignal("SnR", DIR_SELL, lvl);
                  g_lastSnRTime=TimeAt(1);
               }
            }
         }
      }
   }
}

//==================================================================
//  EVENT HANDLERS
//==================================================================
int OnInit()
{
   ArrayResize(g_snr,0); ArrayResize(g_snrTouch,0); ArrayResize(g_snrIsRes,0);
   ArrayResize(g_dedupStrat,0); ArrayResize(g_dedupDir,0); ArrayResize(g_dedupRef,0); ArrayResize(g_dedupBar,0);
   g_lastBarCount = Bars(_Symbol,_Period);
   PrintFormat("XAUUSD SMC+SnR Signal EA v3.0 aktif | SMC=%s SnR=%s | TF=%s",
               (InpEnableSMC?"ON":"OFF"), (InpEnableSnR?"ON":"OFF"), EnumToString(_Period));
   if(InpUseTelegram && (InpBotToken=="" || InpChatID==""))
      Print("PERINGATAN: Token/Chat ID Telegram kosong. Isi input agar notifikasi terkirim.");

   // --- TES KONEKSI: kirim pesan instan ke Telegram saat EA dipasang/refresh ---
   if(InpUseTelegram && InpSendTestOnInit)
      SendConnectionTest();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ }

void OnTick()
{
   // Proses HANYA saat bar baru terbentuk (anti-repaint: evaluasi pada bar tertutup)
   int barsNow = Bars(_Symbol,_Period);
   if(barsNow == g_lastBarCount) return;
   g_lastBarCount = barsNow;

   // butuh cukup histori
   int need = MathMax(InpKeyLevelScan, InpOBLookback) + InpSwingLen + 5;
   if(barsNow < need) return;

   // 1) update struktur & level (berbasis bar tertutup)
   UpdateSwings();
   UpdateSnRLevels();

   // 2) deteksi break & bentuk OB (SMC)
   DetectStructureAndOB();

   // 2b) bersihkan memori dedup yang kedaluwarsa
   PurgeDedup();

   // 3) cooldown sederhana per-jalur (dalam satuan bar)
   datetime barTime = TimeAt(1);
   long secPerBar = (long)PeriodSeconds(_Period);
   bool smcCooled = (g_lastSMCTime==0) || ((long)(barTime - g_lastSMCTime) >= secPerBar*InpCooldownBars);
   bool snrCooled = (g_lastSnRTime==0) || ((long)(barTime - g_lastSnRTime) >= secPerBar*InpCooldownBars);

   // 4) evaluasi sinyal (dua jalur terpisah)
   if(smcCooled) EvaluateSMC();
   if(snrCooled) EvaluateSnR();
}
//+------------------------------------------------------------------+
