# XAUUSD Entry Plan — SMC Signal Bot

Indikator **TradingView (Pine Script v6)** berbasis **Smart Money Concepts (SMC)** khusus untuk market **XAU/USD (Emas)**. Bersifat *signal-only* (pemberi sinyal, **bukan** auto-entry) dan dirancang untuk dihubungkan ke **Webhook Telegram** lewat TradingView Alert.

> ⚠️ **Disclaimer:** Repo ini adalah alat bantu teknikal & edukasi, **bukan saran finansial**. Sinyal SMC bersifat probabilistik. Selalu lakukan konfirmasi manual dan manajemen risiko Anda sendiri. **Backtest di akun demo** sebelum dipakai live.

---

## ✨ Fitur

| # | Fitur | Keterangan |
|---|-------|-----------|
| 1 | **Market Structure** | Deteksi Swing High/Low otomatis + label **BOS** (Break of Structure) & **CHoCH** (Change of Character) dengan arah Bullish/Bearish. |
| 2 | **Order Block (OB)** | Gambar zona OB valid (Demand/Supply) yang memicu break & memiliki Imbalance di depannya. Warna beda untuk Bullish vs Bearish. |
| 3 | **Fair Value Gap (FVG)** | Deteksi imbalance pola 3-candle, tandai yang sudah ter-mitigasi. |
| 4 | **Signal Engine** | BUY/SELL hanya saat: CHoCH/BOS → retrace → harga memitigasi OB / mengisi FVG searah tren. |
| 5 | **HTF Bias Filter** | Saring sinyal agar searah tren timeframe besar (multi-timeframe via `request.security`). |
| 6 | **Liquidity EQH/EQL** | Deteksi Equal Highs / Equal Lows (kolam likuiditas) dengan toleransi berbasis ATR. |
| 7 | **Auto SL / TP** | Hitung otomatis Entry, Stop Loss, Take Profit (berbasis zona + Risk:Reward). |
| 8 | **Strict TF Alignment** | BUY hanya jika **HTF & LTF sama-sama bullish**; SELL hanya jika keduanya bearish. Sinyal counter-trend dicoret total. |
| 9 | **Liquidity Sweep (Anti-Inducement)** | CHoCH baru dianggap valid jika **didahului liquidity sweep** (ekor menembus swing lalu close balik ke dalam range). |
| 10 | **Risk 30–60 Pips** | SL otomatis dalam pips: minimal 30 (anti-noise), maksimal 60. Jika OB terlalu lebar, **entry digeser ke 50% OB (equilibrium)**; jika masih >60 pips sinyal dicoret. |
| 11 | **Signal Quality (Anti Over-Trading)** | Cooldown antar sinyal, satu posisi aktif, syarat zona *fresh* (umur maksimal). |
| 12 | **Win-rate Counter (Intrabar)** | Mini-backtest dengan resolusi akurat via data timeframe lebih kecil + tampilan periode (Mulai/Akhir). |
| 13 | **OB + SnR Confluence (RBS/SBR)** | Sinyal hanya jika OB berimpit level SnR horizontal: **RBS** (Resistance-jadi-Support) untuk BUY, **SBR** (Support-jadi-Resistance) untuk SELL. |
| 14 | **Liquidity Pool (Equal H/L Sweep)** | Wajib ada sweep pool retail (Equal Lows/double bottom untuk BUY, Equal Highs/double top untuk SELL) sebelum konfirmasi entry. |
| 15 | **Breakeven (BEP) Notification** | Alert "Move SL to BEP" saat profit mencapai **+1R** atau harga menyentuh **SnR LTF terdekat**. |
| 16 | **Session Filter (WIB)** | Sinyal hanya 13:00–22:00 WIB (London/New York) untuk menghindari jam sepi/whipsaw. |
| 17 | **Alert Telegram** | `alertcondition` + fungsi `alert()` dinamis dengan format pesan rapi (termasuk jarak SL dalam pips & alert BEP). |

---

## 📂 Struktur Repo

```
xauusd-entry-plan/
├── README.md
├── indicators/
│   └── XAUUSD_SMC_Signal.pine        # Indikator SMC TradingView (Pine v6)
├── expert/
│   └── XAUUSD_SMC_SnR_Signal.mq5     # EA sinyal MQL5 (SMC + SnR, Telegram)
└── docs/
    └── entry-plan.md                 # Checklist & rencana entry SMC
```

