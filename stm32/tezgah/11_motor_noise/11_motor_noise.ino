// AUV tezgah testi 11 - MOTOR + TUM SENSORLER BIRLIKTE (kuru, havada)
// Amac: motor donerken elektriksel gurultunun I2C/ADC'yi bozup bozmadigini olcmek.
// Bu, gercek govdede en sik gorulen arizadir ve kuru tezgahta yakalanabilir.
//
// !!! PERVANE YOK. MOTOR MASAYA SABITLENMIS. !!!
//
// Baglanti = test 09 (ESC) + test 10 (tum sensorler) ayni anda.
// Kablo uzunluklarini NIHAI tasarima yakin tut - gurultu davranisi
// kablo uzunluguna bagli, kisa jumperla test edip sonra uzatirsan
// olcum gecersiz olur.
//
// PROTOKOL:
//   Kod once 10 sn motor NOTR'de referans (baseline) toplar.
//   Sonra sen gazi actikca ayni metrikleri karsilastirir.
//   Her saniye: i2c hata orani, az_g gurultusu, vbat cokmesi, sicaklik.
//
// KOMUTLAR: f=+20us  b=-20us  x=stop  r=baseline'i yeniden al
//           digerleri = ACIL STOP
//
// OTOMATIK KESME (motoru notre alir):
//   - 1 saniyede 5'ten fazla I2C hatasi   -> gurultu sorunu
//   - sizinti sensorlerinden biri esigi gecerse
//   - vbat < 10.0 V
//   - bolme sicakligi > TEMP_LIMIT
//
// GECME KRITERI (60 sn, gaz 1600us'de):
//   i2c_err_rate motor donerken de 0 kalmali
//   az_g standart sapmasi notre gore 2 katindan fazla artmamali
//   vbat cokmesi 0.5 V'u gecmemeli (gecerse kondansator/kablo kesiti yetersiz)
//   sicaklik surekli tirmaniyorsa gorev dongusu sinirin var

#include <Wire.h>
#include <Servo.h>

// Serial = USART1 (PA9 TX / PA10 RX)
Servo esc;

const int   ESC_PIN  = PB0;
const int   NEUTRAL  = 1500;
const int   LIM_LO   = 1400;
const int   LIM_HI   = 1600;
const uint8_t MPU_ADDR = 0x68;  // 'MPU' adi CMSIS makrosuyla cakisir
const int   LEAK[3]  = { PA5, PA6, PA7 };
const int   VBAT_PIN = PA4;
const float DIV      = 13300.0 / 3300.0;

// --- esikler ---
const int   LEAK_THRESHOLD = 2000;   // test 05'te olctugun kuru/islak ortasi
const float VBAT_MIN       = 10.0;   // 3S icin mutlak alt sinir
const float TEMP_LIMIT     = 60.0;   // MPU die sicakligi ~ bolme ortami
const uint32_t I2C_ERR_MAX = 5;      // saniyede

int us = NEUTRAL;
uint32_t last_cmd = 0, t_next = 0, t_sec = 0;
uint32_t i2c_err = 0, i2c_err_prev = 0;

// saniyelik istatistik birikimi
float acc_sum = 0, acc_sq = 0;
float vbat_min_s = 99, vbat_max_s = 0;
uint16_t n_s = 0;

// baseline (motor notrde olculen referans)
float base_noise = -1;
bool  collecting_baseline = true;
uint32_t baseline_until = 0;

void reg_write(uint8_t r, uint8_t v) {
  Wire.beginTransmission(MPU_ADDR); Wire.write(r); Wire.write(v); Wire.endTransmission();
}

void send(int v) {
  us = constrain(v, LIM_LO, LIM_HI);
  esc.writeMicroseconds(us);
  last_cmd = millis();
}

void cutoff(const char* reason) {
  send(NEUTRAL);
  Serial.print("!!! OTOMATIK KESME: ");
  Serial.println(reason);
}

void setup() {
  Serial.begin(115200);
  delay(300);

  analogReadResolution(12);
  for (int i = 0; i < 3; i++) pinMode(LEAK[i], INPUT_ANALOG);
  pinMode(VBAT_PIN, INPUT_ANALOG);
  pinMode(PC13, OUTPUT);

  Wire.setSCL(PB6); Wire.setSDA(PB7); Wire.begin(); Wire.setClock(100000);
  reg_write(0x6B, 0x00); delay(100);
  reg_write(0x1B, 0x00); reg_write(0x1C, 0x00); reg_write(0x1A, 0x03);

  esc.attach(ESC_PIN, 1000, 2000);
  esc.writeMicroseconds(NEUTRAL);

  Serial.println();
  Serial.println("AUV bench 11: motor + sensor birlikte");
  Serial.println("PERVANE YOK, MOTOR SABIT MI? Degilse simdi LiPo'yu cek.");
  for (int i = 5; i > 0; i--) { Serial.println(i); delay(1000); }

  Serial.println("ARM tamam. 10 sn NOTR baseline toplaniyor - motora dokunma.");
  baseline_until = millis() + 10000;
  last_cmd = millis();
  t_sec = millis() + 1000;
  Serial.println("sec,us,i2c_err_rate,az_noise_mg,noise_x_base,vbat_min,vbat_drop,temp_C,leak_max");
}

