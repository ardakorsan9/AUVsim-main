// AUV 15 - OTONOM ISKELET (MATLAB tarzi) - HAZIR / SONRA KULLAN
// Omurga: sensor -> guidance -> control -> logical cmd -> PWM us
// Simulasyondaki mantik: delta_r, delta_e, thrust [-1..1] -> 1000..2000 us
//
// SU AN: MPU/basinc guvenilmez olabilir. Kod:
//   - sensor OK ise basit P kontrol (pitch~az, "yaw" kaba)
//   - sensor KOTU ise ARMED olsa bile fail-closed 1500 (otonom iddia etmez)
//   - leak dusukse disarm
//
// Bu, tam MATLAB codegen / kutle-merkez modeli DEGIL.
// Model (KB/KM) netlesince kazanc ve depth ref buraya / auv_f411'e tasinir.
//
// Komut: a=arm  s=disarm  d=demo_ref (sabit referansla deneme)
// PERVANE YOK. LiPo+UBEC. USB varken UBEC->STM5V YOK.

#include <Wire.h>
#include <Servo.h>

const uint8_t MPU_ADDR = 0x68;
const int LEAK_PIN = PA5;

Servo rudder, elevator, esc;

// --- MATLAB benzeri mantiksal komut ---
struct LogicalCmd {
  float delta_r;  // -1..1 dümen
  float delta_e;  // -1..1 elevator (pozitif = burnu asagi varsayimi - kalibre et)
  float thrust;   // -1..1 (bidirectional ESC: 0=1500)
  bool valid;
};

struct NavState {
  float ax, ay, az;
  float pitch_approx;  // kaba: atan2(-ax, az) rad -> deg
  int leak_raw;
  bool imu_ok;
  bool pressure_ok;    // su an yok / false
  float depth_m;       // stub
};

bool armed = false;
bool demo_ref = false;
uint32_t t_arm = 0;

// Kazançlar - tezgah icin muhafazakar (model netlesince degistir)
const float KP_PITCH = 0.35f;
const float KP_YAW = 0.20f;
const float DEPTH_REF_M = 1.0f;     // ileride basinc ile
const float PITCH_REF_DEG = -8.0f;  // dalis burnu asagi (demo)
const float THRUST_CRUISE = 0.25f;  // |thrust| 0.25 -> ~1575 us civari

uint16_t map_signed(float x, float neutral, float span) {
  if (x > 1.f) x = 1.f;
  if (x < -1.f) x = -1.f;
  return (uint16_t)(neutral + x * span + 0.5f);
}

void pwm_apply(const LogicalCmd &c) {
  if (!c.valid) {
    rudder.writeMicroseconds(1500);
    elevator.writeMicroseconds(1500);
    esc.writeMicroseconds(1500);
    return;
  }
  // span 300us => +/-0.3 tam sapma guvenli tezgah
  uint16_t ru = map_signed(c.delta_r, 1500.f, 300.f);
  uint16_t eu = map_signed(c.delta_e, 1500.f, 300.f);
  uint16_t tu = map_signed(c.thrust, 1500.f, 400.f);
  if (ru < 1200) ru = 1200; if (ru > 1800) ru = 1800;
  if (eu < 1200) eu = 1200; if (eu > 1800) eu = 1800;
  if (tu < 1400) tu = 1400; if (tu > 1600) tu = 1600; // tezgah itki limiti
  rudder.writeMicroseconds(ru);
  elevator.writeMicroseconds(eu);
  esc.writeMicroseconds(tu);
}

void disarm(const char *why) {
  armed = false;
  demo_ref = false;
  LogicalCmd z = {0, 0, 0, false};
  pwm_apply(z);
  Serial.print("DISARM: ");
  Serial.println(why);
}

void reg_write(uint8_t r, uint8_t v) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(r); Wire.write(v); Wire.endTransmission();
}

bool read_imu(NavState &n) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU_ADDR, (uint8_t)6) != 6) return false;
  int16_t x = (Wire.read() << 8) | Wire.read();
  int16_t y = (Wire.read() << 8) | Wire.read();
  int16_t z = (Wire.read() << 8) | Wire.read();
  n.ax = x / 16384.0f;
  n.ay = y / 16384.0f;
  n.az = z / 16384.0f;
  n.pitch_approx = atan2f(-n.ax, n.az) * 57.2958f;
  return true;
}

