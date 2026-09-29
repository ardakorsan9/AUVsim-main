// AUV 13 - acik cevrim (open-loop) dogrulama
// Amac: Otonom ONCESI - "komut gelseydi donanim cevap verir miydi?"
//   Sensörleri oku + zaman bazli (acik cevrim) servo/ESC komutu uygula.
//   Tam navigasyon/MATLAB runtime DEGIL; donanim+komut zinciri testi.
//
// Bagli: MPU B6/B7, leak PA5, servo PB4/PB5, ESC PB0, UART CP2102
// GUC: LiPo + UBEC (servo). PERVANE YOK. USB-C OK; UBEC->STM5V YOK.
//
// Komutlar:
//   a = arm (acik cevrim senaryo baslar)
//   s = stop / disarm (hepsi 1500)
//   p = pause (komutlar 1500, sensor akmaya devam)
//   r = senaryoyu basta
//
// Senaryo (arm sonrasi, ~20 sn, sonra otomatik disarm):
//   0-3s   notur 1500
//   3-6s   dümen/elevator +100us
//   6-9s   dümen/elevator -100us
//   9-12s  notur
//   12-15s ESC 1520 (cok hafif) - pervanesiz
//   15-18s ESC 1500, notur
//   sonra disarm
//
// Basari: UART'ta sensor + cmd satirlari akar; servo senaryoya uyar;
//         's' ile aninda 1500; leak islaksa otomatik disarm.

#include <Wire.h>
#include <Servo.h>

const uint8_t MPU_ADDR = 0x68;
const int LEAK_PIN = PA5;
const int LED = PC13;

Servo rudder;
Servo elevator;
Servo esc;

bool armed = false;
bool paused = false;
uint32_t t0 = 0;
float ax, ay, az;
uint16_t cmd_r = 1500, cmd_e = 1500, cmd_t = 1500;

void reg_write(uint8_t r, uint8_t v) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(r); Wire.write(v); Wire.endTransmission();
}

bool mpu_ok() {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU_ADDR, (uint8_t)6) != 6) return false;
  int16_t x = (Wire.read() << 8) | Wire.read();
  int16_t y = (Wire.read() << 8) | Wire.read();
  int16_t z = (Wire.read() << 8) | Wire.read();
  ax = x / 16384.0f; ay = y / 16384.0f; az = z / 16384.0f;
  return true;
}

void apply() {
  rudder.writeMicroseconds(cmd_r);
  elevator.writeMicroseconds(cmd_e);
  esc.writeMicroseconds(cmd_t);
}

void disarm(const char *why) {
  armed = false;
  paused = false;
  cmd_r = cmd_e = cmd_t = 1500;
  apply();
  Serial.print("DISARM: ");
  Serial.println(why);
}

void open_loop_schedule(uint32_t ms) {
  // acik cevrim: zamana gore komut - sensor karara GIRMEZ (sadece log)
  if (ms < 3000) {
    cmd_r = 1500; cmd_e = 1500; cmd_t = 1500;
  } else if (ms < 6000) {
    cmd_r = 1600; cmd_e = 1600; cmd_t = 1500;
  } else if (ms < 9000) {
    cmd_r = 1400; cmd_e = 1400; cmd_t = 1500;
  } else if (ms < 12000) {
    cmd_r = 1500; cmd_e = 1500; cmd_t = 1500;
  } else if (ms < 15000) {
    cmd_r = 1500; cmd_e = 1500; cmd_t = 1520;  // cok hafif itki
  } else if (ms < 18000) {
    cmd_r = 1500; cmd_e = 1500; cmd_t = 1500;
  } else {
    disarm("senaryo bitti");
  }
}

void setup() {
  pinMode(LED, OUTPUT);
  pinMode(LEAK_PIN, INPUT_ANALOG);
  analogReadResolution(12);

  Serial.begin(115200);
  delay(400);

  Wire.setSCL(PB6);
  Wire.setSDA(PB7);
  Wire.begin();
  Wire.setClock(100000);
  reg_write(0x6B, 0x00);
  delay(50);

  rudder.attach(PB4, 1000, 2000);
  elevator.attach(PB5, 1000, 2000);
  esc.attach(PB0, 1000, 2000);
  disarm("boot");

  Serial.println();
  Serial.println("AUV 13 OPEN-LOOP dogrulama");
  Serial.println("Sensor okunur; komut ZAMANA gore (acik cevrim).");
  Serial.println("a=arm  s=stop  p=pause  r=senaryo basa");
  Serial.println("PERVANE YOK. Leak islaksa otomatik disarm.");
}

void loop() {
  static uint32_t t_led = 0, t_log = 0;
  if (millis() - t_led > 200) {
    t_led = millis();
    digitalWrite(LED, !digitalRead(LED));
  }

  if (Serial.available()) {
    char k = Serial.read();
    if (k == 's') disarm("operator s");
    else if (k == 'p') {
      paused = true;
      cmd_r = cmd_e = cmd_t = 1500;
      apply();
      Serial.println("PAUSE 1500");
    } else if (k == 'r') {
      t0 = millis();
      paused = false;
      Serial.println("senaryo t=0");
    } else if (k == 'a') {
      armed = true;
      paused = false;
      t0 = millis();
      Serial.println("ARMED open-loop senaryo");
    }
  }

  int leak = analogRead(LEAK_PIN);
  // tipik kuru ~4000+; belirgin dusus = islak (esik muhafazakar)
  if (armed && leak < 2500) {
    disarm("leak");
  }

  bool imu = mpu_ok();

  if (armed && !paused) {
    open_loop_schedule(millis() - t0);
    apply();
  }

  if (millis() - t_log > 200) {
    t_log = millis();
    Serial.print("arm=");
    Serial.print(armed ? 1 : 0);
    Serial.print(" t_ms=");
    Serial.print(armed ? (millis() - t0) : 0);
    Serial.print(" leak=");
    Serial.print(leak);
    Serial.print(" ax=");
    Serial.print(imu ? ax : 0, 2);
    Serial.print(" ay=");
    Serial.print(imu ? ay : 0, 2);
    Serial.print(" az=");
    Serial.print(imu ? az : 0, 2);
    Serial.print(" cmd_r=");
    Serial.print(cmd_r);
    Serial.print(" cmd_e=");
    Serial.print(cmd_e);
    Serial.print(" cmd_t=");
    Serial.println(cmd_t);
  }
}
