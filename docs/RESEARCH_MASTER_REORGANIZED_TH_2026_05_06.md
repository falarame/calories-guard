# งานวิจัยและหลักฐานที่รองรับ Calories Guard ฉบับจัดเรียงใหม่

**วันที่:** 6 พฤษภาคม 2569  
**วัตถุประสงค์:** ใช้เป็นเอกสารหลักสำหรับอธิบายกับกรรมการ/อาจารย์/ทีมพัฒนา ว่า Calories Guard ใช้งานวิจัยอะไร ทำไมเลือกงานนั้น งานวิจัยทำอะไร ใช้สูตรหรือ matrix อะไร และนำมาแปลงเป็น requirement ของแอพอย่างไร

## 1. ภาพรวมว่าเอกสารนี้จัดลำดับอย่างไร

เอกสารนี้จัดจาก “ฐานของระบบ” ไปสู่ “ความปลอดภัยและข้อจำกัด”:

1. หลักฐานว่าทำไมต้องมี food logging และ self-monitoring
2. สูตรประเมินร่างกาย: BMI, waist, body composition, BMR/REE, TDEE/EER
3. เป้าหมายผู้ใช้: ลดน้ำหนัก เพิ่มกล้าม รักษาน้ำหนัก รักษากล้าม
4. โภชนาการ: calorie, macro, protein, water, sodium, sugar, fiber, micronutrients
5. ฐานข้อมูลอาหาร: ThaiFCD, ingredients, units, recipe, portion estimation
6. กลุ่มผู้ใช้พิเศษ: เด็ก วัยรุ่น ตั้งครรภ์ ให้นม โรคเบาหวาน CKD
7. ความปลอดภัย: eating-disorder safety, food allergy, AI safety, privacy/security
8. UX: gamification, notification, accessibility, health literacy
9. QA และ requirement matrix

หลักการสำคัญ:

> งานวิจัยไม่ได้พิสูจน์ว่า Calories Guard ทำให้ผู้ใช้สุขภาพดีขึ้น 100% แต่ช่วยยืนยันว่า feature, formula, guardrail และ QA ของแอพถูกออกแบบตามหลักฐานที่เชื่อถือได้

---

## 2. Evidence Map แบบย่อ

| หมวด | งานวิจัย/มาตรฐานหลัก | ใช้กับแอพตรงไหน |
|---|---|---|
| Food logging | Burke, Patel, mobile health app reviews | food log, dashboard, adherence |
| BMR/REE | Mifflin-St Jeor, Frankenfield validation | BMR formula, backend source of truth |
| TDEE/EER | FAO/WHO/UNU, National Academies/IOM | activity factor, TDEE, calorie target |
| BMI/waist | WHO, CDC, WHO Asian BMI, NICE, NHLBI | BMI category, Asian risk note, waist warning |
| Muscle gain/maintenance | ISSN, Morton, Helms, ACSM, ESPEN | protein target, surplus, preserve muscle |
| Pregnancy/lactation | CDC, IOM gestational gain, NICHD | clinical exclusion, pregnancy mode warning |
| Child/adolescent | CDC BMI-for-age, WHO growth standards | age gate, no adult BMI for <20 |
| Diabetes/CKD | ADA Standards of Care, KDIGO/NKF/NIDDK | no medical nutrition therapy by AI/app |
| Sodium/sugar/fiber | WHO, CDC, National Academies DRI, DGA | quality dashboard beyond kcal |
| Food allergy | FDA Big 9, FAO/WHO Codex allergens | allergen flags, recipe safety |
| Thai diet | FAO Thailand FBDG, Nutrition Flag, ThaiFCD | Thai food guide, Thai source priority |
| Portion estimation | dietary assessment reviews, image-based reviews | AI estimate label, grams/serving edit |
| AI safety | WHO AI, NIST AI RMF, LLM nutrition studies | scope guard, kill switch, no diagnosis |
| Security/privacy | OWASP MASVS, PDPA/GDPR/EDPB | auth, consent, no secret in client |
| Accessibility | WCAG, AHRQ health literacy | plain Thai, text summaries |

---

## 3. Food Logging และ Self-Monitoring

### 3.1 งานวิจัยคืออะไร

งานของ Burke et al. และ Patel et al. เป็น systematic reviews ที่ศึกษาว่า “การติดตามพฤติกรรมของตัวเอง” เช่น จดอาหาร จดน้ำหนัก และดู feedback ส่งผลต่อการควบคุมน้ำหนักหรือพฤติกรรมโภชนาการหรือไม่

### 3.2 เขาวิจัยไปทำไม

เพราะการบันทึกอาหารเป็น feature หลักของแอพโภชนาการ แต่ถ้าไม่มีหลักฐานรองรับ ก็อาจเป็นเพียงการเก็บข้อมูลที่เพิ่มภาระให้ผู้ใช้ งานวิจัยกลุ่มนี้จึงดูว่า self-monitoring มีประโยชน์จริงไหม และเงื่อนไขอะไรทำให้ผู้ใช้ทำต่อเนื่อง

### 3.3 เขาทำอย่างไร

ใช้ systematic review matrix:

| มิติที่ศึกษา | ตัวอย่าง |
|---|---|
| intervention | food diary, web/app logging, daily weighing |
| frequency | จดทุกวันหรือบางวัน |
| feedback | มี dashboard/coach feedback หรือไม่ |
| outcome | weight change, adherence, diet quality |
| burden | ใช้ยากไหม เลิกใช้เร็วไหม |

### 3.4 สรุปผล

การ self-monitoring มีแนวโน้มสัมพันธ์กับผลลัพธ์ที่ดีขึ้น โดยเฉพาะเมื่อทำอย่างสม่ำเสมอ แต่ adherence จะลดลงถ้าการบันทึกยุ่งยากหรือใช้เวลามาก

### 3.5 ใช้กับ Calories Guard

Requirement:

- food log ต้องเร็ว แก้ไขได้ และเลือกวันที่ได้ถูกต้อง
- dashboard ต้องให้ feedback ที่ผู้ใช้เข้าใจ
- ข้อมูล estimated ต้องมี label
- missing log ต้องแสดงแบบไม่กล่าวโทษ
- food history ต้องค้นหา/แก้ไขย้อนหลังได้

แหล่งอ้างอิง:

- Burke et al. Self-Monitoring in Weight Loss: https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/
- Patel et al. Dietary self-monitoring review: https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/
- Mobile Apps for Health Behavior Change: https://mhealth.jmir.org/2020/3/e17046/