void loop() {
  // ---- komut ----
  if (Serial.available()) {
    char k = Serial.read();
    if      (k == 'f') send(us + 20);
    else if (k == 'b') send(us - 20);
    else if (k == 'x') send(NEUTRAL);
    else if (k == 'r') {
      send(NEUTRAL); base_noise = -1; collecting_baseline = true;
      baseline_until = millis() + 10000;
      Serial.println("baseline yeniden toplaniyor (10 sn, notr)");
    }
    else if (k == '\r' || k == '\n') { }
    else { send(NEUTRAL); Serial.println("ACIL STOP"); }
  }

  // komut watchdog
  if (us != NEUTRAL && millis() - last_cmd > 3000) cutoff("watchdog (komut yok)");

  // ---- 100 Hz ornekleme degil, 10 Hz olcum ----
  if (millis() < t_next) return;
  t_next = millis() + 100;

  // IMU
  Wire.beginTransmission(MPU_ADDR); Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) i2c_err++;
  Wire.requestFrom(MPU_ADDR, (uint8_t)14);
  int16_t a[3] = {0,0,0}, tr = 0, g[3] = {0,0,0};
  bool imu_ok = false;
  if (Wire.available() >= 14) {
    for (int i = 0; i < 3; i++) a[i] = (Wire.read() << 8) | Wire.read();
    tr = (Wire.read() << 8) | Wire.read();
    for (int i = 0; i < 3; i++) g[i] = (Wire.read() << 8) | Wire.read();
    imu_ok = true;
  } else i2c_err++;

  float az = a[2] / 16384.0;
  float temp = tr / 340.0 + 36.53;

  // sizinti + batarya
  int leak_max = 0;
  for (int i = 0; i < 3; i++) {
    int v = analogRead(LEAK[i]);
    if (v > leak_max) leak_max = v;
  }
  uint32_t vacc = 0;
  for (int i = 0; i < 8; i++) vacc += analogRead(VBAT_PIN);
  float vbat = (vacc / 8.0) * 3.3 / 4095.0 * DIV;

  // istatistik biriktir
  if (imu_ok) { acc_sum += az; acc_sq += az * az; n_s++; }
  if (vbat < vbat_min_s) vbat_min_s = vbat;
  if (vbat > vbat_max_s) vbat_max_s = vbat;

  // ---- guvenlik kesmeleri ----
  if (leak_max > LEAK_THRESHOLD && us != NEUTRAL) cutoff("sizinti algilandi");
  if (vbat < VBAT_MIN && us != NEUTRAL)           cutoff("batarya dusuk");
  if (imu_ok && temp > TEMP_LIMIT && us != NEUTRAL) cutoff("bolme sicak");

  // ---- saniyelik rapor ----
  if (millis() >= t_sec) {
    t_sec += 1000;
    uint32_t err_rate = i2c_err - i2c_err_prev;
    i2c_err_prev = i2c_err;

    float noise_mg = 0;
    if (n_s > 1) {
      float mean = acc_sum / n_s;
      float var  = acc_sq / n_s - mean * mean;
      if (var > 0) noise_mg = sqrt(var) * 1000.0;   // mg (milli-g) RMS
    }

    if (collecting_baseline) {
      if (millis() >= baseline_until) {
        base_noise = (noise_mg > 0.5) ? noise_mg : 0.5;  // sifira bolme korumasi
        collecting_baseline = false;
        Serial.print("baseline gurultu = "); Serial.print(base_noise, 1);
        Serial.println(" mg. Simdi gaz verebilirsin: f");
      }
    }

    if (err_rate > I2C_ERR_MAX && us != NEUTRAL) cutoff("I2C gurultu");

    Serial.print(millis() / 1000);              Serial.print(",");
    Serial.print(us);                           Serial.print(",");
    Serial.print(err_rate);                     Serial.print(",");
    Serial.print(noise_mg, 1);                  Serial.print(",");
    if (base_noise > 0) Serial.print(noise_mg / base_noise, 2); else Serial.print("-");
    Serial.print(",");
    Serial.print(vbat_min_s, 2);                Serial.print(",");
    Serial.print(vbat_max_s - vbat_min_s, 2);   Serial.print(",");
    Serial.print(temp, 1);                      Serial.print(",");
    Serial.println(leak_max);

    acc_sum = acc_sq = 0; n_s = 0;
    vbat_min_s = 99; vbat_max_s = 0;
    digitalWrite(PC13, !digitalRead(PC13));
  }
}
