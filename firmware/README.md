# STM32 / tezgah kodları — GELİŞTİRME AŞAMASI (WIP)

> **Durum: yarıya kadar getirilmiş prototip.**  
> Bu klasör “bitmiş uçuş yazılımı” değildir. Amaç: çalışan tezgah + iskelet firmware’i herkese açık bırakıp **üzerine geliştirmek**.

Etiket: `pre-release` / `wip-stm32` · Hedef sürüm: `v0.4-bringup` → `v1.0-closed-loop` (henüz yok)

---

## İki katman

| Klasör | Ne | Olgunluk |
|---|---|---|
| `bench_arduino/` | Arduino-cli tezgah sketch’leri (01…17) | Parça testleri **çalıştı** |
| `cubemx/` + `App/` + `Src/` + `Inc/` | Asıl `auv_f411` iskeleti (HAL, PWM, safety, codegen) | Bringup **var**, kapalı çevrim **yok** |
| `generated/` | MATLAB codegen çıktısı | Üretilmiş; tick’e bağlanacak |
| `host_tests/` / `host_integration/` | PC’de mantık testleri | Simülasyon yanlı |

---

## Ne bitti / ne eksik

### Bitti (tezgah)
- [x] Blink, UART (CP2102), I2C, MPU6050
- [x] Basınç HX710 okuma (tezgah)
- [x] Servo / ESC güç hattı ve PWM
- [x] Açık çevrim güç profili, sıralı test
- [x] Otonom **iskelet** sketch (`15`, `17`) — kalibrasyonsuz

### Devam edilecek (gömülü / otonom)
- [ ] IMU pitch/yaw düzgün kalibrasyon (düzken ~0°)
- [ ] Basınç → metre derinlik kalibrasyonu
- [ ] CubeMX’e I2C + ADC + basınç GPIO
- [ ] `auv_f411` içinde sensör → tick → PWM kapalı çevrim
- [ ] MATLAB `controller_law` kazançlarını gövdeye uyarlama
- [ ] Görev: `2 m dal → ~N m ileri → yüzeye` kabul testi
- [ ] (İleride) DVL / sonar — opsiyonel

---

## Nasıl geliştirilir (önerilen sıra)

1. `bench_arduino/17_goto_222` ile sensör sağlığı  
2. CubeMX pinleri tezgahla kilitle  
3. Bringup’a sensör sürücülerini taşı  
4. Safety FSM + PWM mapper’ı gerçek komutla besle  
5. Havuzda tek eksen (sadece derinlik), sonra birleşik görev  

---

## Uyarı

- Pervanesiz tezgah; LiPo güvenliği  
- ESC BEC 5V bağlanmaz; servo UBEC’ten  
- Bu kodu “suya indir otonom” diye sunmayın — **WIP**