---

## 4. BMI, Waist, Body Fat และ Body Composition

### 4.1 BMI คืออะไร

BMI หรือ Body Mass Index เป็นตัวคัดกรองว่าน้ำหนักสัมพันธ์กับส่วนสูงอย่างไร

สูตร:

```text
BMI = weight_kg / (height_m ^ 2)
```

ตัวอย่าง:

```text
weight = 70 kg
height = 175 cm = 1.75 m
BMI = 70 / (1.75^2) = 22.86 kg/m²
```

### 4.2 เขาวิจัย/กำหนด BMI ไปทำไม

WHO, CDC และหน่วยงานสาธารณสุขใช้ BMI เพราะ:

- คำนวณง่าย
- ใช้กับประชากรจำนวนมากได้
- สัมพันธ์กับความเสี่ยงโรคในระดับประชากร
- ใช้คัดกรอง ไม่ใช่วินิจฉัย

### 4.3 BMI category ทั่วไป

| BMI | ความหมาย |
|---|---|
| < 18.5 | Underweight |
| 18.5-24.9 | Normal / healthy range |
| 25.0-29.9 | Overweight |
| >= 30.0 | Obesity |

ตัวเลขเหล่านี้เป็น public-health cut-off จาก WHO/CDC ไม่ใช่สูตรเฉพาะรายบุคคล

### 4.4 Asian BMI action points

WHO Expert Consultation พบว่าประชากรเอเชียบางกลุ่มมีความเสี่ยง cardiometabolic เพิ่มที่ BMI ต่ำกว่า 25 จึงเสนอ action points:

| BMI | ความหมายเชิง action |
|---|---|
| >= 23.0 | เริ่มมีความเสี่ยงเพิ่ม ควรติดตาม/ให้คำแนะนำ |
| >= 27.5 | ความเสี่ยงสูงขึ้นชัดเจน ควรประเมินจริงจังขึ้น |

สำหรับผู้ใช้ไทย แอพควรมี Asian note ไม่ควรรอเตือนเฉพาะ BMI 25/30 เท่านั้น

### 4.5 Waist circumference และ waist-to-height ratio

BMI ไม่บอกตำแหน่งไขมัน และไม่แยกไขมันกับกล้ามเนื้อ จึงควรใช้ร่วมกับ waist circumference หรือ waist-to-height ratio

สูตร waist-to-height ratio:

```text
WHtR = waist_cm / height_cm
```

NICE แนะนำแนวคิด practical ว่า waist ควรน้อยกว่าครึ่งหนึ่งของส่วนสูง:

```text
WHtR < 0.5
```

NICE แบ่งความเสี่ยงโดยประมาณ:

| WHtR | ความหมาย |
|---|---|
| < 0.5 | lower central adiposity risk |
| 0.5-0.59 | increased central adiposity risk |
| >= 0.6 | high central adiposity risk |

### 4.6 Body fat / body composition

Body composition หมายถึงองค์ประกอบร่างกาย เช่น:

- fat mass
- lean mass
- skeletal muscle
- water
- bone

วิธีวัดมีหลายแบบ:

| วิธี | ความแม่น/ข้อจำกัด |
|---|---|
| DEXA | แม่นกว่า แต่ไม่เหมาะกับแอพทั่วไป |
| BIA scale | สะดวก แต่คลาดเคลื่อนจาก hydration/เวลา/เครื่อง |
| Skinfold | ต้องใช้ผู้วัดที่ชำนาญ |
| Waist/WHtR | ง่าย ใช้ประเมิน central adiposity |
| BMI | ง่ายที่สุด แต่แยกกล้ามกับไขมันไม่ได้ |

### 4.7 ใช้กับ Calories Guard

Requirement:

- แสดง BMI เป็น screening ไม่ใช่ diagnosis
- เพิ่ม Asian risk note สำหรับผู้ใช้ไทย
- เพิ่ม optional `waist_cm`
- หากมี body fat % ให้เก็บ source เช่น user input, BIA, DEXA
- ไม่ควรบอกว่า “อันตรายแน่นอน” แต่ใช้คำว่า “อาจมีความเสี่ยงเพิ่ม”
- นักกีฬา/ผู้มีกล้ามมากต้องมี limitation note

QA:

| Case | Expected |
|---|---|
| 70 kg, 175 cm | BMI 22.86 |
| BMI 23 Asian mode | show increased-risk note |
| WHtR 0.52 | increased central adiposity risk |
| athlete mode | show BMI limitation |

แหล่งอ้างอิง:

- WHO Obesity and overweight: https://www.who.int/en/news-room/fact-sheets/detail/obesity-and-overweight
- CDC BMI FAQ: https://www.cdc.gov/bmi/faq/index.html
- WHO Asian BMI consultation: https://pubmed.ncbi.nlm.nih.gov/14726171/
- NICE waist-to-height ratio guidance: https://www.nice.org.uk/guidance/ng246/chapter/Identifying-and-assessing-overweight-obesity-and-central-adiposity
- NHLBI BMI/waist risk: https://www.nhlbi.nih.gov/health/overweight-and-obesity/symptoms

---

## 5. BMR / REE: สูตร Mifflin-St Jeor

### 5.1 REE กับ BMR เหมือนกันไหม

ไม่เหมือน 100%:

| คำ | ความหมาย |
|---|---|
| BMR | พลังงานพื้นฐานภายใต้เงื่อนไขวัดที่เข้มงวดมาก |
| REE/RMR | พลังงานตอนพัก เงื่อนไขผ่อนกว่าและใช้ในงานวิจัย/คลินิกบ่อยกว่า |

สูตร Mifflin-St Jeor สร้างมาเพื่อทำนาย REE/RMR แต่แอพทั่วไปมักเรียกว่า BMR เพื่อให้ผู้ใช้เข้าใจง่าย

คำแนะนำ UI:

```text
พลังงานพื้นฐานโดยประมาณ (BMR/REE)
```

### 5.2 งาน Mifflin ทำอะไร

Mifflin et al. วัด resting energy expenditure จริงด้วย indirect calorimetry ในผู้ใหญ่สุขภาพดี แล้วสร้าง regression equation จากน้ำหนัก ส่วนสูง อายุ และเพศ

### 5.3 ประเด็น Ideal Body Weight

งาน Mifflin ใช้ `%IBW` เพื่อจัดกลุ่มตัวอย่าง เช่น normal-weight/obese แต่สูตรสุดท้ายไม่ได้ใช้ IBW เป็น input หลัก

