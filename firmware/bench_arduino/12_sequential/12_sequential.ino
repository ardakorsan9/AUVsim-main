// AUV tezgah 12 - sirali parca testi (senin mevcut baglanti)
// Bagli: UART, 1x MPU6050, 1x leak (PA5), 2x servo (PB4/PB5), ESC+motor (PB0)
// Basinc YOK (bu sketch'te atlanir)
//
// GUVENLIK:
//   - PERVANE TAKILI OLMASIN
//   - Servo kollari cikarilmis olsun (veya yuksuz)
//   - LiPo YOKKEN asama 1-3 (UART/MPU/leak) calisir
//   - Servo + motor icin LiPo + UBEC gerekir; kod beklemede kalir
//   - Motor ASLA kendiliginden donmez; sadece 'm' ile kisa +20us
//
// Komutlar (her an):
//   n = sonraki asama     r = basa don
//   c = servo/esc 1500    s = motor/servo stop (1500 + rapor)
//   m = motor kisa test   (sadece asama 6'da, pervanesiz)

#include <Wire.h>
#include <Servo.h>

const uint8_t MPU_ADDR = 0x68;
const int LEAK_PIN = PA5;
const int LED = PC13;

Servo rudder;    // PB4
Servo elevator;  // PB5
Servo esc;       // PB0

enum Stage : uint8_t {
  ST_BOOT = 0,
  ST_UART,
  ST_MPU,
  ST_LEAK,
  ST_WAIT_LIPO,
  ST_SERVO,
  ST_ESC,
  ST_DONE
};

Stage stage = ST_BOOT;
uint32_t t_stage = 0;
uint32_t t_print = 0;
uint8_t servo_step = 0;
bool lipo_ok = false;

void reg_write(uint8_t r, uint8_t v) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(r);
  Wire.write(v);
  Wire.endTransmission();
}

uint8_t reg_read(uint8_t r) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(r);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU_ADDR, (uint8_t)1);
  return Wire.available() ? Wire.read() : 0xFF;
}

bool mpu_read(float &ax, float &ay, float &az) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU_ADDR, (uint8_t)6) != 6) return false;
  int16_t x = (Wire.read() << 8) | Wire.read();
  int16_t y = (Wire.read() << 8) | Wire.read();
  int16_t z = (Wire.read() << 8) | Wire.read();
  ax = x / 16384.0f;
  ay = y / 16384.0f;
  az = z / 16384.0f;
  return true;
}

void neutrals() {
  rudder.writeMicroseconds(1500);
  elevator.writeMicroseconds(1500);
  esc.writeMicroseconds(1500);
}

void enter(Stage s) {
  stage = s;
  t_stage = millis();
  t_print = 0;
  servo_step = 0;
  Serial.println();
  switch (s) {
    case ST_UART:
      Serial.println("=== 1/6 UART ===");
      Serial.println("Bu yaziyi goruyorsan UART OK. 'n' = sonraki");
      break;
    case ST_MPU:
      Serial.println("=== 2/6 MPU6050 ===");
      Wire.setSCL(PB6);
      Wire.setSDA(PB7);
      Wire.begin();
      Wire.setClock(100000);
      reg_write(0x6B, 0x00);
      delay(50);
      {
        uint8_t who = reg_read(0x75);
        Serial.print("WHO_AM_I=0x");
        Serial.println(who, HEX);
        if (who != 0x68) Serial.println("UYARI: 0x68 degil - kablo/adres");
        else Serial.println("MPU bulundu. 5 sn veri, sonra 'n'");
      }
      break;
    case ST_LEAK:
      Serial.println("=== 3/6 LEAK (PA5) ===");
      pinMode(LEAK_PIN, INPUT_ANALOG);
      analogReadResolution(12);
      Serial.println("Kuru/nemli farka bak. 'n' = sonraki");
      break;
    case ST_WAIT_LIPO:
      Serial.println("=== 4/6 LIPO BEKLEME ===");
      Serial.println("Servo+motor icin: LiPo tak (pervane YOK).");
      Serial.println("UBEC LED yansa 'n' yaz. LiPo yoksa 'n' ile atla (servo/motor atlanir).");
      break;
    case ST_SERVO:
      Serial.println("=== 5/6 SERVO PB4+PB5 ===");
      rudder.attach(PB4, 1000, 2000);
      elevator.attach(PB5, 1000, 2000);
      neutrals();
      Serial.println("Kisa merkez-sol-sag turu basliyor...");
      break;
    case ST_ESC:
      Serial.println("=== 6/6 ESC/MOTOR PB0 ===");
      esc.attach(PB0, 1000, 2000);
      esc.writeMicroseconds(1500);
      Serial.println("ESC 1500us (stop). PERVANE YOK.");
      Serial.println("'m' = +20us kisa test sonra 1500 | 'n' = bitir | 's' = stop");
      break;
    case ST_DONE:
      neutrals();
      Serial.println("=== BITTI ===");
      Serial.println("Hepsi siralandi. 'r' = bastan | 's' = 1500 stop");
      break;
    default:
      break;
  }
}

