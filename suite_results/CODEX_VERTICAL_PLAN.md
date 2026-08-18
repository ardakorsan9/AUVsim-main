# AUV Yaw–Pitch Kapanışı ve Tam Otonom AUV Model Olgunluğu Planı

**Tarih:** 2026-08-04; **son güncelleme:** 2026-08-05  
**Durum:** Yalnız plan; bu belge hiçbir controller veya plant davranışını değiştirmez.  
**Nihai hedef:** MATLAB/Simulink ortamında, fiziksel görev zarfı ve belirsizlikleri açıkça tanımlanmış, gerçek sensör/aktüatör/zamanlama etkilerini içeren, otonom görevleri güvenli biçimde tamamlayan ve daha sonra gerçek araca taşınabilecek tam bir AUV sayısal ikizi.  
**Yakın öncelik:** Pitch gain'leri dondurulmuş durumdadır. Önce R=7.5 radial CTE gerçeği, helix doğrulaması ve R=5 hız–yarıçap zarfı; sonra yumuşak λ scheduling ve birleşik GNC regression. LQI/SMC/MPC/NMPC yalnız model kanıtı gerektirirse açılır.

> **2026-08-05 durum notu:** `PITCH_CLOSURE.md`, `YAW_START.md` ve güncellenmiş `PLANT_VERTICAL_TABLE.md`, bu belgedeki daha eski teşhis tablolarını sonuç/karar bakımından geçersiz kılar. Eski bölümler yapılan işin kronolojisini korur; güncel uygulama sırası Bölüm 9 ve sonrasıdır.

---

## 1. Bu plan hangi çıktılara dayanıyor?

`suite_results` içindeki mevcut çıktı seti baştan sona incelendi:

- Tur 1A/1B/2A/2B çalışma logları, tekrar özetleri ve MAT dosyaları
- İlk pitch chatter teşhis raporu ve beş teşhis grafiği
- Tur 2.5 trim teşhis/verify raporları, logları, MAT dosyaları ve dört grafik
- Tur 3A Muw işaret/birim/double-count doğrulaması
- Tur 3B λ=0…1 taramasının tüm rapor ve MAT dosyaları
- Tur 4A R=5/7.5/10 circle sonuçları ve MATLAB logu
- Tur 5A/Tur 5B sonuçları ve logları
- Eski vertical metric audit, yeni `METRIC_RESCORE`, güncel suite özeti ve dört suite grafiği
- En yeni `PLANT_VERTICAL_TABLE.md`, `elevator_pulse_audit.mat` ve `elevator_pulse_png` altındaki 12 grafik
- Handoff/plan notları

Toplam 92 mevcut çıktı dosyası kapsandı: 51 metin/log/rapor, 27 PNG ve 14 MAT. MAT dosyalarının değişken yapıları doğrulandı; en yeni elevator pulse MAT içindeki dört koşul ayrıca sayısal olarak çözümlendi.

### Çıktılar arasında otorite sırası

1. **Güncel production stack ve doğru path metriği:** `METRIC_RESCORE.md`, güncel `summary.txt`, `01..04_*.png`.
2. **Kabul edilmiş mimari kararları:** `TUR12_SUMMARY.md`, `T25_SUMMARY.md`, `TUR3_SUMMARY.md`, `TUR4A_SUMMARY.md`.
3. **Deneysel fakat production olmayan sonuçlar:** `TUR5A_SUMMARY.md`, `TUR5B_SUMMARY.md` ve bunların doğru metrikle yeniden puanlanması.
4. **Tarihsel teşhis:** T1/T2/T25 ara raporları ve eski legacy CTE sonuçları.
5. **Güncel lean plant audit:** `PLANT_VERTICAL_TABLE.md` ve `elevator_pulse_audit.mat`. u=1.5/2.0 sonuçları geçerli lean bulgudur; u≈0.8 constraint-dominated olduğundan yalnız görev zarfı kanıtıdır. Bu çalışma tam nonlinear model identification değildir.

`RESULT.md` eski controller ve eski nearest-waypoint CTE dönemine aittir; güncel başarı tablosu olarak kullanılmayacaktır. `VERTICAL_AUDIT_METRICS.md` metrik hatasını bulmak için değerlidir, fakat onun kısa-path/endpoint sonuçlarının yerini `METRIC_RESCORE.md` almıştır.

---

## 2. Yapılan çalışmaların gerçek kronolojisi ve anlamı

| Aşama | Ne yapıldı? | Kanıtlanan sonuç | Bugünkü anlamı |
|---|---|---|---|
| İlk teşhis | Pitch ref, elevator limitleri, rate filtresi, Muw, circle yaw-rate incelendi | Pitch ref HF titreşimli değil; actuator limitleri chatter kaynağı değil; yaklaşık 0.71 s rate filtresi ciddi faz gecikmesi üretiyor; Muw ana pitch moment coupling'i | Gain artırmadan önce zamanlama ve filtre düzeltilmesi doğru karardı |
| T1A | Tutarlı `dt=0.0375`, fiziksel filtre zaman sabiti korundu | Chatter hemen çözülmedi | Sorun yalnız integrasyon adımı değildi |
| T1B | `dt_controller=0.025`, `dt_guidance=0.075`, guidance ZOH | Multi-rate yapı stabil ve tekrarlanabilir | Production zamanlama temeli |
| T2A | `Ki_rate=0` | X chatter yaklaşık 0.50→0.31°/s; level pitch bias büyüdü | Rate-I geri getirilmemeli; bias trim/outer loop ile çözülmeli |
| T2B | `tau_rate` 0.356→0.178→0.05 s | Filtre gecikmesi sıfıra yaklaştı; chatter tabanı yaklaşık 0.11°/s | `tau_rate=0.05` kabul edildi |
| T25 | Closed-loop angle-I katkısı trim tablosuna katlandı | Level u=1.5/2.0 pitch hatası 0.194/0.133°; X-line 0.57° | Trim bias doğru şekilde kapatıldı; gain thrash gerekmedi |
| T3A | Muw işareti, birimi, double-count ve elevator etkinliği doğrulandı | `Muw*u*w` gerçek ve elevator momentiyle aynı mertebede; double-count yok | Muw ihmal edilemez |
| T3B | λ=0…1 Muw FF tarandı | λ=0.25 X/circle/helix pitch'i ve feedback eforunu ciddi azalttı; XZ pitch'i kötüleştirdi | λ=0.25 level/curved-flight için yararlı, fakat evrensel optimum değil |
| T4A | `r_ff=U_h*kappa` yapıldı | R=5: oran 0.789 ve %92.4 rudder sat; R=7.5/10: oran ≈1.02, sat yok, CTE ≈0.3 m | R=5 mevcut hız/authority ile infeasible; yaw gain çözümü değil |
| T5A/B | `zdot` ve gamma guidance denendi | Legacy gate'e göre fail; doğru metrikle XZ CTE 0.75→0.55 m civarı iyileşti, fakat hedef ve chatter kapıları geçilmedi | Production `K_gamma=0`, `K_zdot=0`; fikir tamamen değersiz değil ama attitude önceliğinden sonra ele alınmalı |
| Metric fix | Frenet normal CTE ve doğru pencere eklendi; yollar uzatıldı | Eski 2–3 m X/XZ CTE'nin çoğu endpoint/along-track artefaktıydı | Bundan sonra yalnız doğru normal metrikler ana gate olacak |
| İlk pulse audit | İlk lean elevator/NMP denemesinde settle geçersizdi | İlk 4 koşuldan karar çıkarılamadı | Protokolün CL-settle + OL-injection olarak düzeltilmesini sağladı |
| Güncel lean audit | u=0.8/1.5/2.0, ±1°, λ=0/0.25 tamamlandı | u=1.5/2.0'da belirgin NMP yok; u≈0.8 constraint-dominated | Cascade korunur; düşük hız envelope, λ dinamik kazancı etkiliyor |
| Pitch closure | Acquisition/steady ayrıldı, XZ λ A/B yapıldı | XZ steady 0.388°; λ=0 ile 0.332° ve daha az efor; X 0.064° | Pitch gain'leri donduruldu; ileride yumuşak λ scheduling |
| Yaw start | R=7.5/10 true metric ile ayrıldı | `|eψ|=0.31/0.16°`, rate oranı ≈1.03/1.02; R=7.5 CTE 1.315 m | Gain değil radial CTE ve envelope teşhisi sırada |