สูตรใช้:

- actual body weight
- height
- age
- sex

### 5.4 สูตร

```text
ชาย:
BMR = 10W + 6.25H - 5A + 5

หญิง:
BMR = 10W + 6.25H - 5A - 161
```

| ตัวแปร | ความหมาย |
|---|---|
| W | น้ำหนักจริง kg |
| H | ส่วนสูง cm |
| A | อายุ ปี |

### 5.5 ตัวเลขในสูตรมาจากอะไร

| เลข | ที่มา/ความหมาย |
|---|---|
| 10 | regression coefficient ของ weight |
| 6.25 | regression coefficient ของ height |
| -5 | regression coefficient ของ age |
| +5 / -161 | sex/intercept adjustment |

ตัวเลขนี้ไม่ใช่ค่าฟิสิกส์ตายตัว แต่เป็นค่าจาก regression ของ sample

### 5.6 ใช้กับ Calories Guard

Requirement:

- backend เป็น source of truth
- Flutter formula เป็น fallback/preview เท่านั้น
- เก็บ formula version
- แสดงว่าเป็น estimate
- ใช้ actual weight ไม่ใช้ IBW แทนในสูตรนี้

แหล่งอ้างอิง:

- Mifflin et al. DOI: https://doi.org/10.1093/ajcn/51.2.241
- Frankenfield validation: https://pubmed.ncbi.nlm.nih.gov/15883556/

---

## 6. TDEE / TEE / EER และ Activity Factor

### 6.1 TDEE คืออะไร

TDEE คือ Total Daily Energy Expenditure หรือพลังงานรวมที่ใช้ต่อวัน

ในงานวิชาการมักใช้คำว่า:

| คำ | ความหมาย |
|---|---|
| TEE | Total Energy Expenditure |
| TDEE | Total Daily Energy Expenditure |
| EER | Estimated Energy Requirement |
| PAL | Physical Activity Level |

### 6.2 งานวิจัยหลักคืออะไร

FAO/WHO/UNU Human Energy Requirements ใช้แนวคิด:

```text
PAL = TEE / BMR
TEE = BMR * PAL
```

ในแอพจึงเขียนเป็น:

```text
TDEE = BMR * activity_factor
```

National Academies/IOM ใช้ EER equations ที่สร้างจากข้อมูล energy expenditure เช่น doubly labeled water

### 6.3 TDEE ประกอบด้วยอะไร

```text
TDEE = BMR/REE + TEF + exercise activity + NEAT
```

| ส่วน | ความหมาย |
|---|---|
| BMR/REE | พลังงานพื้นฐาน |
| TEF | พลังงานที่ใช้ย่อยอาหาร |
| Exercise | พลังงานจากออกกำลังกาย |
| NEAT | เดิน ขยับตัว ทำงานบ้าน |

### 6.4 Activity factor

| Factor | ความหมาย practical |
|---|---|
| 1.2 | sedentary |
| 1.375 | lightly active |
| 1.55 | moderately active |
| 1.725 | very active |
| 1.9 | extra active |

ตัวเลขชุดนี้เป็น practical approximation จากแนวคิด PAL ไม่ใช่ค่าที่วัดเฉพาะบุคคล

### 6.5 EER equation อีกทางหนึ่ง

ตัวอย่าง IOM/National Academies:

```text
ผู้ชาย:
EER = 662 - (9.53 * age) + PA * [(15.91 * weight_kg) + (539.6 * height_m)]

ผู้หญิง:
EER = 354 - (6.91 * age) + PA * [(9.36 * weight_kg) + (726 * height_m)]
```

แอพอาจใช้วิธีนี้ในอนาคตได้ แต่ปัจจุบัน `BMR * activity_factor` อธิบายง่ายกว่า

### 6.6 ใช้กับ Calories Guard

Requirement:

- เก็บ `tdee_method`
- เก็บ `activity_factor`
- ถ้าใช้ Health Connect ต้องไม่ double-count active calories
- Flutter แสดง backend TDEE ก่อน

แหล่งอ้างอิง:

- FAO/WHO/UNU Human Energy Requirements: https://www.fao.org/4/y5686e/y5686e00.htm
- Adult/PAL chapter: https://www.fao.org/4/y5686e/y5686e07.htm
- National Academies EER: https://www.ncbi.nlm.nih.gov/sites/books/NBK591021/
- Health Canada EER equations: https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/equations-estimate-energy-requirement.html

---

## 7. Goal Modes: ลดน้ำหนัก เพิ่มกล้าม รักษาน้ำหนัก รักษากล้าม

### 7.1 ทำไมต้องแยก goal

ถ้าใช้ logic ลดน้ำหนักกับทุกคน จะผิดสำหรับผู้ใช้ที่ต้องการเพิ่มกล้ามหรือรักษาน้ำหนัก

| Goal | Calorie target | Protein target | Progress |
|---|---|---|---|
| ลดน้ำหนัก | TDEE - deficit | ปานกลางถึงสูง | weight trend ลง |
| เพิ่มกล้าม | TDEE + small surplus | สูง | weight ขึ้นช้า + training |
| รักษาน้ำหนัก | TDEE | ตาม activity/age | อยู่ใน range |
| ลดไขมันรักษากล้าม | TDEE - moderate deficit | สูง | weight/fat trend + protein adherence |
| Recomposition | TDEE หรือ deficit/surplus เล็ก | สูง | waist/strength/weight trend |
| ผู้สูงอายุรักษากล้าม | TDEE/clinician goal | 1.0-1.2+ g/kg | strength/function/weight trend |

### 7.2 ลดน้ำหนัก

แนวคิด:

```text
target_kcal = TDEE - deficit
```

Deficit ควร conservative เช่น 300-500 kcal/day สำหรับทั่วไป และต้องเตือนถ้ารุนแรงเกินไป

แหล่ง:

- CDC losing weight: https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
- ADA weight program criteria: https://diabetes.org/sites/default/files/2023-09/Weight%20Loss%20Program%20Criteria.pdf

### 7.3 เพิ่มกล้าม

หลักฐานจาก ISSN และ Morton สนับสนุน protein สูงกว่าคนทั่วไปเมื่อฝึก resistance training

สูตร:

```text
protein_target_g = body_weight_kg * protein_factor
```

| ค่า | ที่มา/ใช้กับ |
|---|---|
| 1.4-2.0 g/kg/day | ISSN สำหรับคนออกกำลังกาย |
| 1.6 g/kg/day | Morton meta-regression plateau |
| 2.2 g/kg/day | Morton upper confidence interval |

