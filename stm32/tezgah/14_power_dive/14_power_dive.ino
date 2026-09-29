// AUV 14 - 15 sn guc / dalis-ileri profili (ACIK CEVRIM)
// Sensorden BAGIMSIZ: servo+motor gercek akim ceker.
// Senaryo: dalis benzeri elevator + itki, sonra seviye + ileri, sonra notur.
// PERVANE YOK. LiPo+UBEC sart. 's' = aninda 1500.

#include <Servo.h>

Servo rudder;    // PB4
Servo elevator;  // PB5
Servo esc;       // PB0

bool running = false;
uint32_t t0 = 0;

const uint16_t US_N = 1500;
// Gercek guc icin sinirli ama hissedilir (pervanesiz)
const uint16_t US_E_DIVE = 1650;   // burnu asagi / derinlik komutu benzeri
const uint16_t US_E_LEVEL = 1500;
const uint16_t US_R_SWEEP = 1600;  // hafif yon
const uint16_t US_T_CRUISE = 1560; // ileri itki (hafif-orta)
const uint16_t US_T_DIVE = 1540;

void set_all(uint16_t r, uint16_t e, uint16_t t) {
  rudder.writeMicroseconds(r);
  elevator.writeMicroseconds(e);
  esc.writeMicroseconds(t);
}

void stop_now(const char *why) {
  running = false;
  set_all(US_N, US_N, US_N);
  Serial.print("STOP 1500: ");
  Serial.println(why);
}

void setup() {
  Serial.begin(115200);
  delay(400);
  rudder.attach(PB4, 1000, 2000);
  elevator.attach(PB5, 1000, 2000);
  esc.attach(PB0, 1000, 2000);
  stop_now("boot");
  Serial.println();
  Serial.println("AUV 14 POWER DIVE 15s (acik cevrim)");
  Serial.println("PERVANE YOK | a=baslat | s=stop");
  Serial.println("Profil: 0-4s dalis | 4-11s ileri | 11-15s toparlan | stop");
}

void loop() {
  if (Serial.available()) {
    char k = Serial.read();
    if (k == 's') stop_now("operator");
    if (k == 'a') {
      running = true;
      t0 = millis();
      Serial.println("RUN 15s power profile");
    }
  }

  // Idle iken bos ekran olmasin
  if (!running) {
    static uint32_t t_idle = 0;
    if (millis() - t_idle > 1000) {
      t_idle = millis();
      Serial.println("hazir: a=15s baslat | s=stop | PERVANE YOK");
    }
    return;
  }

  uint32_t ms = millis() - t0;
  uint16_t r = US_N, e = US_N, t = US_N;

  if (ms < 4000) {
    // dalis benzeri: elevator asagi + hafif itki
    e = US_E_DIVE;
    t = US_T_DIVE;
    r = US_N;
  } else if (ms < 11000) {
    // ileri / seyir: seviye + daha fazla itki + hafif dümen
    e = US_E_LEVEL;
    t = US_T_CRUISE;
    r = (ms / 500) % 2 == 0 ? US_R_SWEEP : (uint16_t)(1400);
  } else if (ms < 15000) {
    // toparlan
    e = US_N;
    t = US_N;
    r = US_N;
  } else {
    stop_now("15s bitti");
    return;
  }

  set_all(r, e, t);

  static uint32_t t_log = 0;
  if (millis() - t_log > 250) {
    t_log = millis();
    Serial.print("t_ms=");
    Serial.print(ms);
    Serial.print(" r=");
    Serial.print(r);
    Serial.print(" e=");
    Serial.print(e);
    Serial.print(" thr=");
    Serial.println(t);
  }
}
