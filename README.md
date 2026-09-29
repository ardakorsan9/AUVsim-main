# Otonom Sualtı Aracı (AUV) — MATLAB + STM32

Bu depo **anlaşılır iki ana klasöre** ayrılmıştır:

| Klasör | İçerik |
|---|---|
| [`matlab/`](matlab/) | Simülasyon, yol takibi, PID / guidance / dinamik |
| [`stm32/`](stm32/) | Tezgah sketch’leri + gömülü iskelet (**WIP**) |
| [`docs/`](docs/) | PDF ve durum belgeleri |
| [`tools/`](tools/) | Codegen / doğrulama yardımcıları |

**PDF:** [docs/sualti.pdf](docs/sualti.pdf)  
**STM WIP durumu:** [docs/STM32_GELISTIRME_DURUMU.md](docs/STM32_GELISTIRME_DURUMU.md)

---

## Hızlı başlangıç (MATLAB)

```matlab
cd('.../AUVsim-main')   % repo kökü
setup_auv_path          % matlab/* path'e eklenir
underwater777_vehicle_simulation
% veya: test_helix / test_straight_line
```

MATLAB alt klasörleri: [`matlab/README.md`](matlab/README.md)

---

## 1. Araç nasıl bir şey?

Hedef platform: **tek pervaneli**, **iki servo** (dümen + elevator) küçük AUV.

| Özellik | Açıklama |
|---|---|
| İtki | A2212 ~930 KV + ESC 30A (çift yön) |
| Yön / pitch | 2× MG996R (PB4 / PB5) |
| Derinlik | MPS20N0040D + HX710 |
| Tutum | MPU6050 |
| Sızıntı | Leak / yağmur AO |
| Beyin | STM32F411 BlackPill |
| Enerji | 3S LiPo → sigorta → ESC + UBEC 5V (servo) |
| Tezgah | CP2102 UART, ST-Link SWD |

Simülasyonda x,y,z tam bilinir. Donanımda **z ≈ basınç**; yatay mesafe kalibrasyonlu ölü reckoning (sualtında GPS yok).

---

## 2. Elektronik (özet)

STM32F411, ST-Link, CP2102, MPU6050, MPS20, leak, 2× servo, motor, ESC, UBEC, 3S LiPo, XT60, sigorta, 470 µF / 100 nF / dirençler, pertinaks.

ESC BEC 5V **bağlanmaz**. Servo **UBEC 5V**.

Pin özeti: ESC PB0 · servo PB4/PB5 · I2C PB6/PB7 · basınç PB12/PB13 · leak PA5 · UART PA9/PA10.

---

## 3. STM32 (WIP)

```
stm32/
  tezgah/     ← 01_blink ... 17_goto_222
  gomulu/     ← CubeMX + App + Src + generated
```

Seviye: tezgah + bringup **orta**; suda kapalı çevrim **erken**.  
Ayrıntı: [stm32/README.md](stm32/README.md)

---

## 4. Depo haritası

```
AUVsim-main/
├── README.md                 ← buradasınız
├── setup_auv_path.m          ← MATLAB path
├── matlab/
│   ├── cekirdek/             ← asıl simülasyon
│   ├── testler/
│   ├── yol_ve_cizim/
│   ├── codegen/
│   └── deneyler/             ← run_* denemeleri (ileri seviye)
├── stm32/
│   ├── tezgah/
│   └── gomulu/
├── docs/
│   ├── sualti.pdf
│   └── STM32_GELISTIRME_DURUMU.md
└── tools/
```

---

## Lisans / güvenlik

Öğrenci prototipi. Tezgahta pervanesiz test; LiPo güvenliği.
