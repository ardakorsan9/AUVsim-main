// AUV tezgah testi 10 - birlesik telemetri (MOTOR YOK, sadece okuma)
// Tum sensorler ayni anda: IMU + 3 sizinti + Vbat + basinc, 10 Hz CSV.
// Amac: guc gurultusu ve I2C kararliligini birlikte gormek.
// Baglanti: test 04 + 05 + 06 + 07 baglantilarinin toplami.
//   ESC ve servo sinyalleri BAGLI DEGIL.
// Basari kriteri (60 sn kesintisiz):
//   - i2c_err sayaci artmiyor
//   - az_g degeri +/-0.05 g icinde sabit (gurultu yok)
//   - vbat 0.2 V'tan fazla dalgalanmiyor
//   - press_raw kaymiyor (drift < ~2 cm/dk)
// Kayit: terminalde log dosyasina yaz, sonra Python/MATLAB ile incele.

#include <Wire.h>

// Serial = USART1 (PA9 TX / PA10 RX)
// NOT: sabit adi MPU olamaz - CMSIS'te Memory Protection Unit makrosu
const uint8_t MPU_ADDR = 0x68;
const int LEAK[3] = { PA5, PA6, PA7 };
const int VBAT_PIN = PA4;
const int SCK_PIN = PB12, DT_PIN = PB13;
const float DIV = 13300.0 / 3300.0;
long ZERO = 0;
uint32_t i2c_err = 0, t_next = 0;

void reg_write(uint8_t r, uint8_t v) {
  Wire.beginTransmission(MPU_ADDR); Wire.write(r); Wire.write(v); Wire.endTransmission();
}

long hx_read() {
  uint32_t t0 = millis();
  while (digitalRead(DT_PIN) == HIGH) if (millis() - t0 > 30) return 0x7FFFFFFF;
  long v = 0;
  for (int i = 0; i < 24; i++) {
    digitalWrite(SCK_PIN, HIGH); delayMicroseconds(2);
    v = (v << 1) | (digitalRead(DT_PIN) ? 1 : 0);
    digitalWrite(SCK_PIN, LOW);  delayMicroseconds(2);
  }
  digitalWrite(SCK_PIN, HIGH); delayMicroseconds(2);
  digitalWrite(SCK_PIN, LOW);  delayMicroseconds(2);
  if (v & 0x800000L) v |= ~0xFFFFFFL;
  return v;
}

void setup() {
  Serial.begin(115200);
  delay(300);
  analogReadResolution(12);
  for (int i = 0; i < 3; i++) pinMode(LEAK[i], INPUT_ANALOG);
  pinMode(VBAT_PIN, INPUT_ANALOG);
  pinMode(SCK_PIN, OUTPUT); digitalWrite(SCK_PIN, LOW);
  pinMode(DT_PIN, INPUT);
  pinMode(PC13, OUTPUT);

  Wire.setSCL(PB6); Wire.setSDA(PB7); Wire.begin(); Wire.setClock(100000);
  reg_write(0x6B, 0x00); delay(100);
  reg_write(0x1B, 0x00); reg_write(0x1C, 0x00); reg_write(0x1A, 0x03);

  long acc = 0; int ok = 0;
  for (int i = 0; i < 10; i++) { long r = hx_read(); if (r != 0x7FFFFFFF) { acc += r; ok++; } delay(110); }
  if (ok > 5) ZERO = acc / ok;

  Serial.println();
  Serial.println("ms,ax_g,ay_g,az_g,gx,gy,gz,leak1,leak2,leak3,vbat_V,press_raw,cm_h2o,i2c_err");
}

void loop() {
  if (millis() < t_next) return;
  t_next = millis() + 100;

  Wire.beginTransmission(MPU_ADDR); Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) { i2c_err++; }
  Wire.requestFrom(MPU_ADDR, (uint8_t)14);
  int16_t a[3] = {0, 0, 0}, g[3] = {0, 0, 0};
  if (Wire.available() >= 14) {
    for (int i = 0; i < 3; i++) a[i] = (Wire.read() << 8) | Wire.read();
    Wire.read(); Wire.read();  // temp
    for (int i = 0; i < 3; i++) g[i] = (Wire.read() << 8) | Wire.read();
  } else i2c_err++;

  int lk[3];
  for (int i = 0; i < 3; i++) lk[i] = analogRead(LEAK[i]);
  uint32_t vacc = 0;
  for (int i = 0; i < 8; i++) vacc += analogRead(VBAT_PIN);
  float vbat = (vacc / 8.0) * 3.3 / 4095.0 * DIV;
  long pr = hx_read();
  float cm = (pr == 0x7FFFFFFF) ? -999.0 : (pr - ZERO) / 4200.0 * 10.1972;

  Serial.print(millis());        Serial.print(",");
  Serial.print(a[0] / 16384.0, 3); Serial.print(",");
  Serial.print(a[1] / 16384.0, 3); Serial.print(",");
  Serial.print(a[2] / 16384.0, 3); Serial.print(",");
  Serial.print(g[0] / 131.0, 1);   Serial.print(",");
  Serial.print(g[1] / 131.0, 1);   Serial.print(",");
  Serial.print(g[2] / 131.0, 1);   Serial.print(",");
  Serial.print(lk[0]); Serial.print(",");
  Serial.print(lk[1]); Serial.print(",");
  Serial.print(lk[2]); Serial.print(",");
  Serial.print(vbat, 2);  Serial.print(",");
  Serial.print(pr);       Serial.print(",");
  Serial.print(cm, 1);    Serial.print(",");
  Serial.println(i2c_err);

  digitalWrite(PC13, !digitalRead(PC13));
}