// Guidance: referans uret (MATLAB guidance_law benzeri sade)
void guidance(float t_s, float &pitch_ref_deg, float &yaw_rate_cmd, float &thrust_cmd) {
  if (demo_ref) {
    // 0-5s dalis pitch, 5-12s duz seyir, sonra notur
    if (t_s < 5.f) {
      pitch_ref_deg = PITCH_REF_DEG;
      yaw_rate_cmd = 0.f;
      thrust_cmd = THRUST_CRUISE;
    } else if (t_s < 12.f) {
      pitch_ref_deg = 0.f;
      yaw_rate_cmd = 0.15f * sinf(t_s); // hafif salinim
      thrust_cmd = THRUST_CRUISE;
    } else {
      pitch_ref_deg = 0.f;
      yaw_rate_cmd = 0.f;
      thrust_cmd = 0.f;
    }
    return;
  }
  // Normal otonom hedef (basinc yokken depth yerine pitch tut)
  pitch_ref_deg = PITCH_REF_DEG;
  yaw_rate_cmd = 0.f;
  thrust_cmd = THRUST_CRUISE;
  (void)DEPTH_REF_M;
}

// Control: P (MATLAB controller_law sade)
LogicalCmd control(const NavState &n, float pitch_ref, float yaw_cmd, float thr_cmd) {
  LogicalCmd c;
  c.valid = false;
  c.delta_r = 0;
  c.delta_e = 0;
  c.thrust = 0;
  if (!n.imu_ok) return c;

  float pitch_err = pitch_ref - n.pitch_approx;
  c.delta_e = KP_PITCH * (pitch_err / 30.f); // 30 deg olcek
  c.delta_r = KP_YAW * yaw_cmd + 0.1f * n.ay; // kaba
  c.thrust = thr_cmd;
  c.valid = true;
  return c;
}

void setup() {
  Serial.begin(115200);
  delay(400);
  pinMode(LEAK_PIN, INPUT_ANALOG);
  analogReadResolution(12);

  Wire.setSCL(PB6);
  Wire.setSDA(PB7);
  Wire.begin();
  Wire.setClock(100000);
  reg_write(0x6B, 0x00);

  rudder.attach(PB4, 1000, 2000);
  elevator.attach(PB5, 1000, 2000);
  esc.attach(PB0, 1000, 2000);
  disarm("boot");

  Serial.println();
  Serial.println("AUV 15 AUTONOMY SKELETON (MATLAB-style)");
  Serial.println("a=arm  d=arm+demo_ref  s=disarm");
  Serial.println("IMU kotu => fail-closed 1500. Leak dusuk => disarm.");
  Serial.println("Basinc yok: depth stub. Model netlesince kazanc guncelle.");
}

void loop() {
  if (Serial.available()) {
    char k = Serial.read();
    if (k == 's') disarm("operator");
    if (k == 'a') {
      armed = true; demo_ref = false; t_arm = millis();
      Serial.println("ARMED (sensor gerekli)");
    }
    if (k == 'd') {
      armed = true; demo_ref = true; t_arm = millis();
      Serial.println("ARMED DEMO_REF 12s+");
    }
  }

  NavState n = {};
  n.imu_ok = read_imu(n);
  n.leak_raw = analogRead(LEAK_PIN);
  n.pressure_ok = false;
  n.depth_m = 0.f;

  if (armed && n.leak_raw < 2500) {
    disarm("leak");
  }

  LogicalCmd cmd = {0, 0, 0, false};
  if (armed) {
    float t_s = (millis() - t_arm) / 1000.f;
    float pref, ycmd, thr;
    guidance(t_s, pref, ycmd, thr);
    cmd = control(n, pref, ycmd, thr);
    if (!cmd.valid) {
      // fail-closed
      cmd.delta_r = cmd.delta_e = cmd.thrust = 0;
      cmd.valid = false;
    }
    if (demo_ref && t_s > 15.f) disarm("demo bitti");
  }
  pwm_apply(cmd);

  static uint32_t t_log = 0;
  if (millis() - t_log > 200) {
    t_log = millis();
    Serial.print("arm=");
    Serial.print(armed);
    Serial.print(" imu=");
    Serial.print(n.imu_ok);
    Serial.print(" pitch=");
    Serial.print(n.pitch_approx, 1);
    Serial.print(" leak=");
    Serial.print(n.leak_raw);
    Serial.print(" dr=");
    Serial.print(cmd.delta_r, 2);
    Serial.print(" de=");
    Serial.print(cmd.delta_e, 2);
    Serial.print(" thr=");
    Serial.println(cmd.thrust, 2);
  }
}
