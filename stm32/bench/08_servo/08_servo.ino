// AUV tezgah testi 08 - MG996R servo (TEK SERVO, YUKSUZ)
// GUC: Servo 5V'i UBEC'ten gelir. STM32 3V3'ten ASLA besleme (akim ceker, reset atar).
// Baglanti:
//   LiPo -> XT60 -> sigorta -> UBEC giris
//   UBEC 5V  -> servo kirmizi
//   UBEC GND -> servo kahverengi VE STM32 GND (ortak toprak SART)
//   STM32 PB4 -> servo turuncu (sinyal)
//   Servo besleme uclarina yakin 470 uF 35V kondansator (+ -> 5V, - -> GND)
// GUVENLIK: Servo koluna hicbir sey bagli olmasin. Ilk testte kolu cikar.
//   Servo titriyor/isiniyorsa hemen kes: UBEC 3A, MG996R stall 2.5A ceker.
// Kontrol (seri terminal):
//   c = merkez 1500us   |   a = -50us   |   d = +50us
//   w = 1200..1800 arasi yavas supurme (bir tur)   |   s = darbeyi kes
// Basari: acisal hareket duzgun, ses tek tip, UBEC ve servo isinmiyor,
//         STM32 resetlenmiyor (tick sayaci sifirlanmiyor).

#include <Servo.h>

// Serial = USART1 (PA9 TX / PA10 RX)
Servo sv;
const int SERVO_PIN = PB4;   // ikinci servo icin PB5
int us = 1500;

void setup() {
  Serial.begin(115200);
  delay(300);
  sv.attach(SERVO_PIN, 1000, 2000);
  sv.writeMicroseconds(us);
  Serial.println();
  Serial.println("AUV bench 08: MG996R @ PB4. komut: c a d w s");
  Serial.println("Servo kolu CIKARILMIS olsun.");
}

void loop() {
  if (Serial.available()) {
    char k = Serial.read();
    if (k == 'c') { us = 1500; sv.writeMicroseconds(us); }
    else if (k == 'a') { us = max(1200, us - 50); sv.writeMicroseconds(us); }
    else if (k == 'd') { us = min(1800, us + 50); sv.writeMicroseconds(us); }
    else if (k == 's') { sv.detach(); Serial.println("darbe kesildi"); return; }
    else if (k == 'w') {
      Serial.println("supurme...");
      for (int p = 1200; p <= 1800; p += 10) { sv.writeMicroseconds(p); delay(30); }
      for (int p = 1800; p >= 1200; p -= 10) { sv.writeMicroseconds(p); delay(30); }
      us = 1500; sv.writeMicroseconds(us);
    }
    if (k != 's') { Serial.print("us="); Serial.println(us); }
  }
  delay(20);
}
