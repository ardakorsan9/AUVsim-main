// AUV 17 - OTONOM: (0,0,0) -> (2,2,2) duz hat (MATLAB tarzi guidance + PID)
// ============================================================================
// YAZILDI ve HAZIR. Ama sunu bil:
//
// GERCEK SINIR (neden "tam MATLAB gibi metre metre" su an garanti degil):
//   - MATLAB sim: x,y,z tam biliniyor (dinamik model).
//   - Senin donanim: MPS20 -> yaklasik z (derinlik). MPU -> tutum + kaba yaw.
//   - Su altinda GPS yok. x,y DOGRUDAN OLCULEMEZ.
//   - Bu kod: z'yi basincla PID ile tutar; yatayda hedef yonu atan2(2,2)=45 deg
//     heading PID + ileri itki; x,y'yi hiz varsayimiyla OLEU RECKONING tahmin eder.
//   - Maket KB/KM farkli olunca kazanc (Kp..) ve hiz sabiti kalibre edilecek.
//   - Basinc/MPU yokken ARMED olsa bile fail-closed 1500 (otonom iddia etmez).
//
// Omurga (MATLAB ile ayni sira):
//   sensor -> nav/estimate -> guidance (duz hat) -> PID control -> PWM
//
// Hedef: NED [2, 2, 2] m  (z pozitif asagi / derinlik)
// Baslangic: suya giriste sifirla (b=zero) -> (0,0,0)
//
// Pinler: MPU B6/B7 | basinc B12/B13 | leak PA5 | servo B4/B5 | ESC PB0
// Komut: b=sifirla(baslangic)  a=arm otonom  s=disarm  z=sadece derinlik PID test
// PERVANE YOK tezgahta. LiPo+UBEC. USB varken UBEC->STM5V YOK.

#include <Wire.h>
#include <Servo.h>
#include <math.h>

const uint8_t MPU_ADDR = 0x68;
const int LEAK_PIN = PA5;
const int SCK_PIN = PB12;
const int DT_PIN = PB13;

Servo rudder, elevator, esc;

// ---- hedef / fizik sabitleri (makete gore degistir) ----
const float TARGET_X = 2.0f;
const float TARGET_Y = 2.0f;
const float TARGET_Z = 2.0f;       // m derinlik
const float SPEED_ASSUME = 0.4f;   // m/s ileri (bilinmiyor - kalibre et)
const float LSB_PER_KPA = 4200.0f;
const float KPA_PER_M = 9.81f;     // ~1 m su ~9.81 kPa
long PRESS_ZERO = 0;               // 'b' ile guncellenir

// PID kazançlari (muhafazakar tezgah; simulasyon kazancina cekilir)
float Kp_depth = 0.40f, Ki_depth = 0.05f, Kd_depth = 0.10f;
float Kp_yaw = 0.50f, Ki_yaw = 0.02f, Kd_yaw = 0.05f;
float Kp_pitch = 0.35f, Kd_pitch = 0.08f;

struct Nav {
  float ax, ay, az;
  float pitch_deg, roll_deg;
  float yaw_deg;          // gyro entegrasyon (suruklenir)
  float depth_m;
  float x_m, y_m;         // oleu reckoning
  bool imu_ok, press_ok;
  int leak;
};

struct Pid {
  float i, prev_e;
  float out;
};

bool armed = false;
bool depth_only = false;
uint32_t t_last = 0;
uint32_t t_arm = 0;
Nav nav;
Pid pid_z, pid_yaw, pid_pitch;
float gyro_z_bias = 0;
float yaw_rad = 0;

void reg_write(uint8_t r, uint8_t v) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(r); Wire.write(v); Wire.endTransmission();
}

bool hx_ready(uint32_t timeout_ms) {
  uint32_t t0 = millis();
  while (digitalRead(DT_PIN) == HIGH) {
    if (millis() - t0 > timeout_ms) return false;
  }
  return true;
}

long hx_read() {
  if (!hx_ready(80)) return 0x7FFFFFFF;
  long v = 0;
  for (int i = 0; i < 24; i++) {
    digitalWrite(SCK_PIN, HIGH); delayMicroseconds(2);
    v = (v << 1) | (digitalRead(DT_PIN) ? 1 : 0);
    digitalWrite(SCK_PIN, LOW); delayMicroseconds(2);
  }
  digitalWrite(SCK_PIN, HIGH); delayMicroseconds(2);
  digitalWrite(SCK_PIN, LOW); delayMicroseconds(2);
  if (v & 0x800000L) v |= ~0xFFFFFFL;
  return v;
}