---

## 3. Değiştirilmeyecek production baseline

Yaw/pitch teşhisi sırasında aşağıdaki değerler referans baseline'dır:

| Öğe | Değer |
|---|---:|
| `dt_controller` | 0.025 s |
| `dt_guidance` | 0.075 s, ZOH |
| `tau_rate` | 0.05 s |
| `Ki_rate` | 0 |
| `Ki_angle` | 0.16 |
| Pitch mimarisi | angle loop → rate command → rate loop → elevator |
| T25 trim tablosu | `u=[0.8,1.0,1.5,2.0]`, `de=[-9.18,-7.33,-4.62,-3.17]°` |
| Muw FF | `lambda_muw_ff=0.25`, clamp/blend korunur |
| Circle yaw FF | `r_ff=U_h*kappa` |
| Production vertical guidance | `K_gamma=0`, `K_zdot=0` |

Bu baseline değiştirilmeden her yeni ölçüm önce tekrar üretilecek. `Ki_rate` geri getirilmeyecek; rastgele yaw/pitch PID taraması yapılmayacak.

---

## 4. Güncel performansın doğru yorumu

### 4.1 Pitch: genel olarak iyi, XZ'de iki farklı problem birbirine karışıyor

Doğru metrikli tarihsel full-window baseline:

| Senaryo | Mean `|pitch error|` | Pitch chatter | Theta pp (settled) | Yorum |
|---|---:|---:|---:|---|
| X-line | 0.11° | 0.0179°/s | 2.13° | Çok iyi takip |
| XZ-line | 1.44° | 0.0286°/s | 7.36° | Acquisition + steady bias karışımı |
| R=5 circle | 0.14° | 0.0253°/s | 3.55° | Pitch çok iyi; problem yaw |
| Helix | 0.21° | 0.0243°/s | 3.69° | Pitch iyi; yatay hata yaw ağırlıklı |

XZ grafiğinde araç yaklaşık 0° fiziksel pitch ile başlarken referans yaklaşık 21.8° başlıyor. Araç önce yaklaşık 18.2°'ye düşüp sonra referansa yaklaşıyor; `pitch_ref` daha sonra 26° amplitude limitine ulaşıyor. Bu nedenle 1.44° ortalama hata üç şeyi karıştırıyor:

1. Büyük başlangıç acquisition manevrası,
2. Muw FF kaynaklı olası XZ signed bias,
3. 26° guidance amplitude sınırı.

`PITCH_CLOSURE.md` bu ayrımı tamamladı: XZ'de λ=0.25 ile acquisition 19.75 s, acquisition mean `|eθ|=1.556°`, gerçek steady mean `|eθ|=0.388°` ve p95 0.437°'dir; saturation %0'dır. Dolayısıyla tarihsel 1.44° controller steady kusuru değil acquisition-dominated ortalamadır. Pitch gain'leri dondurulmuştur; ileride transient iyileştirme gerekirse gain yerine önce FF/reference shaping ele alınır.

### 4.2 Muw FF global değil, operating-point bağımlı ele alınmalı

Doğrudan karşılaştırılabilir T3 sonuçları:

| Senaryo | λ=0 pitch | λ=0.25 pitch | λ=0 chatter | λ=0.25 chatter |
|---|---:|---:|---:|---:|
| X-line | 0.57° | 0.15° | 0.0789 | 0.0506 |
| XZ-line | 0.94° | 1.55° | 0.0634 | 0.0665 |
| Circle | 0.40° | 0.14° | 0.0405 | 0.0237 |
| Helix | 0.26° | 0.21° | 0.0342 | 0.0256 |

Son closure A/B, XZ climb'da λ=0'ın λ=0.25'e göre daha hızlı acquisition (15.05 s yerine 19.75 s), daha düşük feedback elevator RMS (2.877° yerine 5.133°), daha düşük steady pitch error (0.332° yerine 0.388°) ve daha iyi CTE verdiğini gösterdi. Level/X ise λ=0.25 ile `|eθ|≈0.064°` tutuyor. Sonuç yeni pitch gain'i değil, ileride **yumuşak operating-point scheduling** gerektiriyor: level'da λ≈0.25, belirgin climb/descent koşulunda daha düşük λ; sert eşik yok.

### 4.3 Yaw: feasible yarıçaplarda iyi; açık konu radial guidance ve R=5 authority

Son `YAW_START.md` sonucu:

| Yarıçap | Mean `|eψ|` | `r/(U_h κ)` | Rudder sat. | Mean rudder | `CTE_perp` |
|---:|---:|---:|---:|---:|---:|
| R=7.5 | 0.31° | 1.030 | %0 | 14.25° | 1.315 m |
| R=10 | 0.16° | 1.018 | %0 | 4.46° | 0.284 m |

