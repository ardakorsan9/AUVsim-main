// AUV tezgah testi 04 - MPU6050 ham okuma
// Baglanti: test 03 ile ayni (Type-C, LiPo YOK)
// Basari: WHO_AM_I = 0x68. Kart duz dururken az ~ +1.00 g, gyro ~ 0 dps.
//         Karti egdiginizde eksenler degisir, birakinca geri doner.
//         Deger donmuyorsa jumper gevsek; surekli 0 ise sensor uyanmamis.

#include <Wire.h>

// Serial = USART1 (PA9 TX / PA10 RX)
// NOT: sabit adi MPU olamaz - CMSIS'te Memory Protection Unit makrosu
const uint8_t MPU_ADDR = 0x68;  // ikinci sensor icin 0x69

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

void setup() {
  Serial.begin(115200);
  delay(300);
  Wire.setSCL(PB6);
  Wire.setSDA(PB7);
  Wire.begin();
  Wire.setClock(100000);

  Serial.println();
  Serial.print("WHO_AM_I=0x");
  Serial.println(reg_read(0x75), HEX);

  reg_write(0x6B, 0x00);  // PWR_MGMT_1: uyandir
  delay(100);
  reg_write(0x1B, 0x00);  // GYRO_CONFIG:  +/-250 dps  -> 131 LSB/dps
  reg_write(0x1C, 0x00);  // ACCEL_CONFIG: +/-2 g      -> 16384 LSB/g
  reg_write(0x1A, 0x03);  // DLPF ~44 Hz
  Serial.println("ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps,temp_C");
}

void loop() {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU_ADDR, (uint8_t)14);
  if (Wire.available() < 14) {
    Serial.println("okuma hatasi");
    delay(500);
    return;
  }
  int16_t ax = (Wire.read() << 8) | Wire.read();
  int16_t ay = (Wire.read() << 8) | Wire.read();
  int16_t az = (Wire.read() << 8) | Wire.read();
  int16_t tr = (Wire.read() << 8) | Wire.read();
  int16_t gx = (Wire.read() << 8) | Wire.read();
  int16_t gy = (Wire.read() << 8) | Wire.read();
  int16_t gz = (Wire.read() << 8) | Wire.read();

  Serial.print(ax / 16384.0, 3); Serial.print(",");
  Serial.print(ay / 16384.0, 3); Serial.print(",");
  Serial.print(az / 16384.0, 3); Serial.print(",");
  Serial.print(gx / 131.0, 2);   Serial.print(",");
  Serial.print(gy / 131.0, 2);   Serial.print(",");
  Serial.print(gz / 131.0, 2);   Serial.print(",");
  Serial.println(tr / 340.0 + 36.53, 1);
  delay(100);
}
