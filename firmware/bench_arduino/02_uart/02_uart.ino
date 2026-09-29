// AUV tezgah testi 02 - UART telemetri hatti (CP2102)
// Baglanti: SADECE Type-C (LiPo YOK)
//   PA9  (STM32 TX) -> CP2102 RXD
//   PA10 (STM32 RX) <- CP2102 TXD
//   GND             -> CP2102 GND
//   CP2102 5V / 3V3 BAGLANMAZ (cift besleme olmasin)
// Terminal: 115200 8N1
// Basari: saniyede bir satir okunur, karakterler bozuk degil.
//         Bozuksa HSE 25 MHz kart ayari yanlis secilmis demektir.

// Serial = USART1 (PA9 TX / PA10 RX) - BlackPill F411CE varyant varsayilani
const int LED = PC13;
uint32_t n = 0;

void setup() {
  pinMode(LED, OUTPUT);
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("AUV bench 02: UART hatti acik. 115200 8N1.");
  Serial.println("Yaz -> geri yansitilir (echo).");
}

void loop() {
  Serial.print("tick=");
  Serial.print(n++);
  Serial.print(" ms=");
  Serial.println(millis());

  while (Serial.available()) {
    char c = Serial.read();
    Serial.print("echo:");
    Serial.println(c);
  }

  digitalWrite(LED, !digitalRead(LED));
  delay(1000);
}
