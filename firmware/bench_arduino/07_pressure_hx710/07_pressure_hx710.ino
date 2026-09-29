// AUV tezgah testi 07 - MPS20N0040D + HX710B derinlik/basinc modulu
// Baglanti: SADECE Type-C (LiPo YOK)
//   VCC  -> 3V3   (modul 3.3-5V; 3V3 kullan, cikis 3.3 V mantik olsun)
//   GND  -> GND
//   SCK  -> PB12  (STM32 cikis)
//   OUT/DOUT -> PB13 (STM32 giris)
// Calisma: DOUT LOW olunca veri hazir; 24 bit MSB-first okunur.
//          Sonda 1 ekstra clock = 10 Hz differential mod.
// KALIBRASYON: acik havada 30 sn bekle, "zero" degerini not al, ZERO'ya yaz.
// Basari: parmakla hortuma hafif ufledigin an deger artar, birakinca doner.
//         cm_h2o ~ 0 civari duruyorsa ve uflemede yukseliyorsa sensor saglam.
// NOT: 40 kPa ~ 4 m su derinligi. Tezgahta 1 m'lik su dolu hortumla
//      dogrulama yapabilirsin (10 cm su = ~1 kPa).

// Serial = USART1 (PA9 TX / PA10 RX)
const int SCK_PIN = PB12;
const int DT_PIN  = PB13;

long ZERO = 0;          // kalibrasyon sonrasi buraya yaz
const float LSB_PER_KPA = 4200.0;  // kaba baslangic; su testiyle duzelt

bool hx_ready(uint32_t timeout_ms) {
  uint32_t t0 = millis();
  while (digitalRead(DT_PIN) == HIGH) {
    if (millis() - t0 > timeout_ms) return false;
  }
  return true;
}

long hx_read() {
  if (!hx_ready(200)) return 0x7FFFFFFF;  // hata isareti
  long v = 0;
  for (int i = 0; i < 24; i++) {
    digitalWrite(SCK_PIN, HIGH);
    delayMicroseconds(2);
    v = (v << 1) | (digitalRead(DT_PIN) ? 1 : 0);
    digitalWrite(SCK_PIN, LOW);
    delayMicroseconds(2);
  }
  digitalWrite(SCK_PIN, HIGH);  // 25. clock -> 10 Hz mod
  delayMicroseconds(2);
  digitalWrite(SCK_PIN, LOW);
  delayMicroseconds(2);
  if (v & 0x800000L) v |= ~0xFFFFFFL;  // 24-bit isaret genisletme
  return v;
}

void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(SCK_PIN, OUTPUT);
  digitalWrite(SCK_PIN, LOW);
  pinMode(DT_PIN, INPUT);
  Serial.println();
  Serial.println("AUV bench 07: HX710B");

  if (ZERO == 0) {   // ilk acilista otomatik sifirla (acik havada tut!)
    long acc = 0; int ok = 0;
    for (int i = 0; i < 20; i++) {
      long r = hx_read();
      if (r != 0x7FFFFFFF) { acc += r; ok++; }
      delay(120);
    }
    if (ok > 10) { ZERO = acc / ok; Serial.print("otomatik ZERO="); Serial.println(ZERO); }
    else Serial.println("HATA: sensorden veri yok - SCK/DOUT kablosu kontrol");
  }
  Serial.println("raw,delta,kPa,cm_h2o");
}

void loop() {
  long r = hx_read();
  if (r == 0x7FFFFFFF) { Serial.println("timeout - veri yok"); delay(500); return; }
  long d = r - ZERO;
  float kpa = d / LSB_PER_KPA;
  Serial.print(r);          Serial.print(",");
  Serial.print(d);          Serial.print(",");
  Serial.print(kpa, 3);     Serial.print(",");
  Serial.println(kpa * 10.1972, 1);  // 1 kPa = 10.2 cm su
  delay(150);
}