Surplus:

```text
target_kcal = TDEE + small_surplus
```

small surplus อาจเริ่มที่ 150-300 kcal/day หรือ 5-10% แล้วปรับจาก trend

ข้อสำคัญ: เพิ่มกล้ามต้องคู่กับ resistance training ไม่ใช่กินโปรตีนอย่างเดียว

แหล่ง:

- ISSN Protein and Exercise: https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8
- Morton meta-analysis: https://elementssystem.com/wp-content/uploads/2018/03/Morton-protein-review.pdf
- ACSM resistance training: https://www.acsm.org/wp-content/uploads/2025/01/Progression-Models-in-Resistance-Training-for-Healthy-Adults.pdf

### 7.4 รักษากล้ามระหว่างลดไขมัน

Helms et al. เสนอช่วง protein สูงใน lean resistance-trained athletes:

```text
protein_target = lean_body_mass_kg * 2.3 ถึง 3.1
```

โดย:

```text
lean_body_mass_kg = weight_kg * (1 - body_fat_percent / 100)
```

ใช้เฉพาะ advanced/athlete mode และต้อง label ชัด

แหล่ง:

- Helms bodybuilding review: https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/

### 7.5 รักษาน้ำหนัก

```text
target_kcal = TDEE
```

ควรใช้ trend/range ไม่ใช่ค่าวันเดียว

ตัวอย่าง product heuristic:

```text
range_low = target_weight * 0.98
range_high = target_weight * 1.02
```

ต้องบอกว่าเป็น “ช่วงติดตาม” ไม่ใช่เกณฑ์แพทย์

แหล่ง:

- Weight maintenance review: https://pmc.ncbi.nlm.nih.gov/articles/PMC9105823/
- Dietary strategies for maintenance: https://pmc.ncbi.nlm.nih.gov/articles/PMC6722715/
- NWCR habits: https://pmc.ncbi.nlm.nih.gov/articles/PMC4568993/

---

## 8. Macronutrients, Protein, Sodium, Sugar, Fiber และ Micronutrients

### 8.1 Macro calories 4/4/9 มาจากไหน

Atwater general factors:

```text
protein = 4 kcal/g
carbohydrate = 4 kcal/g
fat = 9 kcal/g
```

ข้อควรระวัง: database บางแห่งใช้ Atwater specific factors ทำให้ calories ไม่เท่ากับ macro sum พอดี

แหล่ง:

- FAO food energy conversion factors: https://www.fao.org/4/y5022e/y5022e04.htm

### 8.2 AMDR

National Academies DRI:

| Macro | Range |
|---|---|
| Carbohydrate | 45-65% energy |
| Fat | 20-35% energy |
| Protein | 10-35% energy |

ใช้เป็น default range สำหรับผู้ใหญ่ทั่วไป

แหล่ง:

- National Academies DRI: https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids

### 8.3 Sodium

WHO แนะนำ sodium น้อยกว่า 2,000 mg/day หรือเกลือประมาณน้อยกว่า 5 g/day ในผู้ใหญ่

CDC/Dietary Guidelines for Americans ใช้ <2,300 mg/day สำหรับ teens/adults

ใช้กับแอพ:

- เพิ่ม sodium dashboard ในอนาคต
- อาหารไทย/น้ำปลา/ซีอิ๊ว/ซุปควรระวัง sodium สูง
- ไม่ให้คำแนะนำรักษาความดันแทนแพทย์

แหล่ง:

- WHO salt reduction: https://www.who.int/news-room/fact-sheets/detail/salt-reduction
- CDC sodium: https://www.cdc.gov/salt/about/index.html

### 8.4 Sugar

WHO แนะนำ free sugars <10% ของ total energy และถ้าลดได้ถึง <5% จะมีประโยชน์เพิ่มเติม

สูตรในแอพ:

```text
sugar_limit_g = total_kcal * 0.10 / 4
```

ตัวอย่าง 2,000 kcal:

```text
2000 * 0.10 / 4 = 50 g/day
```

แหล่ง:

- WHO sugars guideline note: https://www.who.int/publications-detail-redirect/WHO-NMH-NHD-15.3
- NCBI WHO sugar recommendations: https://www.ncbi.nlm.nih.gov/books/NBK285525/

### 8.5 Fiber

National Academies ให้ Adequate Intake ประมาณ:

```text
14 g fiber / 1000 kcal
```

ตัวอย่าง 2,000 kcal:

```text
fiber_target = 14 * 2 = 28 g/day
```

ใช้กับแอพ:

- เพิ่ม fiber target
- แนะนำผัก ผลไม้ ธัญพืช ถั่ว
- บอกว่าเป็น general target

แหล่ง:

- National Academies fiber DRI: https://nap.nationalacademies.org/read/11537/chapter/11

### 8.6 Micronutrients

Micronutrients เช่น sodium, potassium, calcium, iron, vitamin D, folate มีความสำคัญ แต่ไม่ควรให้แอพทั่วไปแนะนำแบบรักษาโรค

ใช้กับแอพ:

- แสดง nutrient summary เมื่อมีข้อมูลจาก food database
- ถ้าข้อมูล missing ให้ label ว่า incomplete
- ไม่ควรสรุปว่าผู้ใช้ขาดวิตามินจาก food log อย่างเดียว

---

## 9. Water / Hydration

EFSA ใช้แนวคิด adequate intake ของ total water จากอาหารและเครื่องดื่ม ไม่ใช่กฎ 8 แก้วตายตัว

Requirement:

- water target ต้องแก้ไขได้
- บันทึกตาม selected date/timezone
- ไม่อ้างว่าน้ำรักษาโรค

แหล่ง:

- EFSA water DRV: https://www.efsa.europa.eu/en/efsajournal/pub/1459

---

## 10. Food Composition, ThaiFCD, Ingredients, Units, Recipes

### 10.1 ทำไมต้องมีฐานข้อมูลอาหารที่มี source

ข้อมูลโภชนาการไม่ใช่ค่าตายตัว อาหารดิบ/สุก/สูตร/แหล่งข้อมูลต่างกันให้ค่าต่างกัน FAO/INFOODS จึงเน้น source, unit, edible portion, retention/yield และ data checking

### 10.2 Recipe calculation

```text
nutrient_from_ingredient =
nutrient_per_100g * edible_grams_used / 100

recipe_total = sum(nutrient_from_each_ingredient)
per_serving = recipe_total / serving_count
```

ถ้ามีข้อมูล:

