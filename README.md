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
| 13 | **Session Filter (WIB)** | Sinyal hanya 13:00–22:00 WIB (London/New York) untuk menghindari jam sepi/whipsaw. |
| 14 | **Alert Telegram** | `alertcondition` + fungsi `alert()` dinamis dengan format pesan rapi (termasuk jarak SL dalam pips). |

---

## 📂 Struktur Repo

```
xauusd-entry-plan/
├── README.md
├── indicators/
│   └── XAUUSD_SMC_Signal.pine    # Script indikator SMC (Pine v6)
└── docs/
    └── entry-plan.md             # Checklist & rencana entry SMC
```

---

## 🚀 Cara Pasang di TradingView

1. Buka **Pine Editor** di TradingView (bar bawah).
2. Salin seluruh isi [`indicators/XAUUSD_SMC_Signal.pine`](indicators/XAUUSD_SMC_Signal.pine) dan **paste** ke editor.
3. Klik **Save**, beri nama, lalu **Add to chart**.
4. Buka chart **XAU/USD** (mis. `OANDA:XAUUSD`) dan pilih timeframe **M3 / M5 / M15 / H1**.

## 🔔 Cara Aktifkan Alert (Webhook Telegram)

1. Klik ikon **Alerts → Create Alert**.
2. **Condition**: pilih `XAU SMC v2.3` → **"Any alert() function call"**.
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
