// AUV tezgah testi 01 - kart canli mi?
// Kart: WeAct BlackPill STM32F411CEU6
// Baglanti: SADECE Type-C (LiPo YOK) + ST-Link SWDIO=PA13 SWCLK=PA14 GND=GND
// ST-Link 3V3 kablosunu BAGLAMA (USB-C zaten besliyor).
// Basari: PC13 LED 1 Hz yanip soner, kart isinmaz.

const int LED = PC13;  // WeAct BlackPill: LED ters mantik (LOW = yanik)

void setup() {
  pinMode(LED, OUTPUT);
}

void loop() {
  digitalWrite(LED, LOW);
  delay(500);
  digitalWrite(LED, HIGH);
  delay(500);
}