bool read_imu(float dt) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU_ADDR, (uint8_t)14) != 14) return false;
  int16_t ax = (Wire.read() << 8) | Wire.read();
  int16_t ay = (Wire.read() << 8) | Wire.read();
  int16_t az = (Wire.read() << 8) | Wire.read();
  Wire.read(); Wire.read(); // temp
  int16_t gx = (Wire.read() << 8) | Wire.read();
  int16_t gy = (Wire.read() << 8) | Wire.read();
  int16_t gz = (Wire.read() << 8) | Wire.read();
  (void)gx; (void)gy;
  nav.ax = ax / 16384.0f;
  nav.ay = ay / 16384.0f;
  nav.az = az / 16384.0f;
  nav.pitch_deg = atan2f(-nav.ax, nav.az) * 57.2958f;
  nav.roll_deg = atan2f(nav.ay, nav.az) * 57.2958f;
  float gz_dps = gz / 131.0f - gyro_z_bias;
  yaw_rad += (gz_dps * 0.0174533f) * dt;
  // wrap
  while (yaw_rad > 3.14159f) yaw_rad -= 6.28318f;
  while (yaw_rad < -3.14159f) yaw_rad += 6.28318f;
  nav.yaw_deg = yaw_rad * 57.2958f;
  return true;
}

bool read_depth() {
  long raw = hx_read();
  if (raw == 0x7FFFFFFF) return false;
  float kpa = (float)(raw - PRESS_ZERO) / LSB_PER_KPA;
  float d = kpa / KPA_PER_M;
  if (d < 0) d = 0;
  nav.depth_m = d;
  return true;
}

float pid_step(Pid &p, float err, float dt, float kp, float ki, float kd, float ilim) {
  p.i += err * dt;
  if (p.i > ilim) p.i = ilim;
  if (p.i < -ilim) p.i = -ilim;
  float de = (dt > 1e-4f) ? (err - p.prev_e) / dt : 0;
  p.prev_e = err;
  p.out = kp * err + ki * p.i + kd * de;
  return p.out;
}

uint16_t sat_us(float cmd, float neu, float span, uint16_t lo, uint16_t hi) {
  if (cmd > 1) cmd = 1;
  if (cmd < -1) cmd = -1;
  uint16_t u = (uint16_t)(neu + cmd * span + 0.5f);
  if (u < lo) u = lo;
  if (u > hi) u = hi;
  return u;
}

void apply_pwm(float dr, float de, float thr, bool valid) {
  if (!valid) {
    rudder.writeMicroseconds(1500);
    elevator.writeMicroseconds(1500);
    esc.writeMicroseconds(1500);
    return;
  }
  rudder.writeMicroseconds(sat_us(dr, 1500, 300, 1200, 1800));
  elevator.writeMicroseconds(sat_us(de, 1500, 300, 1200, 1800));
  // tezgah itki limiti dar
  esc.writeMicroseconds(sat_us(thr, 1500, 350, 1420, 1580));
}

void disarm(const char *why) {
  armed = false;
  depth_only = false;
  apply_pwm(0, 0, 0, false);
  Serial.print("DISARM: ");
  Serial.println(why);
}

void zero_origin() {
  // baslangic (0,0,0): basinc sifir + yaw sifir + konum sifir
  long acc = 0;
  int n = 0;
  for (int i = 0; i < 16; i++) {
    long r = hx_read();
    if (r != 0x7FFFFFFF) { acc += r; n++; }
    delay(20);
  }
  if (n > 0) PRESS_ZERO = acc / n;
  nav.x_m = nav.y_m = 0;
  yaw_rad = 0;
  nav.yaw_deg = 0;
  pid_z = Pid{0, 0, 0};
  pid_yaw = Pid{0, 0, 0};
  pid_pitch = Pid{0, 0, 0};
  Serial.print("ZERO origin PRESS_ZERO=");
  Serial.println(PRESS_ZERO);
}

// Guidance: (0,0,0)->(2,2,2) duz hat - kalan vektore bak
void guidance(float &yaw_ref_deg, float &depth_ref, float &pitch_ref, float &u_cmd, bool &arrived) {
  float dx = TARGET_X - nav.x_m;
  float dy = TARGET_Y - nav.y_m;
  float dz = TARGET_Z - nav.depth_m;
  float horiz = sqrtf(dx * dx + dy * dy);
  float dist = sqrtf(horiz * horiz + dz * dz);
  arrived = (dist < 0.25f);

  depth_ref = TARGET_Z;
  yaw_ref_deg = atan2f(dy, dx) * 57.2958f; // hedefe yatay yon
  // derinlige inerken burnu hafif asagi
  if (dz > 0.15f) pitch_ref = -12.0f;
  else if (dz < -0.15f) pitch_ref = 8.0f;
  else pitch_ref = 0.0f;

  if (arrived) u_cmd = 0;
  else if (horiz > 0.3f || fabsf(dz) > 0.2f) u_cmd = 0.35f;
  else u_cmd = 0.15f;
}