```text
adjusted_nutrient =
raw_nutrient * retention_factor * yield_factor
```

### 10.3 Data model requirement

- `ingredients` เป็น strong entity
- `units` แปลงเป็น grams/ml ได้
- `food_ingredient` เชื่อม dish/beverage/drink กับ ingredients
- `recipe_ingredients` เชื่อม recipes กับ ingredients
- `food_recipe` เชื่อม food/menu กับ recipe
- log ต้อง snapshot nutrient เพื่อไม่เปลี่ยนย้อนหลัง

### 10.4 ThaiFCD และ Thai dietary source

ThaiFCD เป็น source หลักของอาหารไทยจาก Institute of Nutrition, Mahidol University ตาม FAO listing

Fallback:

- ASEAN Food Composition Database
- USDA FoodData Central
- admin-reviewed estimate

แหล่ง:

- FAO/INFOODS standards: https://www.fao.org/infoods/infoods/standards-guidelines/en/
- FAO recipe/food composition: https://www.fao.org/4/y4705e/y4705e06.htm
- ThaiFCD FAO entry: https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en
- ASEAN Food Composition: https://inmu.mahidol.ac.th/aseanfoods/composition_data.html
- USDA FoodData Central: https://fdc.nal.usda.gov/api-guide

---

## 11. Thai Dietary Guidelines และ Nutrition Flag

### 11.1 แหล่งนี้คืออะไร

Thailand Food-Based Dietary Guidelines หรือ Nutrition Flag เป็นแนวทางการกินสำหรับคนไทย จัดทำโดยหน่วยงานไทยและถูกสรุปใน FAO country profile

### 11.2 หลักสำคัญ

FAO สรุปข้อความหลักของไทย เช่น:

- กินอาหารหลากหลายครบ 5 หมู่ และรักษาน้ำหนักเหมาะสม
- กินข้าว/แหล่งคาร์โบไฮเดรตพอเหมาะ
- กินผักและผลไม้เป็นประจำ
- กินปลา เนื้อไม่ติดมัน ไข่ ถั่ว และนมในปริมาณเหมาะสม
- กินไขมันให้พอเหมาะ
- หลีกเลี่ยงหวานและเค็ม
- กินอาหารสะอาดปลอดภัย
- ลด/หลีกเลี่ยงแอลกอฮอล์

### 11.3 ใช้กับ Calories Guard

- AI coach ภาษาไทยควรอิง nutrition flag ไม่ใช่ guideline ต่างประเทศอย่างเดียว
- dashboard ควรมี quality hints เช่น ผัก/ผลไม้ หวาน เค็ม ไขมัน
- ไม่ควรแนะนำ Thai diet แบบตะวันตกโดยไม่ปรับบริบท

แหล่ง:

- FAO Food-based dietary guidelines Thailand: https://www.fao.org/nutrition/education/dietary-guidelines/regions/thailand/en/
- Thai Nutrition Flag manual PDF: https://nutrition2.anamai.moph.go.th/web-upload/6x22caac0452648c8dd1f534819ba2f16c/m_magazine/31994/1018/file_download/0dd9c46e70cf03ae28b0ebb1bff3bbe4.pdf

---

## 12. Portion-Size Estimation

### 12.1 งานวิจัยนี้คืออะไร

งาน dietary assessment พบว่า portion size estimation เป็นหนึ่งในแหล่ง error ใหญ่ที่สุดของ food diary และ 24-hour recall

### 12.2 เขาวิจัยไปทำไม

แม้รู้ว่าอาหารคืออะไร ถ้าปริมาณผิด calorie และ nutrient ก็ผิดทันที

### 12.3 ใช้ metric อะไร

| Metric | ความหมาย |
|---|---|
| percent error | ค่าประมาณต่างจาก weighed food กี่ % |
| omission | ลืมบันทึกอาหาร |
| portion misestimation | ปริมาณผิด |
| food misclassification | ทายชนิดอาหารผิด |

### 12.4 ใช้กับ Calories Guard

Requirement:

- AI estimate ต้อง label ว่า estimated
- ผู้ใช้ต้องแก้ grams/serving ได้
- household measure ต้องแปลงเป็น gram/ml
- ควรมี common Thai portion defaults แต่ไม่ถือว่า exact
- ถ้าผู้ใช้ต้องการความแม่น แนะนำใช้ food scale

แหล่ง:

- PortionSize app validation: https://pmc.ncbi.nlm.nih.gov/articles/PMC9244674/
- Contributors to dietary assessment error: https://pubmed.ncbi.nlm.nih.gov/36041186/
- Image-based dietary assessment review: https://www.nature.com/articles/s41366-020-00693-2

---

## 13. Pregnancy / Lactation Boundary

### 13.1 ทำไมต้องแยก

การตั้งครรภ์และให้นมมี energy requirement, weight gain target และ nutrient needs ต่างจากผู้ใหญ่ทั่วไป สูตรลดน้ำหนักทั่วไปอาจไม่ปลอดภัย

### 13.2 Pregnancy

CDC ระบุโดยทั่วไป:

- trimester 1: มักไม่ต้องเพิ่ม calorie
- trimester 2: เพิ่มประมาณ 340 kcal/day
- trimester 3: เพิ่มประมาณ 450 kcal/day

IOM gestational weight gain ใช้ pre-pregnancy BMI:

| Pre-pregnancy BMI | Weight gain range |
|---|---|
| Underweight | 28-40 lb |
| Normal | 25-35 lb |
| Overweight | 15-25 lb |
| Obesity | 11-20 lb |

### 13.3 Lactation

NICHD ระบุว่าหลายคนไม่จำเป็นต้องนับเพิ่มแบบตายตัว และความต้องการขึ้นกับภาวะโภชนาการ รูปแบบการให้นม และสุขภาพ

### 13.4 ใช้กับ Calories Guard

Requirement:

- ถ้าผู้ใช้ตั้งครรภ์/ให้นม ห้ามใช้ weight-loss target ปกติแบบไม่เตือน
- AI ต้องไม่ให้คำแนะนำลดน้ำหนักช่วงตั้งครรภ์
- แนะนำปรึกษาแพทย์/นักกำหนดอาหาร
- อาจมี pregnancy/lactation exclusion flag

แหล่ง:

- CDC pregnancy weight gain: https://www.cdc.gov/maternal-infant-health/pregnancy-weight/index.html
- NIDDK pregnancy nutrition: https://www.niddk.nih.gov/health-information/weight-management/healthy-eating-physical-activity-for-life/health-tips-for-pregnant-women
- NICHD breastfeeding calories: https://www.nichd.nih.gov/health/topics/breastfeeding/conditioninfo/calories
- IOM pregnancy weight gain summary: https://pmc.ncbi.nlm.nih.gov/articles/PMC3974574/

---

## 14. Children / Adolescents Boundary

### 14.1 ทำไม adult formula ใช้ตรง ๆ ไม่ได้

เด็กและวัยรุ่นยังเติบโต:

- BMI ต้องใช้ age/sex percentile
- energy needs ต้องรวม growth
- weight-loss messaging ต้องระวังมาก

### 14.2 BMI-for-age

CDC:

| Percentile | Category |
|---|---|
| < 5th | Underweight |
| 5th to <85th | Healthy weight |
| 85th to <95th | Overweight |
| >=95th | Obesity |

### 14.3 ใช้กับ Calories Guard

Requirement:

- ถ้า age < 18 หรือ <20 ตาม standard ที่เลือก ห้ามใช้ adult BMI category โดยตรง
- ไม่ควรให้ calorie deficit recommendation สำหรับเด็ก/วัยรุ่น
- ต้องใช้ parent/guardian/clinician context หากรองรับจริง
- ในเวอร์ชันทั่วไปควร restrict scope เป็นผู้ใหญ่

แหล่ง:

- CDC Child and Teen BMI: https://www.cdc.gov/bmi/child-teen-calculator/bmi-categories.html
- WHO Child Growth Standards: https://www.who.int/tools/child-growth-standards/standards/p

---

## 15. Diabetes / CKD / Clinical Nutrition Boundary

### 15.1 ทำไมต้องมี boundary

ผู้ใช้ที่มีโรค เช่น diabetes หรือ chronic kidney disease ต้องการ medical nutrition therapy เฉพาะบุคคล แอพทั่วไปและ AI coach ไม่ควรแทนแพทย์หรือนักกำหนดอาหาร

### 15.2 Diabetes

ADA Standards of Care เป็น guideline สำหรับ clinicians และอัปเดตทุกปี ADA ระบุว่า nutrition therapy ต้อง individualized และอาจใช้ pattern หลายแบบ เช่น Mediterranean-style หรือ low-carbohydrate ตามความเหมาะสม

ใช้กับแอพ:

- AI ตอบได้แบบ general education
- ห้ามปรับยา/อินซูลิน
- ห้ามบอก carb target เฉพาะโรคแบบเด็ดขาดโดยไม่มี clinician
- ถ้าผู้ใช้บอกว่าเป็นเบาหวาน ให้ใช้ clinical boundary message

### 15.3 CKD

KDIGO/NKF/NIDDK ระบุว่าผู้ป่วย CKD บางกลุ่มต้องจำกัด protein เช่นราว 0.8 g/kg/day ใน non-dialysis CKD บาง stage แต่ dialysis อาจต้องการมากขึ้น

ใช้กับแอพ:

- protein high target สำหรับ muscle gain ต้องมี CKD warning
- ถ้าผู้ใช้บอกว่าโรคไต ห้ามเสนอ 1.6-2.2 g/kg แบบทั่วไป
- แนะนำปรึกษา clinician/dietitian

แหล่ง:

- ADA Standards of Care 2026: https://professional.diabetes.org/standards-of-care/practice-guidelines-resources
- ADA nutrition/wellness: https://professional.diabetes.org/clinical-support/nutrition-wellness
- NKF CKD protein: https://www.kidney.org/kidney-topics/ckd-diet-how-much-protein-right-amount
- NIDDK CKD nutrition: https://www.niddk.nih.gov/health-information/kidney-disease/chronic-kidney-disease-ckd/eating-nutrition
- KDIGO 2024 CKD guideline: https://kdigo.org/wp-content/uploads/2024/03/KDIGO-2024-CKD-Guideline.pdf

---

## 16. Eating Disorder / Disordered Eating Safety

### 16.1 ทำไมสำคัญ

Calorie tracking ช่วย self-monitoring ได้ แต่ในบางคนอาจสัมพันธ์กับ food preoccupation, all-or-none thinking, anxiety, compulsive exercise หรือ eating-disorder symptoms

### 16.2 งานวิจัยบอกอะไร

หลักฐานมีทั้งด้านบวกและความเสี่ยง:

- ในผู้ใหญ่ที่เข้าร่วม weight-loss treatment บางงานไม่พบ self-monitoring เพิ่ม disordered eating
- แต่งาน qualitative และ survey ในผู้ใช้ calorie-tracking apps พบว่าบางคนรู้สึกว่า app ทำให้หมกมุ่นกับ calorie, food anxiety หรือแข่งขันกับตัวเอง

### 16.3 ใช้กับ Calories Guard

Requirement:

- ใช้ภาษาสนับสนุน ไม่ shame
- streak ไม่ควรลงโทษ
- ไม่แสดงสี/ข้อความที่กดดันให้กินน้อยลงเรื่อย ๆ
- มี option พัก tracking
- ถ้าผู้ใช้บอกว่า eating disorder หรือกินน้อยมาก ให้ AI/referral boundary
- หลีกเลี่ยง “good/bad food” แบบตัดสิน

แหล่ง:

- Self-monitoring no adverse effect in obesity treatment: https://pmc.ncbi.nlm.nih.gov/articles/PMC6010018/
- Calorie tracking app and disordered eating motives: https://www.sciencedirect.com/science/article/pii/S1471015321000957
- Diet/fitness apps and eating disorder behaviors qualitative study: https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD
- Systematic review on diet/fitness app use and disordered eating: https://www.sciencedirect.com/science/article/pii/S174014452400158X

---

## 17. Food Allergy / Intolerance Safety

### 17.1 ทำไมสำคัญ

AI recipe, food suggestion หรือ recipe database อาจแนะนำอาหารที่ผู้ใช้แพ้ หากไม่มี allergen flag อาจเป็นความเสี่ยงจริง

### 17.2 Big 9 allergens

FDA major allergens:

1. milk
2. eggs
3. fish
4. Crustacean shellfish
5. tree nuts
6. peanuts
7. wheat
8. soybeans
9. sesame

### 17.3 ใช้กับ Calories Guard

Requirement:

- เพิ่ม allergen tags ใน ingredients/recipes
- ให้ผู้ใช้ตั้ง allergy/intolerance profile
- AI recipe ต้องเช็ก allergy ก่อนแนะนำ
- ถ้าข้อมูล allergen ไม่ครบ ต้องแสดง “allergen data incomplete”
- ห้าม guarantee ว่าปลอดภัย 100% ถ้าไม่ใช่ข้อมูลฉลาก/แหล่ง verified