void setup() {
  pinMode(LED, OUTPUT);
  Serial.begin(115200);
  delay(400);
  Serial.println();
  Serial.println("AUV sequential bench 12");
  Serial.println("Komut: n=sonraki  r=basa  s=stop  m=motor(test)");
  enter(ST_UART);
}

void loop() {
  // LED kalp
  static uint32_t t_led = 0;
  if (millis() - t_led > 250) {
    t_led = millis();
    digitalWrite(LED, !digitalRead(LED));
  }

  if (Serial.available()) {
    char k = Serial.read();
    if (k == 'r') {
      lipo_ok = false;
      enter(ST_UART);
    } else if (k == 's') {
      neutrals();
      Serial.println("STOP 1500");
    } else if (k == 'n') {
      if (stage == ST_UART) enter(ST_MPU);
      else if (stage == ST_MPU) enter(ST_LEAK);
      else if (stage == ST_LEAK) enter(ST_WAIT_LIPO);
      else if (stage == ST_WAIT_LIPO) {
        lipo_ok = true;
        enter(ST_SERVO);
      } else if (stage == ST_SERVO) enter(ST_ESC);
      else if (stage == ST_ESC) enter(ST_DONE);
      else if (stage == ST_DONE) Serial.println("Zaten bitti. 'r' basta.");
    } else if (k == 'm' && stage == ST_ESC) {
      Serial.println("motor +20us 1.5sn...");
      esc.writeMicroseconds(1520);
      delay(1500);
      esc.writeMicroseconds(1500);
      Serial.println("motor 1500 stop");
    }
  }

  uint32_t now = millis();

  if (stage == ST_UART) {
    if (now - t_print > 1000) {
      t_print = now;
      Serial.print("uart ok tick=");
      Serial.println(now);
    }
  }

  if (stage == ST_MPU) {
    if (now - t_print > 200) {
      t_print = now;
      float ax, ay, az;
      if (mpu_read(ax, ay, az)) {
        Serial.print("ax=");
        Serial.print(ax, 3);
        Serial.print(" ay=");
        Serial.print(ay, 3);
        Serial.print(" az=");
        Serial.println(az, 3);
      } else {
        Serial.println("MPU okuma hata");
      }
    }
  }

  if (stage == ST_LEAK) {
    if (now - t_print > 300) {
      t_print = now;
      int raw = analogRead(LEAK_PIN);
      float v = raw * 3.3f / 4095.0f;
      Serial.print("leak raw=");
      Serial.print(raw);
      Serial.print(" V=");
      Serial.println(v, 3);
    }
  }

  if (stage == ST_SERVO) {
    // 0:1500 1:1300 2:1700 3:1500 sonra bekle
    uint32_t dt = now - t_stage;
    if (servo_step == 0 && dt > 500) {
      rudder.writeMicroseconds(1300);
      elevator.writeMicroseconds(1300);
      Serial.println("servo 1300");
      servo_step = 1;
      t_stage = now;
    } else if (servo_step == 1 && dt > 800) {
      rudder.writeMicroseconds(1700);
      elevator.writeMicroseconds(1700);
      Serial.println("servo 1700");
      servo_step = 2;
      t_stage = now;
    } else if (servo_step == 2 && dt > 800) {
      neutrals();
      Serial.println("servo 1500 merkez. 'n' = ESC asamasina");
      servo_step = 3;
    }
  }

  if (stage == ST_ESC) {
    if (now - t_print > 2000) {
      t_print = now;
      Serial.println("ESC idle 1500 - 'm' test / 'n' bitir");
    }
  }
}
