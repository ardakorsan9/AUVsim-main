# STM32 geliştirme durumu (herkese açık özet)

Bu belge, depodaki STM kodlarının **hangi seviyede** olduğunu ve **nasıl yarıda / geliştirilecek** paylaşıldığını anlatır.

## Kısa cevap

STM tarafı **~%40–50**: tezgah ve iskelet var; suda kapalı çevrim yol takibi yok.

## Seviye tablosu

| Seviye | Açıklama | Klasör |
|---|---|---|
| L0 Simülasyon | MATLAB path following + PID | `matlab/` |
| L1 Tezgah | Sensör/aktüatör tek tek | `stm32/tezgah/` |
| L2 Bringup | Disarm, PWM nötr | `stm32/gomulu/App` |
| L3 Güvenlik + mapper | FSM, PWM map | `stm32/gomulu/Src` |
| L4 Sensörlü kapalı çevrim | IMU+basınç → kontrol | **Henüz değil** |
| L5 Görev / path follow suda | Dal–git–çık | **Henüz değil** |

Paylaşım noktası: **L1–L3 (WIP)** · etiket `v0.3-wip-stm32`

## Katkı

- Yeni tezgah sketch → `stm32/tezgah/NN_isim/`  
- Gömülü özellik → `stm32/gomulu/` + host test  
- Checklist: [stm32/README.md](../stm32/README.md)