> **Dua produk dalam satu repo:**
> - **Pine Script** (`indicators/`) → indikator untuk **TradingView**, alert via Webhook.
> - **MQL5 EA** (`expert/`) → signal bot untuk **MetaTrader 5**, notifikasi via Telegram WebRequest. Lihat bagian [EA MQL5](#-ea-mql5-metatrader-5--sinyal-smc--snr) di bawah.

---

## 🚀 Cara Pasang di TradingView

1. Buka **Pine Editor** di TradingView (bar bawah).
2. Salin seluruh isi [`indicators/XAUUSD_SMC_Signal.pine`](indicators/XAUUSD_SMC_Signal.pine) dan **paste** ke editor.
3. Klik **Save**, beri nama, lalu **Add to chart**.
4. Buka chart **XAU/USD** (mis. `OANDA:XAUUSD`) dan pilih timeframe **M3 / M5 / M15 / H1**.

## 🔔 Cara Aktifkan Alert (Webhook Telegram)

1. Klik ikon **Alerts → Create Alert**.
2. **Condition**: pilih `XAU SMC v2.4` → **"Any alert() function call"**.
3. **Trigger**: **Once Per Bar Close** (anti-repaint).
4. Tab **Notifications** → centang **Webhook URL** → isi URL relay/bot Telegram Anda.
5. Klik **Create**. Pesan terisi otomatis (BUY/SELL + harga + Entry/SL/TP).

> ℹ️ TradingView tidak mengirim langsung ke Telegram. Webhook butuh perantara (layanan relay webhook→Telegram atau server kecil Anda sendiri).

---

## ⚙️ Setting Disarankan untuk XAU/USD

| Chart TF | HTF (input) | Swing Length |
|----------|-------------|--------------|
| M3 / M5  | `60` (H1)   | 5–8          |
| M15      | `240` (H4)  | 8–12         |
| H1       | `D` (Daily) | 10–15        |

- **Buffer SL**: Gold volatil — coba `1.0`–`3.0` ($) tergantung TF.
- **Risk:Reward**: default `2.0`. Untuk scalping M3/M5 bisa turunkan ke `1.5`.

### 🎯 Tuning Kualitas Sinyal (Anti Over-Trading)

Jika sinyal terlalu sering muncul (over-trading), sesuaikan grup **"8. Signal Quality"**:

| Parameter | Fungsi | Saran |
|-----------|--------|-------|
| **Max umur zona (bar)** | Zona OB/FVG hanya valid jika dimitigasi dalam N bar setelah dibuat | Kecilkan (mis. `20-30`) agar hanya zona segar yang dipakai |
| **Cooldown antar sinyal (bar)** | Jarak minimal antar sinyal | Naikkan (mis. `15-20`) untuk mengurangi frekuensi |
| **Satu posisi aktif** | Tidak ada sinyal baru selama trade lama belum kena SL/TP | Biarkan `ON` |

> **Win% lebih rendah dari ekspektasi?** Aktifkan **"Resolusi akurat via data intrabar"** (grup 9). Tanpa ini, jika SL & TP tersentuh di bar yang sama, hasilnya hanya estimasi. RR 1:2 butuh win rate **>33%** untuk break-even.

### 🕒 Session Filter

Grup **"12. Session Filter (WIB)"** membatasi sinyal ke jam aktif. Default `1300-2200` (13:00–22:00 WIB = sesi London + New York), timezone `Asia/Jakarta`. Di luar jam ini bot tidak mengirim alert meski kondisi teknikal terpenuhi.

### 🎯 Strict TF Alignment, Liquidity Sweep & Risk 30–60 Pips (v2.3)

Tiga penyaring ketat untuk menaikkan winrate dan menekan false breakout:

| Filter | Grup input | Fungsi |
|--------|-----------|--------|
| **Strict TF Alignment** | 5 | `useStrictAlign`: BUY hanya jika HTF EMA bias **dan** struktur LTF sama-sama bullish (SELL kebalikannya). Mencoret semua sinyal counter-trend. |
| **Liquidity Sweep** | 6 | `useSweep`: CHoCH valid hanya jika dalam `sweepLookback` bar sebelumnya terjadi sweep (ekor menembus swing lalu close balik ke dalam range). Menghindari jebakan inducement. |
| **Risk 30–60 Pips** | 9 | `minPips`=30, `maxPips`=60, `pipValue`=0.10. SL dipaksa minimal 30 pips (anti-noise). Jika >60 pips → **Opsi B**: entry digeser ke 50% OB (equilibrium); jika masih >60 → sinyal dicoret. |

> **Catatan pip XAU/USD:** default `pipValue = 0.10` artinya 10 pips = $1.00 pergerakan harga. Jadi 30 pips = $3.00, 60 pips = $6.00. Sesuaikan dengan konvensi broker Anda jika berbeda.

#### Cara membaca naik-turunnya jumlah sinyal
Setelah v2.3, **jumlah trade akan turun drastis** (itu tujuannya). Yang dikejar adalah **kualitas**, bukan kuantitas. Target realistis winrate naik dari ~28% menuju 45%+ dengan RR 1:2.

### 🧩 OB + SnR Confluence, Liquidity Pool & BEP (v2.4)

Tiga tambahan untuk mendongkrak winrate lebih tinggi lagi dan mengamankan profit:

| Filter | Grup input | Fungsi |
|--------|-----------|--------|
| **OB + SnR Confluence** | 10 | `useSnR`: sinyal hanya valid jika OB berimpit level SnR horizontal. **BUY** butuh **RBS** (resistance lama jadi support), **SELL** butuh **SBR** (support lama jadi resistance). Toleransi diatur `snrTolPips`. |
| **Liquidity Pool Sweep** | 11 | `useLiqPool`: sebelum entry, harga wajib menyapu pool retail — **Equal Lows** (double bottom) untuk BUY, **Equal Highs** (double top) untuk SELL — dalam `liqPoolLookback` bar. |
| **BEP Notification** | 12 | `useBEP`: kirim alert **"Move SL to BEP"** saat profit mencapai **+1R** (RR 1:1) atau harga menyentuh **SnR LTF terdekat**. Bantu amankan posisi agar profit tak berbalik jadi loss. |

> **Panel baru:** baris **"SnR/Pool"** menampilkan jumlah level SnR aktif dan status sweep pool (`B` = Equal Lows tersapu untuk BUY, `S` = Equal Highs tersapu untuk SELL). Marker biru **"BEP"** muncul di chart saat trigger breakeven.

> **Catatan SnR:** garis **oranye** = level dari pivot High (potensi resistance/RBS), garis **biru** = dari pivot Low (potensi support/SBR). Bot otomatis mendeteksi confluence; Anda tinggal cek visual.

---

## 📨 Contoh Pesan Alert

```
[⚠️ XAUUSD SMC SIGNAL]
Type: BUY
Price: 2345.60
Timeframe: 15
Entry: 2345.60
SL: 2342.10
TP: 2352.60  (RR 1:2)
Note: Mitigasi Zone OB/FVG searah HTF. Konfirmasi manual sebelum entry.
```

---

## 🤖 EA MQL5 (MetaTrader 5) — Sinyal SMC & SnR

File: [`expert/XAUUSD_SMC_SnR_Signal.mq5`](expert/XAUUSD_SMC_SnR_Signal.mq5) — **signal-only** (TIDAK auto-entry/auto-order). Mengirim notifikasi ke Telegram langsung dari MT5 via `WebRequest`.

### Karakter EA (revisi v3.0)

| Aspek | Keterangan |
|-------|-----------|
| **Dua strategi TERPISAH** | **Jalur A (SMC)**: BOS/CHoCH anti-repaint (close candle) → retrace → mitigasi **Order Block ber-FVG**. **Jalur B (SnR)**: level Support/Resistance horizontal kuat → **rejection** valid (Buy di Support, Sell di Resistance). Notifikasi ditandai sebagai `SMC` atau `SnR` — tidak digabung. |
| **24 jam nonstop** | **Tanpa session filter.** Bot mencari peluang selama market emas buka. |
| **TP Dinamis** | TP otomatis ke **key-level berikutnya**: SMC → swing high/low terdekat searah; SnR → garis SnR berikutnya. **RR dihitung otomatis** (mis. SL 40 pips, jarak TP 80 pips → ditulis `1:2`). |
| **SL 30–60 pips** | <30 pips → digenapkan 30. >60 pips → entry digeser (SMC: 50% OB; SnR: lebih dekat ke sumbu level). Jika tetap >60 → **sinyal dibatalkan**. |
| **Anti-repaint** | Evaluasi hanya pada **bar tertutup** (shift=1) dan diproses sekali per bar baru. |

### ⚙️ Cara Pasang di MetaTrader 5

1. Buka **MetaEditor** (F4 di MT5) → **File → Open Data Folder** → masuk `MQL5/Experts/`.
2. Salin `XAUUSD_SMC_SnR_Signal.mq5` ke folder tersebut.
3. Di MetaEditor, buka file lalu klik **Compile** (F7). Pastikan 0 error.
4. Di MT5, buka chart **XAUUSD**, drag EA dari **Navigator → Expert Advisors** ke chart.
5. Centang **Allow Algo Trading** (untuk WebRequest), lalu isi parameter input.

### 🔑 WAJIB: Allowlist WebRequest (agar Telegram jalan)

`WebRequest` diblokir secara default. Aktifkan dulu:

1. MT5 → **Tools → Options → Expert Advisors**.
2. Centang **"Allow WebRequest for listed URL"**.
3. Tambahkan URL: `https://api.telegram.org`
4. Klik **OK**.

> Tanpa langkah ini, EA akan mencetak error `WebRequest gagal (err 4060/5203...)` di tab Experts.

### 🔧 Setup Telegram (input EA)

| Input | Isi dengan |
|-------|-----------|
| `InpBotToken` | Token dari **@BotFather** (mis. `123456:ABC-xyz...`) |
| `InpChatID` | Chat ID tujuan (dapatkan via `https://api.telegram.org/bot<TOKEN>/getUpdates`) |
| `InpEnableSMC` / `InpEnableSnR` | Aktif/nonaktifkan tiap jalur strategi |
| `InpPipSize` | `0.10` untuk XAUUSD (10 pips = $1.00) — sesuaikan dgn broker |
| `InpMinSLPips` / `InpMaxSLPips` | `30` / `60` (default) |
| `InpMinRR` | RR minimal agar sinyal dikirim (default `1.0`) |

### 📨 Contoh Pesan Telegram (EA)

```
🚨 [XAUUSD LIVE SIGNAL] 🚨
Strategi: SMC
Aksi: BUY
Harga Entry: 2345.60
Target SL: 35.0 pips (2342.10)
Target TP: 2352.60
Dinamis RR: 1:2.00
```