void setup() {
  Serial.begin(115200);
  delay(400);
  pinMode(LEAK_PIN, INPUT_ANALOG);
  analogReadResolution(12);
  pinMode(SCK_PIN, OUTPUT);
  pinMode(DT_PIN, INPUT);
  digitalWrite(SCK_PIN, LOW);

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
  t_last = millis();

  Serial.println();
  Serial.println("AUV 17 GOTO (0,0,0)->(2,2,2) duz hat PID");
  Serial.println("b=sifirla  a=arm  z=depthPID  s=disarm");
  Serial.println("x,y oleu-reckoning; z basinc. Model kalibrasyonu sonra.");
}

void loop() {
  uint32_t now = millis();
  float dt = (now - t_last) / 1000.0f;
  if (dt < 0.001f) dt = 0.001f;
  if (dt > 0.1f) dt = 0.1f;
  t_last = now;

  if (Serial.available()) {
    char k = Serial.read();
    if (k == 's') disarm("operator");
    if (k == 'b') zero_origin();
    if (k == 'a') {
      armed = true; depth_only = false; t_arm = now;
      Serial.println("ARMED goto 2,2,2");
    }
    if (k == 'z') {
      armed = true; depth_only = true; t_arm = now;
      Serial.println("ARMED depth-only PID");
    }
  }

  nav.imu_ok = read_imu(dt);
  nav.press_ok = read_depth();
  nav.leak = analogRead(LEAK_PIN);

  // oleu reckoning: varsayilan hiz * cos/sin(yaw)  (kabaca)
  if (armed && nav.imu_ok) {
    float u = SPEED_ASSUME * 0.35f; // arm iken komutla oranlanacak asagida
    // gecici: onceki thrusta baglamadan sabit; kontrol sonrasi guncelle
  }

  if (armed && nav.leak < 2500) disarm("leak");

  float dr = 0, de = 0, thr = 0;
  bool valid = false;
  bool arrived = false;

  if (armed) {
    if (!nav.imu_ok || !nav.press_ok) {
      valid = false; // fail-closed
    } else if (depth_only) {
      float ez = TARGET_Z - nav.depth_m;
      float uz = pid_step(pid_z, ez, dt, Kp_depth, Ki_depth, Kd_depth, 2.0f);
      float ep = (0.0f - nav.pitch_deg);
      float up = pid_step(pid_pitch, ep, dt, Kp_pitch, 0, Kd_pitch, 1.0f);
      de = constrain(uz * 0.15f + up * 0.02f, -1.0f, 1.0f);
      dr = 0;
      thr = 0.2f;
      valid = true;
    } else {
      float yaw_ref, z_ref, pitch_ref, u_cmd;
      guidance(yaw_ref, z_ref, pitch_ref, u_cmd, arrived);

      float eyaw = yaw_ref - nav.yaw_deg;
      while (eyaw > 180) eyaw -= 360;
      while (eyaw < -180) eyaw += 360;
      float uyaw = pid_step(pid_yaw, eyaw, dt, Kp_yaw, Ki_yaw, Kd_yaw, 30.0f);

      float ez = z_ref - nav.depth_m;
      float uz = pid_step(pid_z, ez, dt, Kp_depth, Ki_depth, Kd_depth, 2.0f);

      float ep = pitch_ref - nav.pitch_deg;
      float up = pid_step(pid_pitch, ep, dt, Kp_pitch, 0, Kd_pitch, 1.0f);

      dr = constrain(uyaw / 45.0f, -1.0f, 1.0f);
      de = constrain(uz * 0.2f + up * 0.03f, -1.0f, 1.0f);
      thr = arrived ? 0.0f : u_cmd;
      valid = true;

      // konum entegrasyonu (x,y) - hiz varsayimi * thrust
      float u_ms = SPEED_ASSUME * fabsf(thr);
      nav.x_m += u_ms * cosf(yaw_rad) * dt;
      nav.y_m += u_ms * sinf(yaw_rad) * dt;

      if (arrived) {
        Serial.println("ARRIVED ~ (2,2,2) tahmin");
        disarm("arrived");
      }
    }
  }

  apply_pwm(dr, de, thr, valid && armed);

  static uint32_t t_log = 0;
  if (now - t_log > 200) {
    t_log = now;
    Serial.print("arm="); Serial.print(armed);
    Serial.print(" imu="); Serial.print(nav.imu_ok);
    Serial.print(" p="); Serial.print(nav.press_ok);
    Serial.print(" x="); Serial.print(nav.x_m, 2);
    Serial.print(" y="); Serial.print(nav.y_m, 2);
    Serial.print(" z="); Serial.print(nav.depth_m, 2);
    Serial.print(" yaw="); Serial.print(nav.yaw_deg, 1);
    Serial.print(" pit="); Serial.print(nav.pitch_deg, 1);
    Serial.print(" dr="); Serial.print(dr, 2);
    Serial.print(" de="); Serial.print(de, 2);
    Serial.print(" thr="); Serial.println(thr, 2);
  }
}