R=7.5/10'da wrapped error ile unwrapped lag uyuşuyor; yaw-rate FF geometrik talebi izliyor. Bu nedenle yaw gain/FF thrash yapılmayacak. R=7.5'te rudder ortalaması limite çok yakınken yaw hatası küçük fakat radial CTE büyüktür; önce bunun gerçek radial offset mi, progress/projection metriği mi, speed/radius envelope etkisi mi olduğu ayrılır. Yaklaşık 35° sınıfındaki eski sonuç feasible R=7.5/10 unwrap problemi değil, R=5 hard-turn authority problemidir.

### 4.4 Circle metriğinde kalan raporlama sorunu

`METRIC_RESCORE.md`, circle satırında yanlışlıkla açık-yol `0.88*s_total` kesmesinin kullanıldığını açıkça işaretliyor. Güncel `summary.txt` de circle için pencereyi `settled_before_end` olarak etiketliyor. Circle kapalı yol olduğundan nihai yaw/path kabulü öncesinde:

- endpoint maskesi kaldırılmalı,
- settled tam-tur ve tur-başına metrikler kullanılmalı,
- radial error, heading error, course error ve yaw-rate error ayrı raporlanmalı.

Mevcut R=7.5 ve R=10 sonuçları sağlıklı bir feasibility göstergesidir; fakat nihai near-perfect gate yeni kapalı-yol metriğiyle verilmelidir.

---

## 5. “Kusursuza yakın” kabul tanımı

Sıfır sayısal hata hedeflenmeyecek. Hedef; feasible görev zarfında düşük steady hata, hızlı ve kontrollü acquisition, düşük chatter, düşük actuator eforu ve saturation olmamasıdır.

### 5.1 Yaw kabul kapıları

| Metrik | İlk kabul | Stretch hedef |
|---|---:|---:|
| Straight settled mean `|e_psi|` | ≤0.25° | ≤0.10° |
| Feasible circle/helix settled mean `|e_psi|` | ≤1.0° | ≤0.5° |
| Feasible circle/helix p95 `|e_psi|` | ≤2.0° | ≤1.0° |
| Mean signed yaw bias | ≤0.5° | ≤0.25° |
| `mean(r)/mean(U_h*kappa)` | 0.98–1.02 | 0.99–1.01 |
| Rudder saturation, feasible görev | ≤1% | 0% |
| Circle settled radial/normal CTE | ≤0.30 m | ≤0.20 m |
| Helix yatay normal hata | ≤0.40 m | ≤0.25 m |

Acquisition ayrı raporlanacak: ilk kez ±2° bandına giriş, bu bantta kalma süresi, peak yaw error ve ilk tur ile sonraki turlar arasındaki fark.

### 5.2 Pitch kabul kapıları

| Metrik | İlk kabul | Stretch hedef |
|---|---:|---:|
| Level hold signed mean error | ≤0.10° | ≤0.05° |
| Level hold mean `|e_theta|` | ≤0.15° | ≤0.10° |
| Feasible steady path segment mean `|e_theta|` | ≤0.25° | ≤0.15° |
| p95 `|e_theta|` | ≤0.50° | ≤0.30° |
| Pitch chatter | ≤0.05°/s | ≤0.03°/s |
| Elevator saturation | 0% | 0% |
| X/circle/helix regresyonu | ≤5% | ≤2% |

XZ acquisition için ayrı gate:

- 0°→yaklaşık 22° komut geçişinde rise time,
- peak/overshoot,
- ±0.5° bandına yerleşme süresi,
- acquisition sırasında elevator max/RMS ve saturation,
- pitch amplitude/rate limit hit yüzdesi.

Full-window XZ mean pitch error, steady tracking gate'i olarak tek başına kullanılmayacak.

---

## 6. Yaw–pitch closure deney tasarımı (tarihsel çerçeve)

## Aşama 0 — Tek ve güvenilir baseline üret

Controller değişmeden önce ölçüm altyapısı netleştirilecek.

1. X, XZ, R=5/7.5/10 circle ve helix aynı başlangıç koşullarıyla tekrar çalıştırılır.
2. Açık yollar `settled_before_end`; circle settled tam-tur ölçülür.
3. Yaw logları:
   - `psi_ref`, `psi`, `chi_path`, actual course,
   - `e_psi`, `e_chi`, β,
   - `r_ff`, `r`, `r_ref-r`,
   - rudder feedback/FF/total/unsat ve saturation,
   - curvature, `U_h`, radial error.
4. Pitch logları:
   - `pitch_raw`, filtered/rate-limited/amplitude-limited `pitch_ref`,
   - `theta_phys`, `theta_phys_dot`, rate command,
   - trim, Muw FF, feedback ve total elevator,
   - `Muw*u*w`, elevator momenti, `w`, `zdot`, gamma.
5. Acquisition ve steady pencereleri ayrı raporlanır.
6. İki tekrarın metrikleri tekrarlanabilir olmalıdır.

**Aşama 0 çıkış kapısı:** Circle kapalı-yol metriği, yaw heading/course ayrımı ve pitch acquisition/steady ayrımı doğrulanmadan controller parametresi değiştirilmez.

## Aşama 1 — Yaw authority ve steady-turn ihtiyacını ölç

En büyük açık yaw olduğu için ilk aktif çalışma budur.

### 1A. Feasibility haritası

R=5/7.5/10 ve seçilmiş hız noktalarında şu tablo çıkarılır:

- gerekli `U_h*kappa`,
- gerçekleşen steady `r`,
- rudder mean/RMS/max ve saturation,
- steady `e_psi`, `e_chi`, radial error,
- roll ve sideslip,
- gerekli steady rudder açısı.

Hızı düşürmenin otomatik çözüm olduğu varsayılmayacak. Gerekli yaw rate yaklaşık `U/R` ile azalırken rudder moment authority yaklaşık `u²` ile değişir. Bu nedenle curvature-aware speed scheduler yalnız ölçülmüş feasibility haritasından türetilecek.

### 1B. Mevcut yaw controller'ın bias mekanizmasını ayır

Şu soru cevaplanacak:

> Sabit eğrilikte gerekli steady rudder komutu nereden geliyor: actuator feedforward/trim'den mi, yoksa kalıcı heading error'ın P katkısından mı?

Eğer steady rudder yükünü P error taşıyorsa, yalnız Kp artırmak near-perfect ve robust çözüm değildir. Öncelik sırası:

