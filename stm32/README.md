# STM32 — WIP (yarıya kadar, geliştirilecek)

> Bitmiş uçuş yazılımı değil. Tezgah + gömülü iskelet.

## Klasörler (bakınca net)

| Klasör | Ne |
|---|---|
| **`tezgah/`** | Arduino-cli sketch’leri `01`…`17` — parça parça donanım testi |
| **`gomulu/`** | Asıl STM32F411 projesi: CubeMX, App bringup, safety, PWM mapper, MATLAB codegen |

## Olgunluk

- Tezgah: sensör/servo/ESC çalıştı  
- Gömülü: disarm + PWM nötr + host testleri  
- Kapalı çevrim otonom (suda): **henüz yok** → sıradaki iş  

Detay: [`../docs/STM32_GELISTIRME_DURUMU.md`](../docs/STM32_GELISTIRME_DURUMU.md)

## Geliştirme sırası

1. `tezgah/17_goto_222` sensör sağlığı  
2. `gomulu/cubemx` pinleri tezgahla kilitle  
3. Sensörleri `gomulu` bringup’a taşı  
4. Safety + PWM mapper’ı gerçek komutla besle  
5. Havuzda derinlik → sonra birleşik görev  
