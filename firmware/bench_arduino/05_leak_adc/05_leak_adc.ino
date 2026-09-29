// AUV tezgah testi 05 - sizinti (yagmur) sensorleri, ANALOG okuma
// Baglanti: SADECE Type-C (LiPo YOK)
//   Yagmur modulu VCC -> 3V3  (5V DEGIL! AO cikisi 3.3 V'u gecmemeli)
//   GND -> GND
//   AO  -> PA5 / PA6 / PA7   (DO pinini KULLANMA)
// Basari: kuru levha ~4095'e yakin (ya da modulunuzde tersi), nemli bez ile
//         belirgin dusus. Kuru/islak arasi en az ~800 LSB fark olmali;
//         yoksa esik guvenli degil.
// NOT: Suyu kartin uzerine damlatma. Sadece sensor levhasini nemlendir.

// Serial = USART1 (PA9 TX / PA10 RX)
const int LEAK[3] = { PA5, PA6, PA7 };

void setup() {
  Serial.begin(115200);
  delay(300);
  analogReadResolution(12);
  for (int i = 0; i < 3; i++) pinMode(LEAK[i], INPUT_ANALOG);
  Serial.println();
  Serial.println("AUV bench 05: leak1,leak2,leak3 (0..4095) + volt");
}

void loop() {
  for (int i = 0; i < 3; i++) {
    int raw = 0;
    for (int s = 0; s < 8; s++) raw += analogRead(LEAK[i]);  // 8 ornek ortalama
    raw /= 8;
    Serial.print(raw);
    Serial.print("(");
    Serial.print(raw * 3.3 / 4095.0, 2);
    Serial.print("V)");
    Serial.print(i < 2 ? "," : "\n");
  }
  delay(200);
}