1. `delta_r_required(U_h,kappa)` steady-turn rudder feedforward/trim haritası,
2. outer heading/course → yaw-rate command ve inner yaw-rate feedback ayrımının değerlendirilmesi,
3. actuator FF + feedback anti-windup,
4. yalnız residual dinamik hata kalırsa sınırlı model-temelli gain ayarı,
5. integral ancak FF sonrası kalan küçük bias için ve saturation-aware olarak.

### 1C. Circle giriş manevrası

Unwrapped grafiklerde büyük fark ilk saniyelerde birikiyor ve sonra taşınıyor. Bu nedenle:

- başlangıç tangent heading uyumu,
- yaw reference ramp/curvature onset,
- ilk 5 s rudder saturation,
- ilk tur ile ikinci tur yaw/radial error

ayrı incelenir. Reference smoothing geometrik talebi geciktirmemeli; fiziksel olarak imkânsız curvature step'i de doğrudan aktüatöre verilmemelidir.

**Aşama 1 çıkış kapısı:** R=7.5/10 ve feasible helix koşulunda yaw kabul hedefleri geçilecek. R=5 için ya ölçülmüş feasible hız bulunacak ya da minimum radius görev zarfı ilan edilecek. R=5 mevcut hızda gain artırılarak zorlanmayacak.

## Aşama 2 — Pitch'i yeniden tasarlamadan önce gerçek kalan hatayı ölç

### 2A. Hold ve acquisition testlerini ayır

İki farklı deney sınıfı kullanılacak:

1. **Attitude hold:** İstenen operating point'te önceden settle olmuş araç; küçük ±pitch adımları ve rampalar.
2. **Mission acquisition:** 0° başlangıçtan XZ'nin yaklaşık 22° eğimine giriş.

Hold testi steady controller doğruluğunu, acquisition testi bandwidth/reference shaping/authority'yi ölçer. İki sonuç tek mean hata içinde birleştirilmez.

### 2B. XZ için Muw FF A/B

Aynı başlangıç, aynı guidance ve doğru metrikle en az:

- `lambda_muw_ff=0`,
- `lambda_muw_ff=0.25`

karşılaştırılır. Ana pitch metrikleri signed/absolute error, acquisition time, chatter, feedback elevator RMS ve total moment residual'dır. Path `CTE_perp` ve `|e_z|` yalnız secondary gözlem olarak tutulur; bu aşamada attitude controller path guidance ile karıştırılmaz.

Karar olasılıkları:

- λ=0.25 yalnız level/low-gamma için iyi ise operating-point/gamma/w bağımlı scheduling,
- bias trim/AoA kaynaklı ise slope/flight-condition elevator FF,
- sorun reference amplitude/rate limit ise feedback gain yerine reference/limit tasarımı,
- yalnız plant bandwidth yetersizliği kanıtlanırsa pitch loop mimarisi/gain'i.

Muw coupling körlemesine tamamen iptal edilmeyecek. λ≥0.50'nin level ve XZ'de overcompensation yaptığı zaten kanıtlanmıştır; yeniden geniş λ sweep yapılmayacak.

### 2C. İyi çalışan senaryoları koru

Her pitch adayı aşağıdakileri korumalı:

- X-line yaklaşık 0.11° pitch error,
- circle yaklaşık 0.14°,
- helix yaklaşık 0.21°,
- chatter 0.02–0.03°/s bandı,
- elevator saturation %0.

`Ki_angle` artırmak veya `Ki_rate` geri getirmek varsayılan çözüm değildir. T1–T25 çıktıları bunun bias/chatter trade-off'unu zaten göstermiştir.

**Aşama 2 çıkış kapısı:** Steady pitch gate bütün feasible senaryolarda geçilecek; XZ acquisition ayrıca tanımlı time-domain gate'i geçecek. İyileştirme yaw performansını veya X/circle/helix pitch'i bozmayacak.

## Aşama 3 — Birleşik yaw–pitch regression suite

1. X-line ve XZ-line.
2. R=7.5 ve R=10 circle.
3. Feasibility haritası izin verirse scheduled R=5.
4. Helix.
5. En az iki tekrarlı koşu.

Birlikte raporlanacak:

- acquisition ve steady yaw/pitch hataları,
- yaw/pitch chatter,
- actuator RMS/HF jitter/max/saturation,
- `CTE_perp`, yatay normal error ve `|e_z|`,
- yaw-rate/curvature oranı,
- amplitude/rate limit hit yüzdeleri,
- roll/sideslip coupling.

**Ana kapı:** Yaw ve pitch birlikte kabul edilmeden vertical path/depth controller geliştirmesine geçilmeyecek.

---

## 7. Mevcut elevator/NMP çıktısının doğru hükmü

Güncellenmiş `PLANT_VERTICAL_TABLE.md` lean audit'i tamamlamıştır:

- Closed-loop settle + open-loop ±1° elevator injection kullanılmıştır.
- u=1.5 ve 2.0'da `δe → M_elev → q → w → θ → zdot → z` sırası görülmüş; belirgin inverse/NMP response bulunmamıştır.
- u=1.5'te onset yaklaşık 0.025 s, u=2.0'da ölçüm çözünürlüğü içinde 0 s'dir.
- u≈0.8'de elevator yaklaşık −15° sınıra yakındır ve pulse işaretiyle pitch cevabı tutarlı değildir; bu nokta plant zero kanıtı değil, **constraint/envelope** bulgusudur.
- λ=0.25 u=1.5/2.0'da inverse karakteri değiştirmemiş; fakat pitch pulse genliğini yaklaşık %27–31 ve `zdot` cevabını yaklaşık %19–24 azaltmıştır. Bu nedenle “NMP bakımından nötr”, fakat dinamik kazanç bakımından nötr değildir.

**Hüküm:** Cruise'ta lean NMP engeli yok; mevcut cascaded pitch mimarisi korunur. Bu audit tek başına tam A/B, controllability/observability veya nonlinear model doğrulaması değildir. LQI/MPC açmak için hâlâ trim-local model ve bağımsız validation gerekir.

---

## 8. Lean audit'ten tam controller modeline geçiş

Lean pulse audit tamamlandı. Bundan sonraki amaç aynı pulse'ları çoğaltmak değil, ihtiyaç doğduğunda kontrolcü tasarımına yetecek **trim-local model ailesini** kanıtlamaktır. Bu çalışma yaw/pitch closure ve görev zarfı tamamlanıncaya kadar deferred kalır.

### 8.1 Önce gerçek trim/equilibrium

T25 tablosu closed-loop level pitch bias trimidir; tek başına open-loop 6-DOF equilibrium değildir. Pulse öncesinde her hız için tam operating point çözülmelidir. En az şu koşullar kontrol edilir:

