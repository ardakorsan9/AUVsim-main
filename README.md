# Otonom Sualtı Aracı (AUV) — MATLAB Simülasyon + Donanım Getirme

Bu depo, **6-DOF sualtı araç dinamiği**, **yörünge / yol takibi (path following)** ve **PID / PD tabanlı kontrol** içeren MATLAB simülasyonunu ve STM32’ye giden gömülü iskeleti paylaşır.

**Belge (PDF):** [docs/sualti.pdf](docs/sualti.pdf)

---

## 1. Araç nasıl bir şey?

Hedef platform: **tek pervaneli (thruster), iki kanatçıklı (dümen + elevator)** küçük bir otonom sualtı aracı (AUV).

| Özellik | Açıklama |
|---|---|
| Gövde | Kapalı tüp / kavanoz tipi basınç gövdesi (prototip) |
| İtki | Fırçasız motor (**A2212 ~930 KV**) + çift yönlü **ESC 30A** |
| Yön / pitch | **2× MG996R** servo (dümen PB4, elevator PB5) |
| Derinlik | Basınç modülü (**MPS20N0040D + HX710**) — hava kapanı / hortum yöntemi |
| Tutum | **MPU6050** (ivme + jiroskop) |
| Sızıntı | Yağmur / leak plakası (ADC) |
| Beyin | **STM32F411CE** BlackPill |
| Enerji | **3S LiPo** → sigorta → ESC + **UBEC 5V** (servo) |
| Telemetri (tezgah) | **CP2102** UART; programlama **ST-Link V2** |

Simülasyonda araç **tam durum bilgisi** (x, y, z, tutum) ile yol takip eder. Gerçek donanımda **z ≈ basınç**, yatay mesafe ise kalibrasyonlu ölü reckoning ile tahmin edilir (sualtında GPS çalışmaz).

MATLAB tarafında doğrulanmış senaryolar: düz hat, daire, helix; guidance + controller ayrımı vardır.

---

## 2. Alınan elektronik malzemeler (prototip listesi)

| Parça | Adet / not |
|---|---|
| WeAct STM32F411CEU6 BlackPill (25 MHz HSE) | 1 |
| ST-Link V2 | 1 |
| CP2102 USB–UART | 1 |
| MPU6050 (GY-521) | 1–2 |
| MPS20N0040D basınç + HX710 | 1 |
| Yağmur / leak sensörü | 1–3 |
| MG996R servo | 2 |
| A2212 930KV fırçasız motor | 1 |
| Bidirectional ESC 30A | 1 |
| UBEC 5V 3A | 1 |
| 3S LiPo 2200 mAh | 1 |
| XT60, 12 AWG, sigorta (20A sınıfı) | güç hattı |
| 470 µF 35V, 100 nF, direnç seti | filtre / PWM / batarya bölücü |
| Pertinaks, jumper, makaron | montaj |

**Not:** ESC üzerindeki BEC 5V kablosu **bağlanmaz** (UBEC ile çakışmasın). Servolar STM 5V’den değil **UBEC 5V**’den beslenir.

---

## 3. Sistem nasıl kurulur?

### 3.1 Güç

```
LiPo (+) ─ XT60 ─ sigorta ─┬─ ESC (+)
                           └─ UBEC IN (+)
LiPo (−) ──────────────────┬─ ESC (−)
                           └─ UBEC IN (−) / ortak GND

UBEC 5V → servo kırmızıları
UBEC GND → servo GND + STM GND (ortak toprak şart)
```

ESC batarya girişine ve UBEC 5V çıkışına **470 µF** (paralel). PWM hatlarında isteğe bağlı **330 Ω seri + 10 kΩ pulldown**.

Batarya gerilim ölçümü (opsiyonel ADC): `10k / 3.3k` bölücü → STM **PA4** (+ 100 nF).

### 3.2 Sinyal pinleri (BlackPill F411)

| İşlev | Pin |
|---|---|
| ESC PWM | PB0 |
| Servo dümen | PB4 |
| Servo elevator | PB5 |
| I2C SCL / SDA (MPU) | PB6 / PB7 |
| Basınç SCK / DOUT | PB12 / PB13 |
| Leak AO | PA5 (ve PA6/PA7) |
| UART TX / RX (CP2102) | PA9 / PA10 |
| SWD | PA13 / PA14 |
| LED | PC13 |

### 3.3 MATLAB simülasyon

1. MATLAB’da proje kökünü path’e ekleyin.
2. Ana çalıştırma: `underwater777_vehicle_simulation`
3. Testler: `test_straight_line`, `test_circle`, `test_helix`, `test_yaw_control`, `test_pitch_control`, `test_speed_control`
4. Çekirdek dosyalar: `guidance_law.m`, `controller_law.m`, `underwater777_vehicle_dynamics.m`, `init_parameters.m`

### 3.4 Donanım tezgahı (Arduino-cli / sketch’ler)

Tezgah sketch’leri ayrı klasörde geliştirildi (`bench_auv`: blink → UART → I2C → MPU → basınç → servo → ESC → açık çevrim → görev iskeleti).  
Bu depodaki `firmware/stm32f411` ise **CubeMX + bringup + güvenlik FSM + PWM mapper + MATLAB codegen iskeleti**dir.

---

## 4. Depo yapısı (özet)

| Yol | İçerik |
|---|---|
| `*.m` (kök) | Dinamik, guidance, kontrol, simülasyon, testler |
| `firmware/stm32f411/` | STM32F411 iskelet, App bringup, host testleri |
| `tools/` | Doğrulama / yardımcı scriptler |
| `docs/sualti.pdf` | Proje PDF belgesi |
| `suite_results/` | Seçilmiş kanıt / golden dosyalar (ağır çıktılar gitignore’da) |

---

## 5. STM32 kod seviyesi (özet)

Ayrıntılı seviye değerlendirmesi commit notlarında ve proje durumuna göre güncellenir. Kısa hali:

- **Simülasyon (MATLAB):** Yol takibi + PID doğrulanmış — **yüksek olgunluk**
- **Gömülü bringup / tezgah:** PWM nötr, disarm, sensör/aktüatör tezgah testleri — **orta**
- **Kapalı çevrim otonom (suda metre-metre path follow):** Sensör kalibrasyonu + gövde modeli uyumu gerekir — **erken / ön-otonom**

---

## 6. Lisans / kullanım

Öğrenci / araştırma prototipi. Donanımda **pervanesiz** tezgah testi yapın; LiPo ve su güvenliğine dikkat edin.

## Kullanım (MATLAB)

```matlab
underwater777_vehicle_simulation
% veya
test_helix
test_straight_line
```

---

*Açık depo: herkese açık paylaşım için hazırlanmıştır.*
