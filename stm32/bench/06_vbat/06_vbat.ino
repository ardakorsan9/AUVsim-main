// AUV tezgah testi 06 - batarya gerilim bolucu
// DIKKAT: Bu test LiPo ile yapilir. Once SIGORTA takili olsun.
// Bolucu: Vbat --[10k]--+--[3.3k]-- GND ,  orta nokta -> PA4
//         PA4 - GND arasina 100 nF
// Olcek: 3S dolu 12.6 V -> 12.6 * 3.3/13.3 = 3.13 V  (3.3 V altinda, guvenli)
//        4S KULLANMA: 16.8 V -> 4.17 V, pini yakar.
// SIRA:
//   1) Bolucuyu kur, PA4'e HENUZ BAGLAMA.
//   2) LiPo'yu XT60 + sigortadan besle, orta noktayi multimetre ile olc.
//   3) Olculen deger 3.2 V'un altindaysa PA4'e bagla.
// Basari: seri porttaki volt, multimetre ile +/-0.1 V uyusur.
//         Uymuyorsa CAL_GAIN degerini duzelt.

// Serial = USART1 (PA9 TX / PA10 RX)
const int VBAT_PIN = PA4;
const float DIV = (10000.0 + 3300.0) / 3300.0;  // = 4.0303
float CAL_GAIN = 1.000;                         // multimetreye gore ince ayar

void setup() {
  Serial.begin(115200);
  delay(300);
  analogReadResolution(12);
  pinMode(VBAT_PIN, INPUT_ANALOG);
  Serial.println();
  Serial.println("AUV bench 06: raw,pin_V,vbat_V,hucre_V");
}

void loop() {
  uint32_t acc = 0;
  for (int i = 0; i < 16; i++) acc += analogRead(VBAT_PIN);
  float raw = acc / 16.0;
  float pinV = raw * 3.3 / 4095.0;
  float vbat = pinV * DIV * CAL_GAIN;

  Serial.print(raw, 0);      Serial.print(",");
  Serial.print(pinV, 3);     Serial.print(",");
  Serial.print(vbat, 2);     Serial.print(",");
  Serial.println(vbat / 3.0, 2);  // 3S: hucre basina

  if (vbat < 10.5) Serial.println("UYARI: 3S icin dusuk (3.5V/hucre). Testi bitir.");
  delay(500);
}