- `nu_dot≈0`, özellikle `u_dot`, `w_dot`, `q_dot`,
- `q≈0`, `theta_phys_dot≈0`,
- `zdot≈0` veya tanımlı sabit flight-path condition,
- elevator, thrust, theta ve gerekiyorsa w birlikte çözülür,
- 5–10 s doğrulamada u/theta/w/zdot drift eşikleri geçilir.

Fiziksel open-loop equilibrium yoksa iki doğru seçenek vardır:

1. Stabilize edilmiş closed-loop operating point çevresine küçük control injection uygulayıp baseline-subtraction yapmak,
2. Feasible steady flight-path operating point seçmek.

Geçersiz pre-pulse koşuluna pulse eklenmeyecek.

### 8.2 Genişletilmiş identification — yalnız ihtiyaç halinde

Tam 32 koşul varsayılan iş değildir. Ancak cascaded mimari görev kapılarını geçemez veya model-tabanlı controller benchmark'ı gerekirse:

1. u, trim pitch/flight-path angle, depth ve payload/CG operating-point grid'i kurulur.
2. Her noktada küçük step/pulse yanında chirp veya PRBS uygulanır; amplitude dependence için en az iki küçük genlik kullanılır.
3. Aynı veriyle fit ve validation yapılmaz; ayrı maneuver kayıtları tutulur.
4. Local `A,B,C,D`, delay, poles/zeros, frequency response, controllability/observability ve belirsizlik aralıkları raporlanır.
5. Reduced controller modeli, kendisinden daha yüksek sadakatli plant üzerinde ve görmediği inputlarla doğrulanır.

`z` integratör içerdiği için NMP hükmü yalnız z grafiğine bağlanmaz; `w`, `zdot`, transmission zero ve ilk/uzun dönem yön birlikte kullanılır.

### 8.3 Controller karar kapısı

- Minimum-phase + iyi authority/controllability, fakat cascade hedefi geçemiyor → gain-scheduled coupled LQI benchmark.
- Güçlü ve güvenilir RHP zero/inverse response → MPC/NMPC adayı.
- Güçlü matched uncertainty → NDI + super-twisting SMC adayı.
- Büyük hız bağımlılığı → gain scheduling/LPV.
- Düşük hızda authority yok → görev zarfı veya aktüatör değişikliği.

Yeni mimari yalnız “teoride daha gelişmiş” olduğu için açılmayacak. Geçerli local model, mevcut cascade'in karşılayamadığı ölçülmüş gereksinim ve bağımsız benchmark olmadan LQI/SMC/MPC/NMPC yazılmayacak.

---

## 9. Kısa uygulama kuyruğu

1. **Şimdi:** R=7.5 için analytic radial error ile `CTE_perp`i karşılaştır; tam-tur ve tur-başına p95/max çıkar; path tangent, `psi_ref`, actual course, sideslip ve rudder near-limit süresini ayır.
2. R=7.5 radial sorun metric ise metric'i düzelt; gerçek guidance offset ise guidance/projection'ı düzelt; gerçek ve near-limit ise radius–speed envelope ilan et. Yaw gain değiştirme.
3. R=7.5/10 helix'i aynı gerçek metriklerle doğrula.
4. R=5 için hız–yarıçap–rudder authority haritası çıkar; feasible hız yoksa minimum dönüş yarıçapını görev kısıtı yap.
5. Level/climb/descent arasında λ için sert switch değil, yumuşak blend + hysteresis tasarla; X ve XZ A/B ile doğrula.
6. X, XZ, R=7.5/10 circle, feasible R=5 ve helix üzerinde birleşik yaw–pitch regression'ı en az iki tekrarla geçir.
7. Roll, speed ve depth/altitude loop'larını aynı “feasibility → acquisition/steady → actuator margin → regression” disipliniyle sırayla kapat.
8. Sonra Bölüm 11'deki model olgunluğu zincirine geç: plant doğrulama → trim/envelope → identification → aktüatör/enerji → çevre → sensör/zaman → navigation → GNC → perception/autonomy → MIL/SIL/PIL/HIL → su testi korelasyonu.

---

## 10. Değişmez çalışma disiplini

- Her deney tek hipotez sınar.
- Bir koşuda tek yapısal değişken değiştirilir.
- Aynı başlangıç koşulu, aynı pencere ve aynı doğru metrik kullanılır.
- Ham time-series olmadan yalnız özet tabloyla kabul verilmez.
- Mean yanında signed mean, RMS, p95, max, delay, saturation ve actuator effort bulunur.
- Acquisition ile steady-state birbirine karıştırılmaz.
- Fiziksel olarak infeasible görev controller hatası sayılmaz.
- R=5 için “daha düşük hız kesin çözer” varsayılmaz; u² rudder authority nedeniyle ölçülür.
- Eski nearest-waypoint CTE ana başarı metriği olarak kullanılmaz.
- Yaw/pitch kabulünden önce depth/path controller ve ileri controller geliştirilmez.
- `truth` state hiçbir navigation/control/autonomy bloğuna yanlışlıkla verilmez; yalnız ölçüm ve doğrulama tarafında kullanılır.
- Controller modeli ile doğrulama plant'i aynı model olmayacaktır.
- Her stochastic koşu seed, parametre örneği ve yazılım/model sürümüyle tekrar üretilebilir olacaktır.

**Güncel kısa karar:** Pitch gain'leri dondurulmuştur; cruise lean NMP engeli görülmemiştir; feasible R=7.5/10 yaw hatası yaklaşık 0.2–0.3° düzeyindedir. Bir sonraki gerçek problem yaw gain değil R=7.5 radial CTE ve R=5 görev zarfıdır. Tam otonomi çalışması bu GNC temeli bozulmadan, aşağıdaki model olgunluğu kapılarıyla büyütülecektir.

---

## 11. Hedef mimari: tek model değil, iki ayrı model

### 11.1 High-fidelity truth plant / sayısal ikiz

Doğrulama ortamında bulunacak:

- nonlinear 6-DOF rigid-body + added-mass dinamiği,
- Coriolis/centripetal, nonlinear damping ve hydrostatic restoring,
- gerçekçi actuator, propulsion, enerji, sensör, gecikme ve çevre modelleri,
- temas/çarpışma ve fault injection,
- tüm gerçek state'ler; yalnız scoring ve sensör üretimi için.

### 11.2 Onboard/controller modeli

Araç üzerinde çalışacak taraf:

- ölçülen/kestirilen state'ler,
- trim tabloları ve gerekiyorsa reduced/gain-scheduled local modeller,
- guidance, control allocation, estimator, planner ve mission executive,
- code-generation/fixed-step uyumlu deterministik algoritmalar.

**Temel kural:** Controller doğrulandığı plant'in tam denklemlerine veya truth state'lerine erişmez. Böylece “inverse crime” ve yalnız simülasyonda çalışan sahte kusursuzluk önlenir.

---

## 12. Tam model olgunluğu aşamaları ve geçiş kapıları

### M0 — ConOps, gereksinim ve görev zarfı

Tanımlanacak: gövde/aktüatör mimarisi, görev tipleri, hız–derinlik–minimum dönüş yarıçapı, akıntı, batimetri, endurance, payload, sensör seti, haberleşme kısıtları, yüzeye çıkış ve abort davranışı. Body/NED eksenleri, işaretler, derece/radyan ve `z` yönü tek sözlükte sabitlenir.

**Kapı G0:** Her görev için sayısal başarı, güvenlik ve actuator/enerji limitleri vardır; “kusursuz” sözcüğü ölçülebilir metriklere çevrilmiştir.

### M1 — 6-DOF yapısal plant doğrulaması

- `M_RB`, `M_A`, `C(ν)`, `D(ν)`, `g(η)` ve `J(η)` terimleri tek tek test edilir.
- Kütle/atalet ve added-mass simetrisi/pozitifliği, Coriolis enerji özelliği, damping'in dissipative olması ve hydrostatic denge kontrol edilir.
- Zero-input, saf eksen kuvvet/moment, işaret, coordinate-transform ve enerji/passivity testleri yapılır.
- Her katsayıya kaynak etiketi verilir: CAD/ölçüm, CFD, literatür ölçeği, deney veya varsayım; belirsizlik aralığı tutulur.

**Kapı G1:** Yapısal invariant ve işaret testleri geçer; açıklanamayan enerji üretimi veya frame karışıklığı yoktur.

### M2 — Trim ve uygulanabilir zarf haritası

- Hız, depth, pitch/flight-path angle, payload, CG/CB, battery state ve akıntı için equilibrium çözülür.
- Thrust, rudder/elevator, AoA/sideslip ve rate margin'leri çıkarılır.
- Düz seyir, climb/descent, steady circle ve helix trim noktaları doğrulanır.
- Feasible/infeasible bölgeler görev planlayıcıya aktarılabilir tablo haline gelir.

**Kapı G2:** Her nominal görev segmentinin stabil veya kontrol edilebilir trim'i ve actuator rezervi vardır; u≈0.8 ve R=5 gibi sınırlar açıkça etiketlidir.

### M3 — Maneuver ve system-identification doğrulaması

- Axial thrust step/ramp; rudder/elevator ±step/pulse; chirp/PRBS; zig-zag; turning circle; spiral; dive/climb/pull-up; combined 3-D maneuvers.
- Birden fazla hız ve küçük genlik; repeatability; fit/validation veri ayrımı.
- Local model ailesi, hydrodynamic coefficient confidence aralıkları, poles/zeros, delay, frequency response ve cross-coupling çıkarılır.
- Model daha önce görmediği maneuverları time-domain ve frequency-domain belirsizlik bandı içinde tahmin eder.

**Kapı G3:** Controller modeli yalnız kalibrasyon koşularını değil bağımsız validation koşularını da gereksinimde tanımlanan hata bandında tahmin eder.

### M4 — Actuator, propulsion ve enerji modeli

- Motor–propeller/thruster thrust/torque map'i; advance ratio/araç hızı etkisi.
- Servo lag, deadband, backlash, rate/position limit, command quantization, saturation ve arıza durumları.
- Control allocation, actuator priority ve anti-windup.
- Battery SOC/voltage sag, güç tüketimi, endurance; gerekliyse thermal/cavitation limitleri.

**Kapı G4:** Komut → actuator → kuvvet/moment → güç zinciri bench/datasheet/deney verisiyle izlenebilir; görev enerji bütçesi kapanır.

### M5 — Çevre ve temas modeli

- Uniform current, yön sweep'i, shear ve seçilmiş turbulence modeli.
- Yoğunluk/tuzluluk/sıcaklık/depth etkileri, buoyancy/compressibility; yüzeye yakınsa dalga etkisi.
- Bathymetry, seabed/engel geometrisi, collision/contact ve güvenli altitude.
- Parametre ve çevre belirsizlikleri deterministik tek koşu değil dağılım olarak tutulur.

**Kapı G5:** Nominal, zor ve sınır senaryoları tanımlıdır; controller ideal durgun suya bağımlı değildir.

### M6 — Sensör, haberleşme ve zaman tabanı

- IMU bias, random walk, scale/misalignment, saturation ve vibration.
- DVL bottom/water-track, beam dropout ve altitude/range limiti.
- Pressure/depth drift; magnetometer anomaly; GPS yalnız yüzeyde.
- Varsa USBL/LBL/acoustic modem latency, düşük bandwidth ve packet loss.
- Sonar/kamera range, FOV, noise, false alarm/missed detection ve visibility.
- Asenkron sample rate, timestamp, transport delay, jitter, clock drift ve out-of-order/dropout.

**Kapı G6:** Perfect-state controller kapalıdır. Aynı görev yalnız timestamp'li sensor bus ve estimator çıktısıyla tamamlanır.

### M7 — Navigation/state estimation

- IMU propagation + DVL/depth/magnetometer/GPS-surface/acoustic aiding için error-state EKF/UKF veya gerekirse factor graph benchmark'ı.
- Body velocity, pose, bias ve mümkünse current estimate.
- Innovation/residual, NIS/NEES, covariance consistency, divergence/recovery ve dropout testleri.
- Surface GPS fix, DVL kaybı, magnetometer bozulması ve acoustic outlier senaryoları.

**Kapı G7:** Position/attitude/velocity hatası ve covariance tutarlılığı görev gereksinimindedir; sensör kaybında tanımlı degraded/abort davranışı vardır.

### M8 — Birleşik GNC ve fault tolerance

- Inner rate/attitude; speed; depth/altitude; 3-D path following; current compensation.
- Guidance–controller bandwidth ayrımı, reference shaping, gain scheduling, anti-windup ve allocation.
- Feasible curvature/speed generation; actuator margin'i planner'a geri beslenir.
- Stuck/degraded actuator, sensor invalid ve estimator-health için fault detection/isolation ve degraded control.