แหล่ง:

- FDA Food Allergies: https://www.fda.gov/food/food-labeling-nutrition/food-allergies
- FAO food allergens: https://www.fao.org/food-safety/scientific-advice/food-allergens/en
- USDA FSIS Big 9: https://www.fsis.usda.gov/food-safety/safe-food-handling-and-preparation/food-safety-basics/food-allergies-big-9

---

## 18. AI Safety

### 18.1 ทำไม AI ต้องมี guardrail

AI อาจ hallucinate, ให้ medical advice เกิน scope, หรือทำให้ผู้ใช้เข้าใจผิดว่าเป็น clinician

### 18.2 Framework

WHO principles:

- autonomy
- safety
- transparency
- accountability
- inclusiveness

NIST AI RMF:

```text
Govern -> Map -> Measure -> Manage
```

### 18.3 ใช้กับ Calories Guard

Requirement:

- scope guard
- reject medical diagnosis
- AI estimate ต้อง confirm ก่อน save
- health endpoint
- kill switch `AI_ENABLED=false`
- log model/prompt version
- no secrets in response

แหล่ง:

- WHO AI for health: https://www.who.int/publications/i/item/9789240029200
- NIST AI RMF: https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10
- LLM nutrition study: https://pmc.ncbi.nlm.nih.gov/articles/PMC13026456/

---

## 19. Gamification, Notifications, Accessibility

### 19.1 Gamification

Evidence บอกว่า gamification อาจช่วย engagement แต่ไม่ควรอ้างว่าเพิ่ม health outcome แน่นอน

Requirement:

- badge/pet/streak เป็น supportive
- มี streak recovery
- ไม่มี shame copy
- ไม่ใช้ leaderboard ที่กดดันสุขภาพ

แหล่ง:

- Digital health gamification review: https://pmc.ncbi.nlm.nih.gov/articles/PMC11701442/
- Serious games diet/PA: https://pmc.ncbi.nlm.nih.gov/articles/PMC10056209/

### 19.2 Notifications

Just-in-time adaptive interventions มีศักยภาพ แต่ต้องควบคุม fatigue

Requirement:

- ตั้งเวลาได้
- ปิดได้
- ไม่ guilt-based
- ใช้ behavior context

แหล่ง:

- JITAI review: https://link.springer.com/article/10.1186/s12966-019-0792-7

### 19.3 Accessibility / Health literacy

Requirement:

- ภาษาไทยง่าย
- chart มี text summary
- contrast ชัด
- อธิบายคำว่า estimated, target, remaining

แหล่ง:

- WCAG 2.2: https://www.w3.org/TR/wcag/
- AHRQ Health Literacy Toolkit: https://www.ahrq.gov/health-literacy/improve/precautions/index.html

---

## 20. Privacy / Security

### 20.1 ข้อมูลสุขภาพเป็นข้อมูลอ่อนไหว

diet, weight, health integration, AI chat, allergies และ disease flags ควรถูกถือเป็น sensitive data

### 20.2 Requirement

- no Supabase service-role key in Flutter
- secrets อยู่ backend/Railway เท่านั้น
- consent สำหรับ Health Connect/AI
- export/delete path
- admin audit log
- secure storage
- TLS

แหล่ง:

- OWASP MASVS: https://mas.owasp.org/MASVS/
- EDPB data protection basics: https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en
- EDPB lawful processing: https://www.edpb.europa.eu/sme-data-protection-guide/process-personal-data-lawfully_en
- Thailand PDPC GPPC Plus: https://register-gppc-plus.pdpc.or.th/

---

## 21. Product Requirement Matrix

| Evidence | Requirement | Backend | Flutter/Admin | QA |
|---|---|---|---|---|
| Self-monitoring | logging เร็วและ editable | meal logs by selected date | quick add/edit | save yesterday log correctly |
| Mifflin | BMR estimate | formula/version | show estimated | formula unit test |
| FAO/IOM TDEE | TDEE method stored | `tdee_method`, factor | display backend value | no formula mismatch |
| WHO BMI/Asian | BMI category + Asian note | BMI fields | risk note | BMI 23 Asian warning |
| NICE waist | waist optional | `waist_cm`, WHtR | central risk note | WHtR 0.5 warning |
| ISSN/Morton | protein by goal | protein factor source | muscle goal target | 70kg -> 112g at 1.6 |
| Helms | advanced LBM protein | LBM formula | advanced label | no LBM without body fat |
| Pregnancy CDC/IOM | clinical boundary | pregnancy flag | warning/referral | no weight loss target |
| CDC child BMI | adult BMI disabled | age gate | no adult category | age <18 blocked |
| ADA/KDIGO | clinical disease boundary | disease flags | safe AI message | diabetes/CKD prompt refuses specific therapy |
| WHO sodium/sugar | quality nutrients | nutrient targets | sodium/sugar/fiber dashboard | sugar limit formula |
| FDA allergens | allergen tags | ingredient allergens | recipe warnings | allergy profile blocks suggestion |
| FAO/INFOODS | recipe from ingredients | unit conversion | admin source/version | log snapshot immutable |
| Portion research | AI estimate editable | confidence/source | edit grams/serving | AI cannot auto-save final |
| WHO/NIST AI | AI guardrails | health/kill switch | uncertainty labels | AI off returns 503 |
| OWASP/PDPA | security/privacy | auth/audit | consent/export/delete | no secrets in bundle |
| WCAG/AHRQ | accessible UI | text summary if needed | readable Thai | screen reader summary |

---

## 22. QA Test Suite Ideas

### Formula

- BMR male/female matches Mifflin.
- TDEE equals BMR * activity factor.
- Goal loss/gain/maintenance direction correct.
- Flutter shows backend value first.
- BMI/WHtR categories correct.

### Nutrition

- Macro 4/4/9 conversion correct.
- Sugar limit = kcal * 0.10 / 4.
- Fiber target = kcal / 1000 * 14.
- Sodium warning appears when over threshold.
- Protein target changes by goal mode.

### Food Database

- Unit conversion tbsp/tsp/cup/piece to grams works.
- Recipe total equals ingredient sum.
- Food edit does not mutate historical log.
- Source/version appears in admin.
- Missing nutrient flagged.

### Safety

