// AUV tezgah testi 03 - I2C tarayici
// Baglanti: SADECE Type-C (LiPo YOK)
//   MPU6050 #1: VCC->3V3  GND->GND  SCL->PB6  SDA->PB7  AD0->bos/GND  => 0x68
//   MPU6050 #2: ayni hat, AD0->3V3                                    => 0x69
//   UART: PA9->CP2102 RXD, PA10->CP2102 TXD, GND ortak
// Basari: 0x68 (ve ikinci sensor varsa 0x69) listelenir.
//         Hicbir adres yoksa SDA/SCL ters, GND ortak degil ya da VCC yok.

#include <Wire.h>

// Serial = USART1 (PA9 TX / PA10 RX)

void setup() {
  Serial.begin(115200);
  delay(300);
  Wire.setSCL(PB6);
  Wire.setSDA(PB7);
  Wire.begin();
  Wire.setClock(100000);  // tezgahta 100 kHz, uzun jumper toleransi icin
  Serial.println();
  Serial.println("AUV bench 03: I2C tarama (PB6=SCL, PB7=SDA)");
}

void loop() {
  int found = 0;
  Serial.println("--- tarama ---");
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print("bulundu: 0x");
      Serial.println(addr, HEX);
      found++;
    }
  }
  if (found == 0) Serial.println("cihaz yok - kablo/GND/VCC kontrol");
  Serial.print("toplam=");
  Serial.println(found);
  delay(2000);
}