**Kapı G8:** Nominal + belirsiz + fault senaryolarında constraint ihlali olmadan GNC kapıları geçer; kontrolcü yalnız truth-state koşusunda başarılı değildir.

### M9 — Perception, planning ve mission autonomy

- Önce bilinen haritada waypoint/lawnmower/survey/loiter/surface/return-home.
- Sonra sonar/kamera perception, occupancy/bathymetry map, obstacle detection/tracking ve local replanning.
- Gerekirse terrain-relative navigation/SLAM; sualtında lidar örneği körlemesine kopyalanmaz, kullanılan sonar/kamera fiziğine uyarlanır.
- Mission executive: pre-dive check → dive → transit → survey/inspect → loiter/dock/return → surface; low battery, leak, lost comms, localization degraded, obstacle ve actuator fault için recovery/abort.
- Karar mantığı Stateflow/behavior-tree benzeri açık state ve transition guard'larıyla sınanır.

**Kapı G9:** Tek rota demosu değil; farklı çevre, başlangıç, sensör ve fault örneklerinde görev tamamlama ve güvenlik oranı hedefi geçer.

### M10 — Verification ladder ve gerçek araca aktarım

1. Component/unit test harness.
2. MIL-0: perfect state, nominal plant.
3. MIL-1: high-fidelity sensors/actuators/environment.
4. Monte Carlo + uncertainty/sensitivity + fault injection.
5. Back-to-back model regression ve requirements traceability.
6. SIL: generated code ile model sayısal eşdeğerliği.
7. PIL: hedef işlemci, gerçek data type ve execution-time/stack ölçümü.
8. HIL: gerçek autopilot/IO; sensor/actuator emulators; real-time overrun ve bus faults.
9. Bench/tank: CG/CB, buoyancy, actuator/thruster ve sensör kalibrasyonu.
10. Kademeli su testi: tethered safety → düz hat → depth → dönüş → 3-D path → otonom görev.
11. Gerçek loglarla parameter update; calibration verisinden ayrı validation seferi.

**Kapı G10:** MIL/SIL/PIL/HIL sonuçları tanımlı toleranslarda eşdeğer; gerçek su loglarında prediction residual ve görev metrikleri kabul bandındadır.

---

## 13. Zorunlu simülasyon kataloğu

| Test ailesi | Minimum içerik | Neyi kanıtlar? |
|---|---|---|
| Yapısal plant | zero-input, eksen işaretleri, enerji/damping, transform | Denklemler fiziksel ve tutarlı mı? |
| Trim/envelope | hız–depth–gamma–radius–payload–current | Görev fiziksel olarak yapılabilir mi? |
| Maneuver/ID | step, pulse, chirp/PRBS, zig-zag, circle, dive/helix | Katsayılar ve local modeller tahmin edici mi? |
| GNC nominal | line, XZ, circle, helix, depth/altitude, 3-D spline | Takip performansı ve coupling |
| Disturbance | current magnitude/direction, shear/turbulence, density | Robustluk ve current compensation |
| Sensor/navigation | bias/noise/delay/dropout/outlier/clock drift | Estimator doğruluğu ve consistency |
| Actuator/fault | saturation/rate/deadband, %degrade, stuck surface, thruster loss | Margin, FDI ve degraded mode |
| Perception | range/FOV/noise, false/missed detection, visibility | Harita ve obstacle güvenilirliği |
| Autonomy | route blocked, comm loss, low battery, localization loss, abort | Mission executive güvenliği |
| Deployment | fixed-step, data type, overrun, SIL/PIL/HIL equivalence | Gerçeklenebilir yazılım |

Senaryo kombinasyonları ilk günden tam kartesyen çarpım yapılmaz. Önce one-factor screening, sonra etkili parametreler için designed experiments/Latin-hypercube ve en sonda seçilmiş worst-case + Monte Carlo kullanılır.

---

## 14. “Gerçekten modellenebilir” ve “kusursuza yakın otonom” kabulü

Model, yalnız güzel grafik ürettiğinde değil aşağıdakiler sağlandığında modellenebilir sayılır:

1. Her ana parametrenin kaynağı ve belirsizliği izlenebilir.
2. Trim ve görev zarfı çözülmüş; infeasible görevler kontrolcü kusuru gibi sunulmamıştır.
3. Controller modeli bağımsız maneuver verisini tahmin eder; residual bias ve koşula bağlı sistematik hata incelenmiştir.
4. Truth plant ile onboard model ayrıdır.
5. Perfect state, sıfır delay ve ideal actuator varsayımları final acceptance'ta yoktur.
6. Sensör estimator covariance'i tutarlıdır; dropout ve outlier recovery vardır.
7. GNC actuator/energy limitlerini ihlal etmez ve görev zarfını planner'a bildirir.
8. Autonomy başarısı tek deterministik koşu değil, tanımlı belirsizlik dağılımındaki mission-completion/safety olasılığıyla ölçülür.
9. Aynı suite MIL → SIL → PIL → HIL'de yeniden kullanılır.
10. Son kabul gerçek su validation loguyla simülasyon korelasyonudur.

“Kusursuza yakın” sıfır hata anlamına gelmez. Doğru tanım: feasible envelope içinde p95/p99 tracking, constraint, collision, estimator consistency, enerji rezervi ve görev tamamlama kapılarının yüksek güvenle geçilmesi. Sayısal eşikler M0'da görev ve sensör/aktüatör özelliklerinden türetilecek; keyfi olarak sonradan kolaylaştırılmayacaktır.

---

## 15. MATLAB/Simulink proje yapısı hedefi

- Plant, environment, sensors, estimator, GNC, autonomy ve scoring ayrı model-reference/harness sınırlarında.
- `truth_bus`, `sensor_bus`, `nav_bus`, `command_bus`, `health_bus` ayrımı.
- Tek source-of-truth data dictionary: units, frames, geometry, mass/inertia, coefficient provenance ve uncertainties.
- Ideal/high-fidelity/fault sensor ve actuator variant'ları.
- Variable-step truth model ile fixed-step onboard model arasında açık rate transition ve timestamp.
- Scenario catalog, deterministic seed, automatic metric/report ve regression baseline.
- Lisans varsa Simulink Test/Requirements, Stateflow, Sensor Fusion and Tracking/Navigation Toolbox, Embedded Coder ve Simulink Real-Time; yoksa aynı mimari temel MATLAB/Simulink harness ve script'leriyle korunur.

---

## 16. Makale ve gerçek veri nasıl kullanılacak?

Makale faydalıdır fakat doğrudan katsayı kopyalama kaynağı değildir. Öncelik sırası:

1. Aynı/çok benzer gövde geometrisi, Reynolds aralığı ve actuator yerleşimi.
2. PMM/tow-tank/CFD ile doğrulanmış added-mass ve damping katsayıları.
3. Propeller/thruster/rudder/elevator map ve servo dinamiği.
4. IMU/DVL/depth/acoustic/sonar gerçek datasheet ve logları.
5. Zig-zag, turning-circle, dive/helix veya field-test validation verisi.

Her dış katsayı “başlangıç prior'ı” olur; ölçekleme gerekçesi ve belirsizliği yazılır, sonra kendi modelimizin bağımsız maneuver verisiyle kalibre/doğrulanır. Kullanıcının bulacağı makaleler özellikle araç geometrisine ve sensör setine yakınsa bu aşamaları ciddi biçimde güçlendirir.

---

## 17. Tek satırlık ana sıra

**R=7.5 radial gerçeklik → helix → R=5 speed/radius envelope → yumuşak λ schedule → birleşik yaw/pitch → roll → speed → depth/altitude → 6-DOF yapısal doğrulama → trim/envelope atlası → bağımsız maneuver/ID validation → actuator/energy → environment → sensor/time → navigation → full GNC/fault tolerance → perception/planning/mission executive → Monte Carlo MIL → SIL → PIL → HIL → tank/su testi → gerçek logla model korelasyonu → otonom görev acceptance.**

---

## 18. Dış teknik dayanaklar

- Fossen'ın standart 6-DOF marine-craft yapısı: [Marine Craft Model](https://www.fossen.biz/html/marineCraftModel.html)
- MathWorks yüksek sadakatli propulsion + sensor/GNC/state-estimation AUV örneği: [Modeling and Simulation of an Autonomous Underwater Vehicle](https://www.mathworks.com/help/aeroblks/modeling-and-simulation-of-an-autonomous-underwater-vehicle.html)
- IMU/DVL/GPS pose-estimation örneği: [AUV Pose Estimation Using Inertial Sensors and DVL](https://www.mathworks.com/help/fusion/ug/autonomous-underwater-vehicle-pose-estimation-using-inertial-sensors-and-doppler-velocity-log.html)
- State machine/mission-supervision altyapısı: [Stateflow Documentation](https://www.mathworks.com/help/stateflow/index.html)
- Model → generated code → target doğrulama zinciri: [SIL, PIL and HIL Tests](https://www.mathworks.com/help/sltest/sil-pil-and-hil-tests.html)
- Az deneyle hidrodinamik model kalibrasyonu yaklaşımı: [Fast calibration procedure for robotic underwater vehicles](https://arpi.unipi.it/handle/11568/844456)

---

## 19. Matematiksel öğrenme kaydı ve nihai anlatım zorunluluğu

Bu proje yalnız çalışan simülasyon üretmeyecek; sistem tamamlandığında aracın neden o şekilde tasarlandığını öğreten, denklemler ile deney kanıtını birbirine bağlayan bir teknik anlatım da üretilecektir. Sonradan geriye dönük hikâye yazılmaması için her gate tamamlandığında aşağıdaki kayıt tutulur:

1. **Fiziksel soru/hipotez:** Hangi hareket, coupling, limit veya belirsizlik incelendi?
2. **Koordinat ve işaretler:** Body/NED frame, state/input/output, birim ve pozitif yönler.
3. **Temel denklem:** Kullanılan nonlinear denklem veya geometrik ilişki.
4. **Varsayımlar:** Küçük açı, trim çevresi, sabit hız, quasi-steady, ihmal edilen coupling vb.
5. **Türeyiş:** Controller, feedforward, estimator veya metriğin denklemden nasıl çıktığı.
6. **Parametreler:** Değer, birim, kaynak ve belirsizlik; ölçülen ile varsayılan açıkça ayrılır.
7. **Tasarım gerekçesi:** Bu yöntem neden seçildi; daha karmaşık alternatif neden henüz seçilmedi?
8. **Deney tasarımı:** Input, operating point, pencere, seed/tekrar ve PASS/FAIL kapısı.
9. **Sonucun matematiksel yorumu:** Sonuç hangi katsayıyı, kutup/sıfırı, authority'yi, bandwidth'i, feasibility sınırını veya model hatasını gösteriyor?
10. **İzlenebilirlik:** İlgili kod, rapor, MAT/log ve grafik yolları.

Her Cursor görevinin bitiş feedback'inde en az şu blok zorunludur:

`MATHEMATICAL_RECORD = {equations, variables_units_frames, assumptions, parameter_provenance, design_reason, rejected_alternatives, evidence, conclusion, open_questions}`

Kurallar:

- Denklemle **türetilen**, deneyle **identify edilen** ve yalnızca **tune edilen** değerler birbirine karıştırılmaz.
- Correlation, causation veya model validity diye sunulmaz.
- Tek senaryo başarısı genel fizik hükmüne çevrilmez.
- Controller'ın kullandığı yaklaşık model ile truth plant denklemleri ayrı anlatılır.
- Başarısız denemeler de neden başarısız olduklarıyla korunur; yalnız başarılı son ayar yazılmaz.

Nihai öğretici anlatımın sırası:

1. Body/NED frame, Euler/quaternion kinematiği ve 6-DOF state.
2. `Mν̇ + C(ν)ν + D(ν)ν + g(η) = τ` dinamiğinin terim terim fiziksel anlamı.
3. Added mass, hydrodynamic damping, buoyancy, CG/CB ve restoring momentler.
4. Propeller, rudder/elevator, servo limitleri ve control allocation.
5. Trim, equilibrium, linearization, poles/zeros ve system identification.
6. Rate/attitude cascade, PID, feedforward, filtering, anti-windup ve gain scheduling.
7. LOS/path geometry, Frenet/radial CTE, curvature ve yaw/pitch reference üretimi.
8. Sensör hata modelleri ve EKF/UKF/factor-graph navigation mantığı.
9. Speed, depth/altitude, 3-D GNC, fault detection ve degraded control.
10. Perception, mapping/SLAM, planning ve mission state machine.
11. Belirsizlik, Monte Carlo, robustness ve olasılıksal “kusursuza yakın” kabulü.
12. MIL/SIL/PIL/HIL, tank/su testi ve gerçek logla sayısal ikiz korelasyonu.

**Nihai amaç:** Kullanıcı yalnız modeli çalıştırabilen değil; her ana denklemi, tasarım kararını, geçerlilik sınırını ve doğrulama basamağını genel hatlarıyla açıklayabilen seviyeye gelecektir.