- Pregnancy/child/CKD/diabetes prompts trigger boundary response.
- Allergy profile blocks risky recipes.
- Eating-disorder risk messages are supportive.
- AI estimate requires confirmation.
- Kill switch works.

### Privacy/Security/UX

- No service-role key in client.
- Account deletion/export path works.
- Chart has text summary.
- Notifications can be disabled.

---

## 23. สรุปสำหรับใช้พูดกับกรรมการ

> Calories Guard ใช้งานวิจัยหลายกลุ่มเพื่อรองรับระบบ ไม่ใช่พึ่งงานวิจัยชิ้นเดียว ได้แก่ self-monitoring สำหรับการบันทึกอาหาร, Mifflin และ FAO/IOM สำหรับการคำนวณพลังงาน, WHO/CDC/NICE สำหรับ BMI และ waist risk, ISSN/Morton/Helms สำหรับเพิ่มและรักษากล้าม, FAO/INFOODS/ThaiFCD สำหรับฐานข้อมูลอาหารและสูตรอาหาร, WHO/NIST สำหรับ AI safety, OWASP/PDPA สำหรับความปลอดภัยและความเป็นส่วนตัว และ WCAG/AHRQ สำหรับ accessibility และ health literacy หลักฐานเหล่านี้ถูกแปลงเป็น requirement, guardrail และ QA test เพื่อให้แอพปลอดภัย ถูกต้อง และตรวจสอบได้

สิ่งที่ควรพูดอย่างระมัดระวัง:

- แอพเป็น nutrition self-monitoring และ behavior-support app
- สูตรทั้งหมดเป็น estimate
- AI เป็นผู้ช่วย ไม่ใช่แพทย์
- ผู้ใช้กลุ่มพิเศษควรปรึกษาผู้เชี่ยวชาญ
- ต้องทำ internal validation กับผู้ใช้จริงต่อไป

---

## 24. Reference List

1. Burke et al. Self-Monitoring in Weight Loss. https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/
2. Patel et al. Dietary self-monitoring review. https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/
3. Mobile Apps for Health Behavior Change. https://mhealth.jmir.org/2020/3/e17046/
4. WHO Obesity and overweight. https://www.who.int/en/news-room/fact-sheets/detail/obesity-and-overweight
5. CDC BMI FAQ. https://www.cdc.gov/bmi/faq/index.html
6. WHO Asian BMI consultation. https://pubmed.ncbi.nlm.nih.gov/14726171/
7. NICE waist-to-height ratio guidance. https://www.nice.org.uk/guidance/ng246/chapter/Identifying-and-assessing-overweight-obesity-and-central-adiposity
8. NHLBI overweight/obesity diagnosis. https://www.nhlbi.nih.gov/health/overweight-and-obesity/symptoms
9. Mifflin-St Jeor equation. https://doi.org/10.1093/ajcn/51.2.241
10. Frankenfield RMR equation validation. https://pubmed.ncbi.nlm.nih.gov/15883556/
11. FAO/WHO/UNU Human Energy Requirements. https://www.fao.org/4/y5686e/y5686e00.htm
12. FAO adults/PAL chapter. https://www.fao.org/4/y5686e/y5686e07.htm
13. National Academies EER. https://www.ncbi.nlm.nih.gov/sites/books/NBK591021/
14. CDC losing weight. https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
15. ISSN Protein and Exercise. https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8
16. Morton protein meta-analysis. https://elementssystem.com/wp-content/uploads/2018/03/Morton-protein-review.pdf
17. Helms bodybuilding nutrition. https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/
18. ACSM resistance training. https://www.acsm.org/wp-content/uploads/2025/01/Progression-Models-in-Resistance-Training-for-Healthy-Adults.pdf
19. ESPEN older adult protein. https://www.sciencedirect.com/science/article/pii/S0261561414001113
20. National Academies DRI macro/fiber. https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids
21. FAO Atwater conversion factors. https://www.fao.org/4/y5022e/y5022e04.htm
22. WHO salt reduction. https://www.who.int/news-room/fact-sheets/detail/salt-reduction
23. WHO sugar guideline. https://www.who.int/publications-detail-redirect/WHO-NMH-NHD-15.3
24. EFSA water DRV. https://www.efsa.europa.eu/en/efsajournal/pub/1459
25. FAO/INFOODS standards. https://www.fao.org/infoods/infoods/standards-guidelines/en/
26. FAO food composition and recipes. https://www.fao.org/4/y4705e/y4705e06.htm
27. ThaiFCD FAO entry. https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en
28. ASEAN Food Composition Database. https://inmu.mahidol.ac.th/aseanfoods/composition_data.html
29. USDA FoodData Central. https://fdc.nal.usda.gov/api-guide
30. FAO Thailand food-based dietary guidelines. https://www.fao.org/nutrition/education/dietary-guidelines/regions/thailand/en/
31. PortionSize app validation. https://pmc.ncbi.nlm.nih.gov/articles/PMC9244674/
32. Dietary assessment error review. https://pubmed.ncbi.nlm.nih.gov/36041186/
33. Image-based dietary assessment review. https://www.nature.com/articles/s41366-020-00693-2
34. CDC pregnancy weight gain. https://www.cdc.gov/maternal-infant-health/pregnancy-weight/index.html
35. NICHD breastfeeding calories. https://www.nichd.nih.gov/health/topics/breastfeeding/conditioninfo/calories
36. CDC child/teen BMI. https://www.cdc.gov/bmi/child-teen-calculator/bmi-categories.html
37. WHO child growth standards. https://www.who.int/tools/child-growth-standards/standards/p
38. ADA Standards of Care. https://professional.diabetes.org/standards-of-care/practice-guidelines-resources
39. NKF CKD protein. https://www.kidney.org/kidney-topics/ckd-diet-how-much-protein-right-amount
40. Eating disorder self-monitoring safety. https://pmc.ncbi.nlm.nih.gov/articles/PMC6010018/
41. Diet/fitness apps and eating disorder behaviors. https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD
42. FDA Food Allergies. https://www.fda.gov/food/food-labeling-nutrition/food-allergies
43. FAO food allergens. https://www.fao.org/food-safety/scientific-advice/food-allergens/en
44. WHO AI for health. https://www.who.int/publications/i/item/9789240029200
45. NIST AI RMF. https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10
46. OWASP MASVS. https://mas.owasp.org/MASVS/
47. EDPB data protection basics. https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en
48. WCAG 2.2. https://www.w3.org/TR/wcag/
49. AHRQ Health Literacy Toolkit. https://www.ahrq.gov/health-literacy/improve/precautions/index.html

