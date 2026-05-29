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
| 8 | **Win-rate Counter** | Mini-backtest: lacak tiap sinyal kena TP (Win) atau SL (Loss), tampil di panel. |
| 9 | **Alert Telegram** | `alertcondition` + fungsi `alert()` dinamis dengan format pesan rapi. |

---

## 📂 Struktur Repo

```
xauusd-entry-plan/
├── README.md
├── indicators/
│   └── XAUUSD_SMC_Signal.pine    # Script indikator SMC (Pine v5)
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
2. **Condition**: pilih `XAU SMC v2.1` → **"Any alert() function call"**.
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
