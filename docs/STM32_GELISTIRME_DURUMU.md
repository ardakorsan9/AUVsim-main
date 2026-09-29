# STM32 geliştirme durumu (herkese açık özet)

Bu belge, depodaki STM kodlarının **hangi seviyede** olduğunu ve **nasıl yarıda bırakılmış / geliştirilecek** şekilde paylaşıldığını anlatır.

## Kısa cevap

STM tarafı **~%40–50**: tezgah ve iskelet var; suda kapalı çevrim yol takibi yok.

## Seviye tablosu

| Seviye | Açıklama | Bu depoda |
|---|---|---|
| L0 Simülasyon | MATLAB path following + PID | Olgun |
| L1 Tezgah | Sensör/aktüatör tek tek | `firmware/bench_arduino` |
| L2 Bringup | Disarm, PWM nötr, zamanlayıcı | `App/auv_bringup`, CubeMX |
| L3 Güvenlik + mapper | FSM, PWM map, telemetri iskeleti | `Src/` / `Inc/` (host testli) |
| L4 Sensörlü kapalı çevrim | IMU+basınç → kontrol → PWM | **Henüz değil** |
| L5 Görev / path follow suda | Dal–git–çık, kalibre metre | **Henüz değil** |

Şu an paylaşım noktası: **L1–L3 arası (WIP)**.

## Neden böyle yüklüyoruz?

1. Bitmiş ürün gibi görünmesin diye `firmware/README.md` içinde WIP / checklist var.  
2. Tezgah sketch’leri ile “asıl” `auv_f411` ayrı — karışmasın.  
3. İlerleme GitHub Issues / README checkbox ile takip edilir.  
4. Sürüm etiketi: `v0.3-wip-stm32` (pre-release).

## Katkı / devam

Pull request veya doğrudan commit ile:

- Yeni tezgah sketch → `firmware/bench_arduino/NN_isim/`  
- Gömülü özellik → `App/` veya `Src/` + host test  
- README checklist’i güncelle
