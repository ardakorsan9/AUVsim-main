// AUV 16 - cift servo testi (MPS20 takili kalsin)
// Amac: Diger servo MPS20 yuzunden mi olmuyor?
//   Basinc B12/B13'te; servolar B4/B5 - pin catismasi YOK.
//   Bu kod SADECE B4 ve B5 surer. ESC 1500'de kilitli.
//
// Beklenti (MPS20 takili):
//   - "B4" yazinca bir servo hareket
//   - "B5" yazinca DIGER servo hareket
//   - Ikisi de hareket ediyorsa MPS20 suçlu DEGIL
//   - B5 hic kimildamiyorsa kablo/330R/servo (MPS20 degil)
//
// LiPo+UBEC sart. PERVANE umrunda degil (motor surulmez).
// Komut: a=otomatik tur | 4=sadece B4 | 5=sadece B5 | b=ikisi | s=1500

#include <Servo.h>

Servo s4;  // PB4
Servo s5;  // PB5
Servo esc; // PB0 - sadece notur

bool auto_run = false;
uint32_t t0 = 0;
uint8_t phase = 0;

void neut() {
  s4.writeMicroseconds(1500);
  s5.writeMicroseconds(1500);
  esc.writeMicroseconds(1500);
}

void setup() {
  Serial.begin(115200);
  delay(400);
  s4.attach(PB4, 1000, 2000);
  s5.attach(PB5, 1000, 2000);
  esc.attach(PB0, 1000, 2000);
  neut();

  Serial.println();
  Serial.println("AUV 16 DUAL SERVO (MPS20 takili test)");
  Serial.println("B4=PB4  B5=PB5  | basinc B12/B13 dokunulmaz");
  Serial.println("a=otomatik  4=B4  5=B5  b=ikisi  s=stop");
}

void sweep_one(Servo &sv, const char *name) {
  Serial.print(">>> SIMDI SADECE ");
  Serial.println(name);
  for (int u = 1300; u <= 1700; u += 20) {
    sv.writeMicroseconds(u);
    delay(25);
  }
  for (int u = 1700; u >= 1300; u -= 20) {
    sv.writeMicroseconds(u);
    delay(25);
  }
  sv.writeMicroseconds(1500);
  Serial.print("<<< ");
  Serial.print(name);
  Serial.println(" bitti -> 1500");
  delay(400);
}

void loop() {
  if (Serial.available()) {
    char k = Serial.read();
    if (k == 's') {
      auto_run = false;
      neut();
      Serial.println("STOP 1500");
    } else if (k == '4') {
      auto_run = false;
      s5.writeMicroseconds(1500);
      sweep_one(s4, "B4");
    } else if (k == '5') {
      auto_run = false;
      s4.writeMicroseconds(1500);
      sweep_one(s5, "B5");
    } else if (k == 'b') {
      auto_run = false;
      Serial.println(">>> IKISI BIRDEN");
      for (int u = 1300; u <= 1700; u += 20) {
        s4.writeMicroseconds(u);
        s5.writeMicroseconds(u);
        delay(25);
      }
      for (int u = 1700; u >= 1300; u -= 20) {
        s4.writeMicroseconds(u);
        s5.writeMicroseconds(u);
        delay(25);
      }
      neut();
      Serial.println("<<< ikisi bitti");
    } else if (k == 'a') {
      auto_run = true;
      t0 = millis();
      phase = 0;
      Serial.println("OTOMATIK: B4 -> B5 -> ikisi -> stop");
    }
  }

  if (!auto_run) {
    static uint32_t t_idle = 0;
    if (millis() - t_idle > 1500) {
      t_idle = millis();
      Serial.println("hazir: a / 4 / 5 / b / s | MPS20 takili kalabilir");
    }
    return;
  }

  // otomatik sira
  uint32_t ms = millis() - t0;
  if (phase == 0) {
    sweep_one(s4, "B4");
    s5.writeMicroseconds(1500);
    phase = 1;
    t0 = millis();
  } else if (phase == 1 && ms > 300) {
    sweep_one(s5, "B5");
    s4.writeMicroseconds(1500);
    phase = 2;
    t0 = millis();
  } else if (phase == 2 && ms > 300) {
    Serial.println(">>> IKISI BIRDEN");
    for (int u = 1300; u <= 1700; u += 20) {
      s4.writeMicroseconds(u);
      s5.writeMicroseconds(u);
      delay(25);
    }
    for (int u = 1700; u >= 1300; u -= 20) {
      s4.writeMicroseconds(u);
      s5.writeMicroseconds(u);
      delay(25);
    }
    neut();
    Serial.println("SONUC: B4 ve B5 hareket ettiyse MPS20 suçlu degil.");
    Serial.println("Biri hic kimildamadiysa o pin/kablo/servo bak.");
    auto_run = false;
  }
}
