// AUV tezgah testi 09 - Bidirectional ESC 30A + A2212 930KV
// !!! EN RISKLI TEST. PERVANE TAKMA. MOTORU MASAYA KELEPCE/BANT ILE SABITLE. !!!
// !!! A2212 SU MOTORU DEGIL - SUYA SOKMA, sadece havada kisa sureli calistir. !!!
//
// Baglanti:
//   LiPo -> XT60 -> 20A sigorta -> ESC guc girisi
//   ESC 3 faz -> motor 3 kablo (sira onemsiz; yon terse donerse 2 kablo degistir)
//   ESC sinyal (turuncu/beyaz) -> STM32 PB0
//   ESC GND (kahverengi/siyah) -> STM32 GND   <-- ORTAK TOPRAK SART
//   ESC kirmizi (BEC 5V) -> BAGLAMA (UBEC ile cakisir, ac birak/izole et)
//   ESC guc girisine yakin 470 uF 35V kondansator
//
// Bidirectional ESC: 1500us = NOTR/STOP, 1500-2000 ileri, 1000-1500 geri.
//
// PROTOKOL: kod acilista 1500us gonderip ARM eder ve orada BEKLER.
//   Motor kendiliginden donmez. Her adim senin komutunla, +/-20us.
//   ' ' (bosluk) veya herhangi bir tanimsiz tus = ANINDA 1500 (acil stop)
//   f = +20us   b = -20us   x = 1500 stop   r = rapor
// GUVENLIK LIMITI: kod 1400-1600 araligini asmaz (~%20 gaz). Yeterli.
// Basari: motor iki yonde de yumusak baslar, ESC/motor asiri isinmaz,
//         STM32 resetlenmez (arm_ms artmaya devam eder).

#include <Servo.h>

// Serial = USART1 (PA9 TX / PA10 RX)
Servo esc;
const int ESC_PIN = PB0;
const int NEUTRAL = 1500;
const int LIM_LO  = 1400;   // guvenlik siniri - degistirmeyin
const int LIM_HI  = 1600;
int us = NEUTRAL;
uint32_t last_cmd = 0;

void send(int v) {
  us = constrain(v, LIM_LO, LIM_HI);
  esc.writeMicroseconds(us);
  last_cmd = millis();
}

void setup() {
  Serial.begin(115200);
  delay(300);
  esc.attach(ESC_PIN, 1000, 2000);
  esc.writeMicroseconds(NEUTRAL);
  Serial.println();
  Serial.println("AUV bench 09: ESC arm ediliyor, 1500us, 5 sn...");
  Serial.println("PERVANE YOK, MOTOR SABIT MI? Degilse simdi LiPo'yu cek.");
  for (int i = 5; i > 0; i--) { Serial.println(i); delay(1000); }
  Serial.println("ARM tamam. komut: f=+20 b=-20 x=stop r=rapor, digerleri=ACIL STOP");
  last_cmd = millis();
}

void loop() {
  if (Serial.available()) {
    char k = Serial.read();
    if      (k == 'f') send(us + 20);
    else if (k == 'b') send(us - 20);
    else if (k == 'x') send(NEUTRAL);
    else if (k == 'r') { /* sadece rapor */ }
    else if (k == '\r' || k == '\n') { /* yoksay */ }
    else { send(NEUTRAL); Serial.println("ACIL STOP"); }
    Serial.print("us="); Serial.print(us);
    Serial.print(" gaz%="); Serial.print((us - NEUTRAL) / 5.0, 0);
    Serial.print(" arm_ms="); Serial.println(millis());
  }

  // Watchdog: 3 sn komut gelmezse notre don (kablo kopsa motor durur)
  if (us != NEUTRAL && millis() - last_cmd > 3000) {
    send(NEUTRAL);
    Serial.println("watchdog -> notr");
  }
  delay(10);
}
