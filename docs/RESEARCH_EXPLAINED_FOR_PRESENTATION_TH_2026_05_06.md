# อธิบายงานวิจัยแบบเข้าใจง่ายสำหรับ Calories Guard

**วันที่:** 6 พฤษภาคม 2569  
**วัตถุประสงค์ของไฟล์นี้:** อธิบายว่า “งานวิจัยแต่ละชิ้นคืออะไร เขาวิจัยไปทำไม เขาทำอย่างไร ใช้สูตร/กรอบ/เมทริกซ์อะไร และ Calories Guard เอามาใช้ตรงไหน”

ไฟล์นี้เขียนสำหรับใช้ตอบอาจารย์/กรรมการ/ผู้รีวิว ที่อาจถามว่า:

- ทำไมแอพต้องให้ผู้ใช้บันทึกอาหาร
- ทำไมใช้สูตร Mifflin-St Jeor
- ทำไมต้องมี food version/snapshot
- ทำไม AI ต้องมี guardrail
- ทำไม gamification ต้องออกแบบแบบไม่ลงโทษผู้ใช้
- ทำไมต้องมี privacy/security/accessibility

## 1. วิธีอ่านเอกสารนี้

งานวิจัยที่เราใช้ไม่ได้มีชิ้นเดียวที่บอกว่า “Calories Guard ทั้งแอพถูกต้อง” แต่เป็นงานวิจัยหลายกลุ่มที่รองรับองค์ประกอบของแอพ เช่น:

| กลุ่มงานวิจัย | รองรับส่วนไหนของ Calories Guard |
|---|---|
| Self-monitoring | food log, weight log, dashboard |
| Energy equation | BMR, TDEE, calorie goal |
| Dietary reference | macro target, water target |
| Food composition | ingredients, units, recipes, ThaiFCD |
| Behavior change | reminders, goal feedback, streak |
| Gamification | badges, missions, pet progression |
| AI safety | AI coach, meal estimate, hallucination guard |
| Wearable validation | Health Connect, steps, active calories |
| Privacy/security | auth, consent, data deletion, no secret leak |
| Accessibility/health literacy | Thai UI, charts, readable nutrition feedback |

ดังนั้นงานวิจัยทำหน้าที่เหมือน “ฐานรองรับ requirement” ไม่ใช่แค่รายการอ้างอิงท้ายเล่ม

---

## 2. Burke et al. - Self-Monitoring in Weight Loss

**ชื่ออ้างอิง:** Self-Monitoring in Weight Loss: A Systematic Review of the Literature  
**ลิงก์:** https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/

### งานวิจัยนี้คืออะไร

งานนี้เป็น systematic review ที่รวบรวมงานวิจัยเกี่ยวกับการ self-monitoring หรือการติดตามพฤติกรรมของตัวเอง เช่น:

- จดอาหารที่กิน
- จดน้ำหนัก
- จดกิจกรรมทางกาย
- ติดตามเป้าหมายการลดน้ำหนัก

### เขาวิจัยไปทำไม

เขาต้องการตอบคำถามว่า:

> คนที่ติดตามอาหาร น้ำหนัก หรือกิจกรรมของตัวเอง มีแนวโน้มควบคุมน้ำหนักได้ดีขึ้นจริงไหม

เหตุผลคือในโปรแกรมลดน้ำหนัก การ self-monitoring เป็นพฤติกรรมหลักที่มักถูกใช้ แต่ต้องพิสูจน์ว่าไม่ใช่แค่ความเชื่อ

### เขาทำอย่างไร

งานนี้ไม่ได้ทดลองเอง แต่รวบรวมและวิเคราะห์งานวิจัยก่อนหน้า โดยดูว่าแต่ละงาน:

- ใช้ self-monitoring แบบใด
- ผู้เข้าร่วมจดบ่อยแค่ไหน
- ติดตามนานแค่ไหน
- ผลลัพธ์น้ำหนักเป็นอย่างไร
- adherence หรือความต่อเนื่องของการจดเป็นอย่างไร

### ใช้สูตรหรือ matrix อะไร

งานนี้ใช้แนวทาง systematic review:

```text
Research question -> Search studies -> Screen studies -> Extract evidence -> Compare findings
```

ไม่ได้ใช้สูตรคำนวณแบบ BMR แต่ใช้ evidence extraction matrix เช่น:

| ตัวแปรที่ดู | ความหมาย |
|---|---|
| intervention | วิธี self-monitoring ที่ใช้ |
| frequency | ความถี่ในการบันทึก |
| duration | ระยะเวลาติดตาม |
| outcome | น้ำหนัก/พฤติกรรม/การคงอยู่ |
| adherence | ผู้ใช้ทำต่อเนื่องแค่ไหน |

### ผลวิจัยสรุปว่าอะไร

โดยรวมพบว่า self-monitoring มีความสัมพันธ์กับผลลัพธ์การลดน้ำหนักที่ดีขึ้น โดยเฉพาะเมื่อผู้ใช้จดต่อเนื่อง แต่ปัญหาคือถ้าการจดยุ่งยาก ผู้ใช้จะเลิกทำ

### Calories Guard เอามาใช้ยังไง

ใช้รองรับฟีเจอร์:

- food logging
- weight logging
- daily dashboard
- progress summary

ข้อกำหนดที่ได้:

- การบันทึกต้องเร็ว
- แก้ไขย้อนหลังได้
- เลือกวันที่ได้ถูกต้อง
- dashboard ต้องทำให้ผู้ใช้เห็นผลจากการติดตามตัวเอง
- ห้ามทำให้การ logging หนักเกินไปจนผู้ใช้เลิกใช้

---

## 3. Patel et al. - Dietary Self-Monitoring in Behavioral Weight Loss

**ลิงก์:** https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/

### งานวิจัยนี้คืออะไร

เป็น systematic review ที่โฟกัสเฉพาะ “การติดตามอาหาร” ในโปรแกรมลดน้ำหนักเชิงพฤติกรรม

### เขาวิจัยไปทำไม

เขาต้องการรู้ว่า:

- การจดอาหารช่วยลดน้ำหนักหรือไม่
- ต้องจดถี่แค่ไหนถึงมีผล
- วิธีส่ง feedback หรือรูปแบบ digital ช่วยได้ไหม

### เขาทำอย่างไร

เขารวบรวมงานวิจัยที่ใช้ dietary self-monitoring แล้วดู:

- วิธีบันทึกอาหาร
- ความเข้มข้นของการติดตาม
- feedback ที่ผู้ใช้ได้รับ
- ผลลัพธ์น้ำหนัก
- adherence ต่อการบันทึก

### ใช้ formula/matrix อะไร

ใช้ evidence matrix ประเภท:

| มิติ | ตัวอย่าง |
|---|---|
| delivery mode | paper diary, web, mobile app |
| intensity | จดทุกวัน/บางวัน |
| feedback | มี feedback หรือไม่มี |
| outcome | น้ำหนัก, adherence, diet quality |

### ผลวิจัยสรุปว่าอะไร

การจดอาหารอย่างต่อเนื่องและการได้รับ feedback มีแนวโน้มช่วยเพิ่มผลลัพธ์การควบคุมน้ำหนัก

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- หน้า dashboard แคลอรีวันนี้
- progress bar
- macro summary
- meal history
- reminder ให้บันทึกอาหาร

ข้อกำหนด:

- ต้องบอกผู้ใช้ว่าวันนี้บันทึกครบหรือยัง
- ถ้าเป็นค่าประมาณ ต้อง label ว่า estimated
- feedback ต้องช่วยให้ผู้ใช้ตัดสินใจ ไม่ใช่แค่แสดงตัวเลข

---

## 4. Mifflin et al. - สูตร Mifflin-St Jeor สำหรับ BMR/REE

**ชื่อ:** A New Predictive Equation for Resting Energy Expenditure in Healthy Individuals  
**ลิงก์ DOI:** https://doi.org/10.1093/ajcn/51.2.241  
**สำเนาอ่านได้:** https://studylib.net/doc/28162558/mifflin1990

### งานวิจัยนี้คืออะไร

งานนี้เป็นงานวิจัยต้นฉบับที่สร้างสมการทำนาย Resting Energy Expenditure หรือ REE ซึ่งใกล้เคียงกับแนวคิด BMR ที่แอพใช้สำหรับคำนวณพลังงานพื้นฐานของร่างกาย

### เขาวิจัยไปทำไม

ก่อนหน้านี้มีสูตรเก่าอย่าง Harris-Benedict แต่ประชากรยุคใหม่มีน้ำหนัก รูปร่าง และองค์ประกอบร่างกายต่างจากอดีต นักวิจัยจึงต้องการสร้างสูตรใหม่ที่เหมาะกับผู้ใหญ่ทั่วไปมากขึ้น

คำถามหลักคือ:

> ถ้าเราไม่มีเครื่องวัด metabolic rate จริง จะใช้ข้อมูลพื้นฐาน เช่น น้ำหนัก ส่วนสูง อายุ เพศ เพื่อทำนาย REE ได้แม่นแค่ไหน

### เขาทำอย่างไร

งานนี้ใช้ข้อมูลจากผู้ใหญ่สุขภาพดี 498 คน แบ่งเป็นชายและหญิง มีทั้งกลุ่ม normal-weight และ obese อายุประมาณ 19-78 ปี

เขาวัด REE จริงด้วย indirect calorimetry ซึ่งถือเป็นวิธีมาตรฐานในการวัดพลังงานขณะพัก โดยให้ผู้เข้าร่วม:

- งดอาหารก่อนวัด
- งดออกกำลังกายก่อนวัด
- อยู่ในท่าพัก
- วัดการใช้ oxygen และ carbon dioxide ผ่านเครื่องมือ

จากนั้นนำข้อมูลมาสร้างสมการด้วย regression

### ประเด็น Ideal Body Weight ในงานนี้

งานนี้มีการใช้ **%IBW หรือ percent of Ideal Body Weight** เพื่อช่วยจัดกลุ่มตัวอย่าง เช่น:

- normal-weight ประมาณ 80 ถึงน้อยกว่า 120% IBW
- obese ประมาณ 120% IBW ขึ้นไป
- พยายาม exclude คนที่ underweight มากหรือ morbidly obese มาก

แต่จุดสำคัญคือ:

> IBW ถูกใช้เพื่อคัดและจัดกลุ่ม sample ในงานวิจัย ไม่ใช่ input หลักของสูตร Mifflin-St Jeor ที่แอพใช้

สูตรสุดท้ายที่ใช้ทั่วไปใช้:

- actual body weight
- height
- age
- sex

ไม่ใช่ Ideal Body Weight

### ใช้สูตรหรือ matrix อะไร

ใช้ regression model เพื่อหาความสัมพันธ์ระหว่าง measured REE กับตัวแปรของร่างกาย

ตัวแปรที่พิจารณา:

| ตัวแปร | ใช้ทำอะไร |
|---|---|
| weight | predictor หลักของ REE |
| height | predictor เพิ่มความแม่น |
| age | REE ลดลงตามอายุ |
| sex | เพศมีผลต่อ REE |
| fat-free mass | มีความสัมพันธ์กับ REE แต่ใช้งานจริงยากกว่า |
| BMI / IBW group | ใช้จัดกลุ่มและอธิบาย population |

สูตรที่ใช้ในแอพทั่วไปคือ:

```text
ชาย:
BMR = 10W + 6.25H - 5A + 5

หญิง:
BMR = 10W + 6.25H - 5A - 161

W = actual body weight in kg
H = height in cm
A = age in years
```

อีกวิธีเขียนคือ:

```text
REE = 9.99W + 6.25H - 4.92A + 166S - 161

S = 1 สำหรับชาย
S = 0 สำหรับหญิง
```

### ผลวิจัยสรุปว่าอะไร

งานนี้พบว่า weight, height, age, sex สามารถใช้ทำนาย REE ได้ในระดับที่เหมาะกับการใช้งานทั่วไป แต่ยังมี unexplained variability เหลืออยู่ แปลว่าสูตรนี้ไม่ได้แม่น 100%

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- BMR calculation
- TDEE calculation
- calorie target
- goal planning

ข้อกำหนด:

- backend ต้องคำนวณและบันทึกค่าเป็นหลัก
- Flutter ห้ามใช้สูตรคนละชุดแล้วแสดงแทน backend
- ต้องแสดงว่าเป็นค่าประมาณ
- ต้องเก็บ formula version
- ไม่ควรใช้ IBW แทน actual weight ในสูตรนี้ เว้นแต่ระบบมีสูตรเฉพาะและ label ชัดเจน

---

## 5. Frankenfield et al. - Validation ของสูตร BMR/RMR

**ชื่อ:** Comparison of Predictive Equations for Resting Metabolic Rate in Healthy Nonobese and Obese Adults: A Systematic Review  
**ลิงก์:** https://pubmed.ncbi.nlm.nih.gov/15883556/

### งานวิจัยนี้คืออะไร

เป็น systematic review ที่เปรียบเทียบสูตรทำนาย resting metabolic rate หลายสูตร เช่น:

- Harris-Benedict
- Mifflin-St Jeor
- Owen
- WHO/FAO/UNU

### เขาวิจัยไปทำไม

เพราะมีสูตรหลายสูตรและแต่ละสูตรให้ค่าต่างกัน นักวิจัยต้องการตอบว่า:

> สูตรไหนทำนาย RMR ได้ใกล้เคียงค่าที่วัดจริงที่สุดในผู้ใหญ่ที่ไม่อ้วนและอ้วน

### เขาทำอย่างไร

เขารวบรวมงาน validation ที่เปรียบเทียบ predicted RMR กับ measured RMR แล้วประเมิน:

- ความคลาดเคลื่อน
- จำนวนคนที่สูตรทำนายได้ใกล้เคียงค่าจริง
- ความเหมาะสมใน nonobese/obese adults

### ใช้ formula/matrix อะไร

ไม่ได้สร้างสูตรใหม่ แต่ใช้ comparison matrix:

| สูตร | predicted RMR | measured RMR | error | percent within acceptable range |
|---|---|---|---|---|

metric สำคัญคือความสามารถในการทำนายได้ภายในช่วงประมาณ 10% ของค่าที่วัดจริง

### ผลวิจัยสรุปว่าอะไร

Mifflin-St Jeor เป็นสูตรที่ reliable มากกว่าสูตรอื่นในผู้ใหญ่ nonobese และ obese โดยทำนายได้ภายในช่วงคลาดเคลื่อนที่ยอมรับได้ในคนจำนวนมากกว่า และมี error range แคบกว่า

### Calories Guard เอามาใช้ยังไง

ใช้ยืนยันว่า:

- เลือก Mifflin-St Jeor เป็น default ได้อย่างมีเหตุผล
- แต่ต้องบอกว่าเป็น estimate
- ควรมีการปรับค่าจาก weight trend จริงของผู้ใช้

---

## 6. CDC และ ADA - เป้าหมายลดน้ำหนักและ calorie deficit

**CDC:** https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html  
**ADA criteria PDF:** https://diabetes.org/sites/default/files/2023-09/Weight%20Loss%20Program%20Criteria.pdf

### งาน/แหล่งนี้คืออะไร

ไม่ใช่งานทดลองสูตรใหม่ แต่เป็น guideline/public health guidance สำหรับการลดน้ำหนักอย่างปลอดภัย

### เขาทำไปทำไม

เป้าหมายคือให้คำแนะนำที่ปลอดภัยและใช้ได้กับประชาชนทั่วไป ไม่ให้คนลดน้ำหนักเร็วเกินไปหรือใช้วิธีเสี่ยง

### ใช้สูตรหรือ matrix อะไร

แนวคิดหลักคือ energy balance:

```text
น้ำหนักเปลี่ยน = energy intake - energy expenditure
```

การตั้งเป้าลดน้ำหนักจึงมักใช้:

```text
calorie target = TDEE - deficit
```

โดย deficit ควร conservative และปรับตามบริบท

### ผลสรุปคืออะไร

การลดน้ำหนักควร realistic และค่อยเป็นค่อยไป โปรแกรมควบคุมน้ำหนักที่ปลอดภัยมักใช้ deficit ระดับกลาง เช่นประมาณ 500-750 kcal/day พร้อมการปรับพฤติกรรม

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- calorie target
- goal speed warning
- safe deficit guardrail

ข้อกำหนด:

- ถ้าผู้ใช้ตั้งเป้าหมายเร็วเกินไป ต้องเตือน
- ไม่ควรแนะนำ very low-calorie diet
- ไม่ควรรับประกันผลลดน้ำหนัก

---

## 7. National Academies DRI - Macronutrient Range

**ลิงก์:** https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids  
**NCBI tables:** https://www.ncbi.nlm.nih.gov/books/NBK208874/

### แหล่งนี้คืออะไร

เป็น Dietary Reference Intakes หรือ DRI ซึ่งเป็นค่าอ้างอิงทางโภชนาการระดับประชากร

### เขาทำไปทำไม

เพื่อกำหนดช่วงสารอาหารที่เหมาะสมสำหรับประชาชนทั่วไป เช่น carbohydrate, protein, fat, fiber

### ใช้สูตรหรือ matrix อะไร

ใช้กรอบ AMDR หรือ Acceptable Macronutrient Distribution Range

```text
protein_kcal = protein_g * 4
carb_kcal = carb_g * 4
fat_kcal = fat_g * 9

macro_percent = macro_kcal / total_kcal * 100
```

ช่วงที่มักใช้อ้างอิงในผู้ใหญ่:

| Macro | ช่วงพลังงาน |
|---|---|
| Carbohydrate | 45-65% |
| Fat | 20-35% |
| Protein | 10-35% |

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- macro target
- macro dashboard
- warning เมื่อ custom macro สูง/ต่ำมาก

ข้อกำหนด:

- default macro ควรอยู่ในช่วง AMDR
- ถ้าผู้ใช้ตั้งเองนอกช่วง ต้อง label ว่า custom
- ไม่ควรบอกว่าทุกคนต้องกิน macro แบบเดียวกัน

---

## 8. EFSA - Dietary Reference Values for Water

**ลิงก์:** https://www.efsa.europa.eu/en/efsajournal/pub/1459

### งานนี้คืออะไร

เป็น scientific opinion ของ EFSA เรื่องปริมาณน้ำที่เหมาะสมหรือ adequate intake

### เขาวิจัยไปทำไม

เพื่อกำหนด reference value สำหรับน้ำในประชากร โดยพิจารณาจาก:

- อายุ
- เพศ
- สภาพอากาศ
- กิจกรรม
- น้ำจากอาหารและเครื่องดื่ม

### ใช้ formula/matrix อะไร

ใช้ dietary reference value framework ไม่ใช่สูตรตายตัวแบบ BMR

แนวคิดสำคัญ:

```text
total water intake = water from beverages + water from food
```

ค่า adequate intake เป็นค่าอ้างอิงระดับประชากร ไม่ใช่ prescription รายบุคคล

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- water logging
- water target
- hydration reminder

ข้อกำหนด:

- water target ต้องแก้ไขได้
- ไม่ควรใช้กฎ 8 แก้วแบบตายตัว
- ต้องบันทึกตาม selected date/timezone
- ไม่ควรอ้างว่าน้ำรักษาโรค

---

## 9. FAO/INFOODS - Food Composition, Recipe, Unit, Version

**Standards:** https://www.fao.org/infoods/infoods/standards-guidelines/en/  
**Food composition chapter:** https://www.fao.org/4/y4705e/y4705e06.htm  
**Data checking:** https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/Guidelines_data_checking2012.pdf

### งาน/มาตรฐานนี้คืออะไร

FAO/INFOODS เป็นมาตรฐานและแนวทางสำหรับการสร้างและตรวจสอบฐานข้อมูลส่วนประกอบอาหาร

### เขาทำไปทำไม

เพราะข้อมูลโภชนาการอาหารมีความซับซ้อน เช่น:

- อาหารดิบกับอาหารสุกต่างกัน
- หน่วย household เช่น ช้อนโต๊ะ/ถ้วย/ชิ้น ต้องแปลงเป็นกรัม
- สูตรอาหารมี yield loss
- สารอาหารบางตัวหายจากการปรุง
- แหล่งข้อมูลต่างกันให้ค่าต่างกัน

### ใช้ formula/matrix อะไร

สูตรพื้นฐาน:

```text
nutrient_from_ingredient =
nutrient_per_100g * edible_grams_used / 100
```

สูตร recipe:

```text
recipe_total = sum(nutrient_from_each_ingredient)
per_serving = recipe_total / serving_count
```

ถ้ามีข้อมูลขั้นสูง:

```text
adjusted_nutrient =
raw_nutrient * retention_factor * yield_factor
```

data checking matrix:

| สิ่งที่ตรวจ | ตัวอย่าง |
|---|---|
| source | ThaiFCD, USDA, admin, user |
| unit basis | per 100g, per serving |
| edible portion | ส่วนที่กินได้ |
| conversion | cup -> gram |
| missing nutrient | protein/carbs/fat หายไหม |
| version | ค่าชุดนี้มาจากเวอร์ชันใด |

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- `ingredients`
- `units`
- `food_ingredient`
- `recipes`
- `recipe_ingredients`
- `food_recipe`
- food versioning
- log snapshot

ข้อกำหนด:

- ingredients ต้องเป็น strong entity
- ทุก ingredient ต้องมี unit/nutrient basis
- recipe nutrition ควรคำนวณจาก ingredient
- เมื่อแอดมินแก้ข้อมูลอาหาร ห้ามทำให้ log เก่าของผู้ใช้เปลี่ยนย้อนหลัง

---

## 10. ThaiFCD / ASEAN / USDA FoodData Central

**ThaiFCD FAO entry:** https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en  
**ASEAN DB:** https://inmu.mahidol.ac.th/aseanfoods/composition_data.html  
**USDA FDC:** https://fdc.nal.usda.gov/api-guide

### แหล่งเหล่านี้คืออะไร

เป็นฐานข้อมูลโภชนาการอาหาร:

- ThaiFCD: อาหารไทย โดย Institute of Nutrition, Mahidol University
- ASEAN Food Composition Database: อาหารในภูมิภาค ASEAN
- USDA FoodData Central: ฐานข้อมูลอาหารสหรัฐฯ และ branded foods

### เขาทำไปทำไม

เพื่อให้มีข้อมูลโภชนาการมาตรฐาน เช่น:

- พลังงาน
- protein
- carbohydrate
- fat
- fiber
- vitamins/minerals

### ใช้ formula/matrix อะไร

ไม่ได้ใช้สูตรเดียว แต่ใช้ food composition table structure:

| food code | food name | edible portion | unit basis | kcal | protein | carb | fat | source |
|---|---|---|---|---|---|---|---|---|

### Calories Guard เอามาใช้ยังไง

ใช้เป็น source ของ:

- ingredient nutrient
- Thai food nutrient
- beverage/drink values
- recipe calculation

ข้อกำหนด:

- อาหารไทยให้ priority ThaiFCD
- ถ้าไม่มี ThaiFCD ใช้ ASEAN/USDA/admin estimate เป็น fallback
- ต้องแสดง source และ version
- ห้าม merge ค่าโดยไม่รู้ที่มา

---

## 11. Michie et al. - Behavior Change Technique Taxonomy

**ลิงก์:** https://doi.org/10.1007/s12160-013-9486-6

### งานนี้คืออะไร

เป็น taxonomy หรือระบบจัดหมวดหมู่เทคนิคการเปลี่ยนพฤติกรรม เรียกว่า BCT Taxonomy v1

### เขาวิจัยไปทำไม

ปัญหาของงานสุขภาพเชิงพฤติกรรมคือแต่ละงานใช้คำไม่เหมือนกัน เช่น “feedback”, “goal”, “reward” ทำให้เปรียบเทียบกันยาก

งานนี้จึงจัดทำ taxonomy ให้เรียกเทคนิคต่าง ๆ ด้วยภาษามาตรฐาน

### ใช้ formula/matrix อะไร

ใช้ taxonomy matrix:

| BCT | ความหมาย | ตัวอย่างในแอพ |
|---|---|---|
| Goal setting | ตั้งเป้าหมาย | calorie goal |
| Self-monitoring | ติดตามตัวเอง | food log |
| Feedback | ให้ผลสะท้อนกลับ | dashboard |
| Prompts/cues | แจ้งเตือน | reminder |
| Rewards | ให้รางวัล | badge/pet |
| Review goals | ทบทวนเป้าหมาย | weight trend |

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- dashboard feedback
- daily goal
- reminders
- gamification
- streak/missions

ข้อกำหนด:

- ทุก gamification ควร map กับ behavior change technique
- notification ต้องเป็น prompts/cues ที่ผู้ใช้ควบคุมได้
- feedback ต้อง actionable ไม่ใช่แค่ตัวเลข

---

## 12. Gamification Reviews - Badge, Streak, Pet Progression

**Digital health gamification:** https://pmc.ncbi.nlm.nih.gov/articles/PMC11701442/  
**Family engagement gamification:** https://pmc.ncbi.nlm.nih.gov/articles/PMC8460596/  
**Serious games diet/PA:** https://pmc.ncbi.nlm.nih.gov/articles/PMC10056209/

### งานวิจัยกลุ่มนี้คืออะไร

เป็น systematic review/meta-analysis ที่ดูว่า gamification ใน digital health app ช่วยเพิ่ม engagement หรือเปลี่ยนพฤติกรรมสุขภาพได้ไหม

### เขาวิจัยไปทำไม

เพราะหลายแอพใส่ badge, point, streak, leaderboard แต่ยังไม่ชัดว่าช่วยจริงหรือแค่ทำให้แอพดูสนุก

### เขาทำอย่างไร

รวบรวมงานที่มีฟีเจอร์ gamification แล้วดูผล เช่น:

- engagement
- retention
- physical activity
- diet behavior
- motivation
- adherence

### ใช้ formula/matrix อะไร

ใช้ gamification mechanic matrix:

| mechanic | ตัวอย่าง | ความเสี่ยง |
|---|---|---|
| points | ได้แต้มจากการบันทึก | อาจเน้นแต้มมากกว่าสุขภาพ |
| badges | badge เมื่อทำสำเร็จ | ถ้าได้ยากเกินไปอาจท้อ |
| streaks | ทำต่อเนื่องหลายวัน | ถ้าขาดแล้ว reset อาจ shame |
| missions | ภารกิจรายวัน | ต้องไม่บังคับเกินไป |
| avatar/pet | ตัวละครเติบโต | ควรเป็น emotional support |
| leaderboard | แข่งกับคนอื่น | เสี่ยงเปรียบเทียบ/กดดัน |

### ผลวิจัยสรุปว่าอะไร

gamification มีศักยภาพช่วย engagement แต่ผลลัพธ์ขึ้นกับการออกแบบ และไม่ควรตีความว่า gamification ทำให้สุขภาพดีแน่นอน

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- pet progression
- streak
- badge
- daily missions

ข้อกำหนด:

- ใช้ supportive design
- มี recovery หลัง streak ขาด
- ไม่ใช้ข้อความ shame
- ไม่ทำให้ผู้ใช้หมกมุ่นกับ calorie tracking
- ไม่อ้างว่า badge ทำให้สุขภาพดีแน่นอน

---

## 13. WHO AI for Health และ NIST AI RMF

**WHO:** https://www.who.int/publications/i/item/9789240029200  
**NIST AI RMF:** https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10

### งาน/มาตรฐานนี้คืออะไร

WHO เป็น guideline ด้านจริยธรรมและ governance ของ AI ในสุขภาพ  
NIST AI RMF เป็น framework สำหรับบริหารความเสี่ยง AI

### เขาทำไปทำไม

AI ในสุขภาพมีความเสี่ยง เช่น:

- ตอบผิดแต่ดูมั่นใจ
- bias
- privacy leak
- ผู้ใช้เข้าใจว่าเป็นคำแนะนำแพทย์
- ระบบล่มหรือ provider ล้มเหลว

### ใช้ formula/matrix อะไร

WHO ใช้ ethical principles:

| หลักการ | ความหมาย |
|---|---|
| autonomy | ผู้ใช้ต้องตัดสินใจเองได้ |
| safety | AI ต้องไม่สร้างอันตราย |
| transparency | ต้องบอกว่าเป็น AI/estimate |
| accountability | ตรวจสอบย้อนหลังได้ |
| inclusiveness | ไม่ทำให้กลุ่มใดเสียเปรียบ |

NIST ใช้ AI RMF:

```text
Govern -> Map -> Measure -> Manage
```

| ขั้น | ใช้กับแอพ |
|---|---|
| Govern | กำหนด policy/guardrail |
| Map | ระบุ risk เช่น hallucination |
| Measure | test prompt, health check |
| Manage | fallback, kill switch, monitoring |

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- AI coach
- meal estimate
- recipe suggestion
- scope guard
- health endpoint
- kill switch

ข้อกำหนด:

- AI ห้ามวินิจฉัยโรค
- AI ต้องตอบเฉพาะเรื่อง nutrition/fitness ที่อยู่ใน scope
- AI estimate ต้องให้ผู้ใช้ยืนยันก่อนบันทึก
- ต้องมี fallback เมื่อ Ollama ล่ม
- ต้องมี `/api/chat/health`
- ต้องมี `AI_ENABLED=false` เพื่อปิด AI ได้

---

## 14. งานวิจัย LLM Nutrition Advice และ Food Image Recognition

**LLM nutrition:** https://pmc.ncbi.nlm.nih.gov/articles/PMC13026456/  
**Food recognition review:** https://www.mdpi.com/2029682

### งานกลุ่มนี้คืออะไร

เป็นงานที่ดูว่า AI/LLM หรือ computer vision ใช้กับอาหารและโภชนาการได้แม่นแค่ไหน

### เขาวิจัยไปทำไม

AI อาจช่วย:

- แนะนำอาหาร
- ประเมินเมนู
- อ่านรูปอาหาร
- ประมาณ portion

แต่ความเสี่ยงคือ AI อาจเดาผิด โดยเฉพาะ portion size และ nutrient calculation

### ใช้ formula/matrix อะไร

งาน food recognition มักใช้ metric เช่น:

| metric | ความหมาย |
|---|---|
| classification accuracy | ทายชนิดอาหารถูกไหม |
| top-k accuracy | คำตอบที่ถูกอยู่ใน top k หรือไม่ |
| portion error | ประมาณปริมาณผิดเท่าไหร่ |
| calorie error | calorie estimate ต่างจากค่าจริงเท่าไหร่ |

งาน LLM nutrition ใช้ evaluation matrix:

| มิติ | ตัวอย่าง |
|---|---|
| guideline concordance | ตรงกับ guideline ไหม |
| safety | มีคำแนะนำเสี่ยงไหม |
| completeness | ให้ข้อมูลครบไหม |
| hallucination | มีข้อมูลมั่วไหม |

### ผลวิจัยสรุปว่าอะไร

AI ช่วยได้ แต่ยังไม่ควรเชื่อแบบอัตโนมัติ โดยเฉพาะ:

- portion size
- calorie estimate
- medical nutrition advice
- disease-specific diet

### Calories Guard เอามาใช้ยังไง

ข้อกำหนด:

- AI-generated food ต้องเป็น draft
- ผู้ใช้ต้องแก้ portion ได้
- ต้องแสดง label estimated
- ห้ามบันทึกเข้าประวัติแบบ final โดยไม่ confirm
- medical advice ต้อง refuse/redirect

---

## 15. Wearable / Health Connect

**Wearable review:** https://pmc.ncbi.nlm.nih.gov/articles/PMC4683756/  
**Fitbit accuracy:** https://pmc.ncbi.nlm.nih.gov/articles/PMC9047731/  
**Health Connect:** https://developer.android.com/health-and-fitness/health-connect/availability

### งานวิจัยนี้คืออะไร

เป็นงานที่ประเมินความแม่นของ wearable devices เช่น smartwatch/fitness tracker ในการวัด:

- steps
- heart rate
- energy expenditure
- activity

### เขาวิจัยไปทำไม

เพราะหลายแอพนำข้อมูลจาก wearable มาคำนวณ calorie แต่ค่าพลังงานจาก wearable อาจคลาดเคลื่อน

### ใช้ formula/matrix อะไร

ใช้ validation matrix:

| wearable output | reference method | error |
|---|---|---|
| steps | manual/video count | step error |
| heart rate | ECG/chest strap | HR error |
| energy expenditure | indirect calorimetry | kcal error |

### ผลวิจัยสรุปว่าอะไร

โดยทั่วไป steps มักแม่นกว่า energy expenditure ส่วน calorie/active energy มีความคลาดเคลื่อนมากกว่า

### Calories Guard เอามาใช้ยังไง

ข้อกำหนด:

- active calories ต้อง label ว่า estimate
- ต้องแสดง source เช่น Health Connect/Fitbit
- ต้องมี timestamp
- ห้าม double count กับ activity factor ใน TDEE

---

## 16. OWASP MASVS - Mobile Security

**ลิงก์:** https://mas.owasp.org/MASVS/

### มาตรฐานนี้คืออะไร

OWASP MASVS เป็นมาตรฐานตรวจสอบความปลอดภัยของ mobile app

### เขาทำไปทำไม

เพื่อให้ mobile app ปลอดภัยในเรื่อง:

- storage
- authentication
- network
- cryptography
- platform interaction
- privacy
- code quality

### ใช้ matrix อะไร

ใช้ security control matrix:

| หมวด | ตัวอย่าง control |
|---|---|
| MASVS-STORAGE | ไม่เก็บ secret แบบ plaintext |
| MASVS-AUTH | session/auth ปลอดภัย |
| MASVS-NETWORK | ใช้ TLS |
| MASVS-PRIVACY | ลดการเก็บข้อมูลเกินจำเป็น |
| MASVS-CODE | dependency/security scan |

### Calories Guard เอามาใช้ยังไง

ข้อกำหนด:

- ห้ามใส่ Supabase service role key ใน Flutter
- secret ต้องอยู่ backend/Railway env เท่านั้น
- token ต้องเก็บใน secure storage
- API sensitive ต้อง require auth
- upload/storage ต้องตรวจ permission

---

## 17. PDPA/GDPR/EDPB - Privacy and Consent

**EDPB basics:** https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en  
**EDPB lawful processing:** https://www.edpb.europa.eu/sme-data-protection-guide/process-personal-data-lawfully_en  
**PDPC Thailand:** https://register-gppc-plus.pdpc.or.th/

### แหล่งนี้คืออะไร

เป็นแหล่งข้อมูลด้านกฎหมายและแนวทางคุ้มครองข้อมูลส่วนบุคคล โดยเฉพาะข้อมูลสุขภาพซึ่งถือว่าอ่อนไหว

### เขาทำไปทำไม

เพื่อกำหนดว่าแอพที่เก็บข้อมูลผู้ใช้ต้อง:

- แจ้งวัตถุประสงค์
- ขอ consent ในกรณีที่จำเป็น
- เก็บเท่าที่จำเป็น
- ให้ผู้ใช้ลบ/ขอข้อมูลได้
- มีมาตรการป้องกันข้อมูลรั่ว

### ใช้ matrix อะไร

privacy requirement matrix:

| ประเด็น | คำถาม |
|---|---|
| purpose | เก็บข้อมูลไปทำไม |
| data minimization | เก็บเกินจำเป็นไหม |
| consent | ต้องขอ consent ไหม |
| access | ใครเข้าถึงได้ |
| retention | เก็บนานเท่าไหร่ |
| deletion/export | ผู้ใช้ลบหรือ export ได้ไหม |

### Calories Guard เอามาใช้ยังไง

ข้อกำหนด:

- diet, weight, health data, AI chat เป็นข้อมูลอ่อนไหว
- Health Connect ต้องขอ consent ชัดเจน
- AI processing ต้องอธิบายให้ผู้ใช้รู้
- ต้องมี account deletion/export
- admin access ต้องจำกัดและ audit

---

## 18. WCAG และ AHRQ Health Literacy

**WCAG:** https://www.w3.org/TR/wcag/  
**AHRQ:** https://www.ahrq.gov/health-literacy/improve/precautions/index.html

### แหล่งนี้คืออะไร

WCAG เป็นมาตรฐาน accessibility  
AHRQ เป็น toolkit สำหรับสื่อสารข้อมูลสุขภาพให้เข้าใจง่าย

### เขาทำไปทำไม

ผู้ใช้สุขภาพไม่ได้มีความรู้เท่ากัน และบางคนอาจมีข้อจำกัดด้านการมองเห็น การอ่าน หรือความเข้าใจข้อมูลโภชนาการ

### ใช้ matrix อะไร

WCAG ใช้หลัก POUR:

| หลัก | ความหมาย |
|---|---|
| Perceivable | มองเห็น/รับรู้ได้ |
| Operable | ใช้งานได้ |
| Understandable | เข้าใจได้ |
| Robust | ทำงานกับเทคโนโลยีช่วยเหลือได้ |

AHRQ ใช้แนวคิด universal precautions:

```text
ออกแบบเหมือนผู้ใช้ทุกคนอาจต้องการคำอธิบายที่ง่ายขึ้น
```

### Calories Guard เอามาใช้ยังไง

ข้อกำหนด:

- ใช้ภาษาไทยง่าย ๆ
- คำว่า BMR, TDEE, macro ต้องมีคำอธิบาย
- chart ต้องมี text summary
- contrast ต้องอ่านง่าย
- ปุ่มและสถานะต้องมี label ชัดเจน

---

## 19. สรุปแบบใช้พูดกับกรรมการ

ถ้าต้องอธิบายสั้น ๆ:

> งานวิจัยที่ใช้ไม่ได้เป็นงานเดียวที่สร้างแอพเหมือนเรา แต่เป็นหลักฐานแยกตามองค์ประกอบของระบบ เช่น การบันทึกอาหาร สูตรคำนวณพลังงาน ฐานข้อมูลอาหาร AI ความปลอดภัย และ gamification เรานำแต่ละงานมาแปลงเป็น requirement และ test case เพื่อให้แอพทำงานถูกต้อง ปลอดภัย และตรวจสอบได้

ตัวอย่างการแปลงงานวิจัยเป็นระบบ:

| งานวิจัย | สิ่งที่งานวิจัยบอก | กลายเป็นอะไรในแอพ |
|---|---|---|
| Burke / Patel | การจดอาหารช่วย self-monitoring | food log + dashboard |
| Mifflin | คำนวณ REE จาก actual weight/height/age/sex | backend BMR formula |
| Frankenfield | Mifflin ใช้ได้แต่ยังคลาดเคลื่อน | label estimated + formula version |
| FAO/INFOODS | recipe ต้องคำนวณจาก ingredient/unit | ingredients + units + recipe calculation |
| ThaiFCD | อาหารไทยควรใช้ฐานข้อมูลไทย | source priority ThaiFCD |
| WHO/NIST | AI สุขภาพต้องมี safety/monitoring | scope guard + kill switch |
| OWASP | mobile app ห้าม leak secret | no service key in Flutter |
| WCAG/AHRQ | ข้อมูลสุขภาพต้องอ่านง่ายและเข้าถึงได้ | text summary + plain Thai |

---

## 20. ข้อควรระวังในการนำเสนอ

ควรพูดว่า:

> แอพใช้หลักฐานวิจัยเพื่อออกแบบสูตร การบันทึกอาหาร การคำนวณสูตรอาหาร AI guardrail และระบบความปลอดภัย

ไม่ควรพูดว่า:

> งานวิจัยพิสูจน์แล้วว่าแอพนี้ทำให้ผู้ใช้ลดน้ำหนักได้แน่นอน

เพราะการพิสูจน์ว่าแอพของเรามีผลจริง ต้องทำ user study หรือ pilot study กับผู้ใช้ของ Calories Guard เอง เช่น:

- retention rate
- food log adherence
- weight trend outcome
- AI correction rate
- user satisfaction
- safety incident rate

---

## 21. Practical Research-to-QA Matrix

| Research evidence | Product rule | QA case |
|---|---|---|
| Mifflin formula | ใช้ actual weight ไม่ใช่ IBW ในสูตร app | profile test ต้องได้ BMR ตรงสูตร |
| Frankenfield validation | ต้อง label estimated | UI แสดง “ค่าประมาณ” |
| FAO recipe calculation | nutrient = per100g * grams / 100 | recipe unit test |
| FAO data checking | missing nutrient ต้อง flag | ingredient ไม่มี protein ต้องเตือน admin |
| ThaiFCD | source/version ต้องเก็บ | admin เห็น source ThaiFCD |
| WHO AI | AI ต้องไม่วินิจฉัย | prompt ถามโรคต้อง refuse |
| NIST AI RMF | AI ต้อง monitor/disable ได้ | AI_ENABLED=false แล้ว endpoint 503 |
| Wearable review | active kcal เป็น estimate | Health Connect calorie มี label source |
| OWASP MASVS | secret ห้ามอยู่ client | scan Flutter bundle |
| WCAG | chart ต้องมี text summary | screen reader อ่าน summary ได้ |

---

## 22. งานวิจัยที่รองรับเป้าหมายอื่นนอกจากลดน้ำหนัก

เอกสารเดิมเน้น weight loss มากเกินไป แต่ในแอพจริงผู้ใช้อาจมีเป้าหมายอย่างน้อย 4 แบบ:

| Goal mode | ความหมาย | สิ่งที่แอพต้องคำนวณ |
|---|---|---|
| ลดน้ำหนัก | ลด fat mass โดยพยายามรักษากล้ามเนื้อ | calorie deficit + protein เพียงพอ + trend |
| เพิ่มกล้ามเนื้อ | เพิ่ม lean mass ผ่าน resistance training และพลังงานเพียงพอ | maintenance/surplus + protein target + rate of gain |
| รักษาน้ำหนัก | ให้น้ำหนักคงที่ใน range | target ใกล้ TDEE + weight trend band |
| รักษากล้ามเนื้อ | ลดการสูญเสีย muscle ระหว่าง deficit/สูงอายุ/กิจกรรมสูง | protein target + resistance training reminder + conservative deficit |

ดังนั้น Calories Guard ไม่ควรถูกอธิบายว่าเป็นแค่ “แอพลดน้ำหนัก” แต่ควรอธิบายว่าเป็น:

> แอพติดตามโภชนาการและเป้าหมายร่างกาย ที่รองรับการลดน้ำหนัก เพิ่มกล้ามเนื้อ รักษาน้ำหนัก และรักษามวลกล้ามเนื้อ โดยใช้สูตรคำนวณและหลักฐานวิจัยที่เหมาะกับแต่ละ goal mode

---

## 23. ISSN Position Stand - Protein and Exercise

**ชื่อ:** International Society of Sports Nutrition Position Stand: Protein and Exercise  
**ลิงก์:** https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8

### งานนี้คืออะไร

เป็น position stand หรือคำแนะนำเชิงวิชาการจาก International Society of Sports Nutrition เกี่ยวกับการกินโปรตีนในคนที่ออกกำลังกาย โดยเฉพาะคนที่ต้องการ:

- เพิ่มกล้ามเนื้อ
- รักษามวลกล้ามเนื้อ
- ฟื้นตัวจากการฝึก
- สนับสนุน adaptation จาก resistance training

### เขาทำไปทำไม

คนทั่วไปมักรู้แค่ RDA protein 0.8 g/kg/day แต่คนที่ออกกำลังกายหรือฝึกเวทมีความต้องการโปรตีนสูงกว่าเพื่อซ่อมแซมและสร้างกล้ามเนื้อ

งานนี้จึงตอบคำถามว่า:

> สำหรับคนที่ออกกำลังกาย ต้องกินโปรตีนเท่าไหร่เพื่อสร้างหรือรักษากล้ามเนื้อ

### เขาทำอย่างไร

เป็นการ review และสังเคราะห์หลักฐานจากงานวิจัยหลายกลุ่ม เช่น:

- protein intake
- resistance training
- muscle protein synthesis
- lean mass
- strength
- timing/distribution ของ protein

### ใช้ formula/matrix อะไร

งานนี้ใช้ recommendation matrix ตาม goal และ population:

| กลุ่มผู้ใช้ | protein recommendation |
|---|---|
| ผู้ใหญ่ออกกำลังกายทั่วไป | ประมาณ 1.4-2.0 g/kg body weight/day |
| เป้าหมายสร้าง/รักษากล้าม | 1.4-2.0 g/kg/day เพียงพอสำหรับหลายคน |
| บางกรณีต้องการลดไขมันและรักษา lean mass | อาจต้องสูงกว่านี้ ขึ้นกับความ lean และ deficit |

สูตรที่แอพใช้ได้:

```text
protein_target_g = body_weight_kg * protein_factor

เช่น:
70 kg * 1.6 g/kg = 112 g protein/day
```

### ตัวเลข 1.4-2.0 มาจากอะไร

ตัวเลขนี้ไม่ได้เดาจากสูตรคณิตศาสตร์ลอย ๆ แต่มาจากการสังเคราะห์งานวิจัยเกี่ยวกับ protein balance, training adaptation, lean mass และ strength ในคนที่ออกกำลังกาย

ความหมายเชิงแอพ:

- 1.4 g/kg/day เหมาะเป็นค่าล่างสำหรับ active user
- 1.6 g/kg/day มักใช้เป็น default ที่สมเหตุสมผลสำหรับ muscle gain/recomposition
- 2.0 g/kg/day ใช้เป็นค่าบนทั่วไปสำหรับผู้ฝึกจริงจัง

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ goal mode:

- เพิ่มกล้ามเนื้อ
- รักษากล้ามเนื้อ
- recomposition
- ลดน้ำหนักแต่ไม่อยากเสียกล้าม

ข้อกำหนด:

- ถ้า user เลือก “เพิ่มกล้ามเนื้อ” default protein ไม่ควรต่ำเท่า RDA 0.8 g/kg
- UI ต้องบอกว่า target เป็น nutrition target ไม่ใช่คำสั่งแพทย์
- ถ้าผู้ใช้มีโรคไต/โรคเฉพาะ ต้องมี disclaimer ให้ปรึกษาผู้เชี่ยวชาญ

---

## 24. Morton et al. - Protein Supplementation + Resistance Training Meta-Regression

**ชื่อ:** A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults  
**แหล่ง:** British Journal of Sports Medicine  
**ลิงก์ PDF:** https://elementssystem.com/wp-content/uploads/2018/03/Morton-protein-review.pdf

### งานนี้คืออะไร

เป็น systematic review, meta-analysis และ meta-regression ที่ศึกษาว่า protein supplementation ช่วยเพิ่ม muscle mass และ strength จาก resistance training หรือไม่

### เขาวิจัยไปทำไม

คำถามที่คนออกกำลังกายถามบ่อยคือ:

> ถ้าฝึกเวทแล้วกินโปรตีนเพิ่ม จะช่วยให้กล้ามเพิ่มจริงไหม และต้องกินถึงจุดไหน

### เขาทำอย่างไร

งานนี้รวบรวม randomized controlled trials หลายงานที่เปรียบเทียบ:

- resistance training + protein supplementation
- resistance training + placebo/ไม่เสริมโปรตีน

แล้วดูผลลัพธ์:

- fat-free mass
- one-repetition maximum หรือ 1RM strength
- muscle fiber cross-sectional area

### ใช้ formula/matrix อะไร

ใช้ meta-analysis และ meta-regression:

```text
effect_size = ผลลัพธ์กลุ่ม protein - ผลลัพธ์กลุ่ม control
```

จากนั้นใช้ meta-regression เพื่อดู dose-response:

```text
protein intake เพิ่มขึ้น -> fat-free mass/strength เพิ่มขึ้นแค่ไหน
```

matrix ที่ใช้คิด:

| ตัวแปร | ความหมาย |
|---|---|
| total protein intake | g/kg/day |
| resistance training duration | ระยะเวลาฝึก |
| training status | มือใหม่/มีประสบการณ์ |
| FFM change | การเปลี่ยน fat-free mass |
| strength change | การเปลี่ยน strength |

### ผลวิจัยสรุปว่าอะไร

ผลโดยรวมพบว่า protein supplementation ช่วยเพิ่มผลจาก resistance training โดยเฉพาะเมื่อ protein intake เดิมไม่พอ งานนี้มักถูกอ้างว่า benefit เพิ่มขึ้นจนประมาณ 1.6 g/kg/day และ upper confidence interval ประมาณ 2.2 g/kg/day

### ตัวเลข 1.6 และ 2.2 มาจากอะไร

- 1.6 g/kg/day มาจากจุดที่ meta-regression เห็นว่า benefit ต่อ fat-free mass เริ่ม plateau
- 2.2 g/kg/day เป็นค่าประมาณ upper confidence interval เพื่อเผื่อความต่างระหว่างบุคคล

แปลเป็น logic ในแอพ:

```text
muscle_gain_default_protein = body_weight_kg * 1.6
muscle_gain_high_option = body_weight_kg * 2.2
```

แต่ไม่ควรบอกว่า 2.2 ดีกว่า 1.6 สำหรับทุกคน เพราะบางคนไม่ได้ benefit เพิ่มถ้าได้รับโปรตีนพอแล้ว

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- protein target สำหรับเพิ่มกล้าม
- muscle maintenance target
- recomposition

ข้อกำหนด:

- default สำหรับ muscle gain อาจใช้ 1.6 g/kg/day
- advanced/high option อาจให้ผู้ใช้เลือกถึง 2.0-2.2 g/kg/day
- ต้อง label ว่าเป็น estimate และควรปรับตาม training/health status

---

## 25. Helms et al. - รักษากล้ามเนื้อระหว่าง calorie restriction

**ชื่อ:** Evidence-based recommendations for natural bodybuilding contest preparation: nutrition and supplementation  
**ลิงก์:** https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/

### งานนี้คืออะไร

เป็น review ที่สรุปคำแนะนำด้านโภชนาการสำหรับ natural bodybuilders ช่วงเตรียมแข่ง ซึ่งเป็นกรณีที่ต้อง:

- ลดไขมัน
- รักษามวลกล้ามเนื้อ
- ฝึกหนัก
- อยู่ใน calorie deficit

### เขาวิจัยไปทำไม

นักกีฬากลุ่มนี้มีความเสี่ยงเสีย lean mass ระหว่าง diet มากกว่าคนทั่วไป โดยเฉพาะเมื่อ lean อยู่แล้วและ deficit ต่อเนื่อง

คำถามคือ:

> ถ้าต้องลดไขมันแต่รักษากล้ามเนื้อ ควรกินโปรตีนเท่าไหร่ และควรลดน้ำหนักเร็วแค่ไหน

### เขาทำอย่างไร

เป็น evidence-based review รวบรวมงานเกี่ยวกับ:

- protein intake
- lean body mass
- calorie restriction
- bodybuilding contest prep
- rate of weight loss
- fat/carb distribution

### ใช้ formula/matrix อะไร

งานนี้เสนอ protein เป็น g/kg ของ lean body mass ไม่ใช่ total body weight:

```text
protein_target_g = lean_body_mass_kg * protein_factor
```

ช่วงที่เสนอในบริบท lean resistance-trained athletes:

```text
2.3-3.1 g/kg lean body mass/day
```

matrix:

| ตัวแปร | ความหมาย |
|---|---|
| lean body mass | น้ำหนักตัวที่ไม่ใช่ไขมัน |
| energy deficit | ระดับการลดแคลอรี |
| weekly weight loss rate | ลดเร็วแค่ไหน |
| training status | ฝึกเวทจริงจังหรือไม่ |
| risk of muscle loss | โอกาสเสียมวลกล้าม |

### ตัวเลข 2.3-3.1 มาจากอะไร

ตัวเลขนี้ไม่ได้เหมาะกับทุกคน แต่สังเคราะห์จาก evidence ในกลุ่ม natural bodybuilders หรือ resistance-trained lean athletes ที่อยู่ใน calorie deficit

แปลว่า:

- ถ้าผู้ใช้ทั่วไปลดน้ำหนัก ไม่จำเป็นต้อง default สูงถึง 3.1 g/kg LBM
- ถ้าผู้ใช้เลือก goal “รักษากล้ามระหว่าง cut” และเป็น advanced user อาจมี option สูงขึ้น

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- fat loss with muscle preservation
- advanced athlete mode
- recomposition

ข้อกำหนด:

- ถ้าไม่มี lean body mass ให้ใช้ body weight-based range เช่น 1.6-2.2 g/kg เป็น fallback
- ถ้ามี body fat percentage จึงคำนวณ LBM ได้:

```text
lean_body_mass_kg = body_weight_kg * (1 - body_fat_percent / 100)
protein_target_g = lean_body_mass_kg * 2.3 ถึง 3.1
```

- ต้อง label ว่าเป็น advanced/athlete estimate

---

## 26. ACSM Resistance Training - การฝึกเพื่อเพิ่มกล้ามต้องมี progressive overload

**ชื่อ:** Progression Models in Resistance Training for Healthy Adults  
**ลิงก์:** https://www.acsm.org/wp-content/uploads/2025/01/Progression-Models-in-Resistance-Training-for-Healthy-Adults.pdf

### งานนี้คืออะไร

เป็น position stand ของ American College of Sports Medicine เกี่ยวกับการจัดโปรแกรม resistance training เพื่อเพิ่ม:

- strength
- hypertrophy
- muscular endurance
- power

### เขาวิจัยไปทำไม

การเพิ่มกล้ามไม่ได้เกิดจากกินโปรตีนหรือกินแคลอรีอย่างเดียว ต้องมี training stimulus ที่เหมาะสม

คำถามคือ:

> การฝึกเวทควรมี progression อย่างไรเพื่อให้เกิด strength/hypertrophy adaptation

### เขาทำอย่างไร

สังเคราะห์หลักฐานเกี่ยวกับ resistance training variables:

- load
- volume
- frequency
- rest
- exercise selection
- progression
- training status

### ใช้ formula/matrix อะไร

ใช้ training prescription matrix:

| ตัวแปร | ความหมาย |
|---|---|
| load | น้ำหนักที่ใช้ฝึก เช่น %1RM |
| repetitions | จำนวนครั้ง |
| sets | จำนวนเซ็ต |
| frequency | จำนวนวัน/สัปดาห์ |
| progression | เพิ่ม load/volume ตามเวลา |
| goal | strength/hypertrophy/endurance |

### Calories Guard เอามาใช้ยังไง

Calories Guard ไม่จำเป็นต้องเป็น workout app เต็มรูปแบบ แต่ถ้าจะรองรับ muscle gain ต้องไม่ทำให้ผู้ใช้เข้าใจว่า “กินโปรตีนอย่างเดียวพอ”

ข้อกำหนด:

- goal เพิ่มกล้ามควรมีข้อความว่า ต้องคู่กับ resistance training
- ถ้ามี AI coach ควรถามว่าผู้ใช้ฝึกเวทหรือไม่ก่อนให้คำแนะนำเพิ่มกล้าม
- nutrition target ต้องไม่ claim ว่าทำให้กล้ามขึ้นเอง

---

## 27. ESPEN / PROT-AGE - รักษากล้ามเนื้อในผู้สูงอายุ

**ESPEN expert group:** https://www.sciencedirect.com/science/article/pii/S0261561414001113  
**Protein intake and muscle function review:** https://pmc.ncbi.nlm.nih.gov/articles/PMC4394186/  
**ESPEN geriatric guideline PDF:** https://www.espen.org/files/ESPEN-Guidelines/ESPEN_practical_guideline_Clinical_nutrition_and_hydration_in_geriatrics.pdf

### งานนี้คืออะไร

เป็นคำแนะนำและงาน review เกี่ยวกับ protein intake สำหรับผู้สูงอายุ เพื่อรักษา muscle mass, strength และ physical function

### เขาวิจัยไปทำไม

ผู้สูงอายุมีความเสี่ยง sarcopenia หรือการสูญเสียมวลกล้ามเนื้อและกำลังกล้ามเนื้อ อีกทั้งร่างกายมี anabolic resistance คือการตอบสนองต่อโปรตีนลดลง

คำถามคือ:

> RDA protein 0.8 g/kg/day เพียงพอสำหรับผู้สูงอายุหรือไม่

### เขาทำอย่างไร

สังเคราะห์ evidence จาก:

- observational studies
- clinical trials
- expert consensus
- geriatric nutrition guidelines

### ใช้ formula/matrix อะไร

ใช้ protein-per-body-weight recommendation:

```text
protein_target_g = body_weight_kg * protein_factor
```

ค่าที่มักถูกเสนอ:

| กลุ่ม | protein factor |
|---|---|
| ผู้ใหญ่ทั่วไป RDA | 0.8 g/kg/day |
| ผู้สูงอายุสุขภาพดี | 1.0-1.2 g/kg/day |
| ผู้สูงอายุป่วย/เสี่ยง malnutrition | 1.2-1.5 g/kg/day หรือมากกว่าตามแพทย์ |

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ goal:

- maintain muscle
- healthy aging
- weight maintenance ในผู้สูงอายุ

ข้อกำหนด:

- ถ้าผู้ใช้สูงอายุ ระบบไม่ควร default protein ต่ำเกินไปโดยไม่เตือน
- ต้องมี disclaimer สำหรับโรคไต/โรคเรื้อรัง
- ไม่ควรให้คำแนะนำ medical nutrition therapy แทนแพทย์

---

## 28. Weight Maintenance Research - รักษาน้ำหนักหลังลดหรือรักษาน้ำหนักทั่วไป

**Successful weight loss maintenance review:** https://pmc.ncbi.nlm.nih.gov/articles/PMC9105823/  
**Dietary strategies for weight loss maintenance:** https://pmc.ncbi.nlm.nih.gov/articles/PMC6722715/  
**NWCR dietary habits:** https://pmc.ncbi.nlm.nih.gov/articles/PMC4568993/

### งานวิจัยนี้คืออะไร

เป็นงานเกี่ยวกับ weight maintenance หรือการรักษาน้ำหนักหลังลดสำเร็จ/รักษาน้ำหนักให้อยู่ในช่วงเป้าหมาย

### เขาวิจัยไปทำไม

ปัญหาหลังลดน้ำหนักคือ weight regain หลายคนลดได้แต่รักษาไม่ได้ จึงต้องศึกษาว่าพฤติกรรมใดสัมพันธ์กับการ maintain ระยะยาว

### เขาทำอย่างไร

แหล่งอย่าง National Weight Control Registry เก็บข้อมูลคนที่ลดน้ำหนักได้และรักษาไว้ได้ แล้วดูพฤติกรรม เช่น:

- self-monitoring
- physical activity
- dietary consistency
- weighing frequency
- eating patterns

systematic review จะรวบรวมงาน registry และ intervention เพื่อดูปัจจัยร่วม

### ใช้ formula/matrix อะไร

maintenance ไม่ใช่แค่สูตรเดียว แต่ใช้ monitoring matrix:

| ตัวชี้วัด | ใช้ทำอะไร |
|---|---|
| weight trend | ดูว่าน้ำหนัก drift ขึ้นหรือลง |
| maintenance range | ช่วงน้ำหนักที่ยอมรับได้ |
| calorie adherence | กินใกล้ target ไหม |
| activity consistency | กิจกรรมสม่ำเสมอไหม |
| self-monitoring frequency | ชั่งน้ำหนัก/จดอาหารบ่อยแค่ไหน |

สูตรในแอพ:

```text
maintenance_target_kcal = TDEE
maintenance_range_low = target_weight * 0.98
maintenance_range_high = target_weight * 1.02
```

หมายเหตุ:

- ตัวเลข ±2% เป็น product heuristic เพื่อทำ UI ไม่ให้ไวเกินไปกับน้ำหนักแกว่งรายวัน
- ถ้าจะใช้ต้อง label ว่าเป็น “ช่วงติดตาม” ไม่ใช่เกณฑ์แพทย์

### Calories Guard เอามาใช้ยังไง

ใช้รองรับ:

- maintain weight goal
- trend feedback
- selected date log
- reminder แบบไม่กดดัน

ข้อกำหนด:

- ถ้าเป้าหมายคือรักษาน้ำหนัก progress ไม่ควรคำนวณแบบลดน้ำหนัก
- ต้องใช้ trend หรือ range
- ถ้าน้ำหนักแกว่งเล็กน้อยไม่ควรแจ้งเตือนแรง

---

## 29. ที่มาของตัวเลขในสูตรและ matrix ที่แอพใช้

ส่วนนี้ตอบคำถามสำคัญว่า:

> ตัวเลขในสูตรมาจากไหน ไม่ใช่แค่เอามาใส่เองใช่ไหม

### 29.1 ตัวเลขในสูตร Mifflin-St Jeor มาจากไหน

สูตร:

```text
ชาย:
BMR = 10W + 6.25H - 5A + 5

หญิง:
BMR = 10W + 6.25H - 5A - 161
```

เลขเหล่านี้มาจาก multiple linear regression จากข้อมูล measured REE:

| เลข | ความหมาย | มาจากอะไร |
|---|---|---|
| 10 หรือ 9.99 | น้ำหนักเพิ่ม 1 kg สัมพันธ์กับ REE เพิ่มประมาณ 10 kcal/day | regression coefficient ของ weight |
| 6.25 | ส่วนสูงเพิ่ม 1 cm สัมพันธ์กับ REE เพิ่มประมาณ 6.25 kcal/day | regression coefficient ของ height |
| -5 หรือ -4.92 | อายุเพิ่ม 1 ปี REE ลดประมาณ 5 kcal/day | regression coefficient ของ age |
| +5 ชาย | sex adjustment สำหรับชาย | รวมจาก sex coefficient/intercept |
| -161 หญิง | sex/intercept adjustment สำหรับหญิง | รวมจาก model intercept เมื่อ sex เป็นหญิง |

สำคัญ:

- ตัวเลขเหล่านี้ไม่ใช่ค่าคงที่ทางฟิสิกส์
- เป็นค่าจาก regression ของกลุ่มตัวอย่าง
- จึงควรใช้เป็น estimate
- IBW ในงาน Mifflin ใช้จัดกลุ่ม sample ไม่ใช่ input ของสูตร app

### 29.2 ตัวเลข 4/4/9 ของ macro calories มาจากไหน

สูตร:

```text
protein_kcal = protein_g * 4
carb_kcal = carb_g * 4
fat_kcal = fat_g * 9
```

ที่มา:

- เรียกว่า Atwater general factors
- FAO อธิบายว่าเป็น energy conversion factors สำหรับแปลง macronutrient grams เป็น kcal
- เป็นค่าเฉลี่ย ไม่ใช่ค่าที่เป๊ะกับอาหารทุกชนิด

แหล่งอ้างอิง:

- FAO Food Energy - Methods of Analysis and Conversion Factors: https://www.fao.org/4/y5022e/y5022e04.htm
- USDA FoodData Central documentation: https://fdc.nal.usda.gov/Foundation_Foods_Documentation/

ข้อควรระวังในแอพ:

- kcal จาก database อาจไม่เท่ากับ protein*4 + carb*4 + fat*9 พอดี
- เพราะบาง database ใช้ Atwater specific factors, fiber adjustment หรือ rounding
- UI ไม่ควรถือว่า macro sum ต้องเท่ากับ calories 100% เสมอ

### 29.3 ตัวเลข AMDR 45-65 / 20-35 / 10-35 มาจากไหน

ช่วง:

```text
Carbohydrate 45-65% energy
Fat 20-35% energy
Protein 10-35% energy
```

ที่มา:

- Dietary Reference Intakes ของ National Academies
- เรียกว่า Acceptable Macronutrient Distribution Range หรือ AMDR
- ตั้งจากหลักฐานเรื่อง nutrient adequacy และ chronic disease risk ในระดับประชากร

ความหมาย:

- เป็นช่วงทั่วไปสำหรับผู้ใหญ่
- ไม่ใช่สูตรบังคับทุกคน
- athlete/medical condition อาจต่างได้

### 29.4 ตัวเลข protein 1.4-2.0 / 1.6 / 2.2 มาจากไหน

| ตัวเลข | ที่มา | ใช้กับใคร |
|---|---|---|
| 0.8 g/kg/day | RDA ผู้ใหญ่ทั่วไป | คนทั่วไป ไม่เน้น training |
| 1.0-1.2 g/kg/day | ESPEN/PROT-AGE | ผู้สูงอายุเพื่อรักษากล้าม |
| 1.4-2.0 g/kg/day | ISSN position stand | คนออกกำลังกาย/ต้องการสร้างหรือรักษากล้าม |
| 1.6 g/kg/day | Morton meta-regression plateau | default muscle gain/recomposition |
| 2.2 g/kg/day | Morton upper confidence interval | high option สำหรับผู้ฝึกจริงจัง |
| 2.3-3.1 g/kg LBM/day | Helms bodybuilding review | lean resistance-trained athletes ใน deficit |

ข้อกำหนดในแอพ:

- ห้ามใช้เลขเดียวกับทุกคน
- ต้องขึ้นกับ goal mode, activity, age, และ health disclaimer

### 29.5 ตัวเลข calorie deficit/surplus มาจากไหน

Deficit:

```text
target = TDEE - deficit
```

Surplus:

```text
target = TDEE + surplus
```

ที่มา:

- Energy balance model
- guideline ด้าน weight management
- sports nutrition recommendation
- practical monitoring จาก trend จริง

แนวทางในแอพ:

| Goal | ค่าเริ่มต้นที่ควรใช้ | เหตุผล |
|---|---|---|
| ลดน้ำหนักทั่วไป | deficit conservative เช่น 300-500 kcal/day | ลดความเสี่ยง extreme diet |
| ลดน้ำหนักแบบ structured | 500-750 kcal/day | พบใน guideline/program criteria |
| เพิ่มกล้าม | surplus เล็ก เช่น 5-10% หรือประมาณ 150-300 kcal/day เริ่มต้น | ลดการเพิ่มไขมันเกินจำเป็น |
| รักษาน้ำหนัก | target = TDEE | ใช้ trend ปรับ |

หมายเหตุ:

- surplus สำหรับ hypertrophy ยังไม่มีเลข optimum ที่แน่นอนสำหรับทุกคน
- evidence ใหม่ชี้ว่า energy surplus อาจช่วย hypertrophy แต่ขนาด surplus ที่เหมาะสมยังต้องปรับตามบุคคล
- แอพควรใช้ trend 2-4 สัปดาห์ปรับ ไม่ใช่ fix ตลอดไป

### 29.6 ตัวเลข maintenance range ±2% มาจากไหน

นี่ควรอธิบายตรง ๆ ว่าเป็น **product heuristic** ไม่ใช่ guideline ทางการแพทย์

เหตุผล:

- น้ำหนักแกว่งจากน้ำ น้ำตาลไกลโคเจน เกลือ อาหารในทางเดินอาหาร และรอบเดือน
- ถ้าแอพเตือนทุกครั้งที่น้ำหนักขึ้น 0.2-0.5 kg ผู้ใช้จะกังวลเกินไป

สูตร:

```text
range_low = target_weight * 0.98
range_high = target_weight * 1.02
```

ข้อกำหนด:

- label ว่า “ช่วงติดตาม”
- ให้ผู้ใช้ปรับ range ได้
- ใช้ trend ไม่ใช่ค่าวันเดียว

---

## 30. Goal Mode Matrix สำหรับ Calories Guard

| Goal mode | Calorie target | Protein target | Progress metric | Warning |
|---|---|---|---|---|
| ลดน้ำหนัก | TDEE - deficit | 1.2-1.6 g/kg หรือสูงขึ้นถ้าออกกำลังกาย | น้ำหนักลดตาม trend | deficit สูง/ลดเร็วเกิน |
| ลดไขมันรักษากล้าม | TDEE - moderate deficit | 1.6-2.2 g/kg หรือ advanced ใช้ LBM | fat/weight trend + protein adherence | เสี่ยงเสียกล้ามถ้า protein/training ต่ำ |
| เพิ่มกล้าม | TDEE + small surplus | 1.6-2.2 g/kg | น้ำหนักขึ้นช้า + training consistency | surplus สูงอาจเพิ่มไขมัน |
| Recomposition | TDEE หรือ deficit/surplus เล็ก | 1.6-2.2 g/kg | waist/weight/training trend | progress ช้า ต้องไม่สรุปจากน้ำหนักอย่างเดียว |
| รักษาน้ำหนัก | TDEE | 0.8-1.2 g/kg ทั่วไป หรือ 1.4+ ถ้า active | อยู่ใน range/trend | น้ำหนักแกว่งรายวันไม่ใช่ failure |
| ผู้สูงอายุรักษากล้าม | TDEE หรือ clinician goal | 1.0-1.2 g/kg, ป่วยอาจ 1.2-1.5 | strength/function/weight trend | โรคไต/โรคเรื้อรังต้องปรึกษาผู้เชี่ยวชาญ |

---

## 31. Product Requirement ที่ควรเพิ่มจาก evidence ใหม่นี้

1. เพิ่ม `goal_type` ให้ชัด เช่น `lose_weight`, `gain_muscle`, `maintain_weight`, `preserve_muscle`, `recomposition`
2. แยก `calorie_strategy` ออกจาก `protein_strategy`
3. เพิ่ม `protein_factor_source` เช่น `RDA`, `ISSN`, `Morton`, `ESPEN`, `Helms`
4. ถ้าใช้ body fat percentage ให้เก็บว่า user-input หรือ measured source
5. ถ้าใช้ LBM ต้องเก็บ formula:

```text
lean_body_mass_kg = weight_kg * (1 - body_fat_percent / 100)
```

6. UI ต้องอธิบายว่า:

- เพิ่มกล้ามต้องคู่กับ resistance training
- target protein เป็น estimate
- surplus สูงขึ้นไม่ได้แปลว่าจะได้กล้ามมากขึ้นเสมอ
- maintenance ใช้ range/trend ไม่ใช่น้ำหนักวันเดียว

---

## 32. แหล่งอ้างอิงเพิ่มเติมสำหรับ goal เพิ่มกล้าม/รักษากล้าม/รักษาน้ำหนัก

1. ISSN Position Stand: Protein and Exercise. https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8
2. Morton et al. Protein supplementation meta-analysis/meta-regression. https://elementssystem.com/wp-content/uploads/2018/03/Morton-protein-review.pdf
3. Helms et al. Natural bodybuilding contest preparation. https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/
4. ACSM Progression Models in Resistance Training. https://www.acsm.org/wp-content/uploads/2025/01/Progression-Models-in-Resistance-Training-for-Healthy-Adults.pdf
5. ESPEN protein intake and exercise for optimal muscle function with aging. https://www.sciencedirect.com/science/article/pii/S0261561414001113
6. Protein Intake and Muscle Function in Older Adults. https://pmc.ncbi.nlm.nih.gov/articles/PMC4394186/
7. ESPEN practical guideline: clinical nutrition and hydration in geriatrics. https://www.espen.org/files/ESPEN-Guidelines/ESPEN_practical_guideline_Clinical_nutrition_and_hydration_in_geriatrics.pdf
8. Successful weight loss maintenance systematic review. https://pmc.ncbi.nlm.nih.gov/articles/PMC9105823/
9. Dietary Strategies for Weight Loss Maintenance. https://pmc.ncbi.nlm.nih.gov/articles/PMC6722715/
10. National Weight Control Registry dietary habits. https://pmc.ncbi.nlm.nih.gov/articles/PMC4568993/
11. FAO Food energy conversion factors / Atwater factors. https://www.fao.org/4/y5022e/y5022e04.htm
12. USDA FoodData Central Foundation Foods documentation. https://fdc.nal.usda.gov/Foundation_Foods_Documentation/

---

## 33. TDEE / TEE / EER - งานวิจัยและที่มาของการคำนวณพลังงานรวมต่อวัน

### 33.1 TDEE คืออะไร

TDEE ย่อมาจาก **Total Daily Energy Expenditure** หรือพลังงานรวมที่ร่างกายใช้ต่อวัน

ในงานวิชาการมักใช้คำว่า:

| คำ | ความหมาย | ใช้บริบทไหน |
|---|---|---|
| TEE | Total Energy Expenditure | คำวิชาการทั่วไป หมายถึงพลังงานรวมที่ใช้ |
| TDEE | Total Daily Energy Expenditure | คำที่แอพ fitness/nutrition ใช้บ่อย หมายถึง TEE รายวัน |
| EER | Estimated Energy Requirement | ค่าพลังงานที่คาดว่าต้องกินเพื่อรักษา energy balance |
| PAL | Physical Activity Level | ตัวคูณกิจกรรม = TEE / BMR |

สำหรับผู้ใหญ่ที่ไม่ตั้งครรภ์ ไม่ให้นม และน้ำหนักคงที่:

```text
EER ≈ TDEE ≈ TEE
```

แปลว่าเป็นค่าพลังงานที่ควรกินโดยเฉลี่ยเพื่อรักษาน้ำหนักปัจจุบัน

### 33.2 งานวิจัย/แหล่งอ้างอิงหลักของ TDEE

#### FAO/WHO/UNU Human Energy Requirements

**ลิงก์:** https://www.fao.org/4/y5686e/y5686e00.htm  
**บทที่เกี่ยวข้อง:** https://www.fao.org/4/y5686e/y5686e07.htm

งานนี้เป็น expert consultation report เรื่อง human energy requirements

เขาอธิบายว่า energy requirement ของผู้ใหญ่สามารถประเมินจาก:

```text
TEE = BMR * PAL
```

โดย:

- BMR คือ basal metabolic rate
- PAL คือ physical activity level
- PAL มาจาก total energy expenditure หารด้วย BMR

พูดง่าย ๆ:

```text
PAL = TEE / BMR
TEE = BMR * PAL
```

นี่คือรากฐานของสูตรที่แอพจำนวนมากใช้:

```text
TDEE = BMR * activity_factor
```

เพียงแต่ในแอพมักเรียก PAL ว่า activity factor

#### Institute of Medicine / National Academies - Estimated Energy Requirement

**DRI Energy chapter:** https://www.ncbi.nlm.nih.gov/sites/books/NBK591021/  
**ตารางสมการ EER:** https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/equations-estimate-energy-requirement.html  
**National Academies summary:** https://nap.nationalacademies.org/read/11537/chapter/8

แหล่งนี้สร้างสมการ EER โดยใช้ข้อมูล **doubly labeled water หรือ DLW** ซึ่งเป็นหนึ่งในวิธีมาตรฐานที่ดีที่สุดในการวัด total energy expenditure ในคนใช้ชีวิตจริง

เขาวิจัยเพื่อหาคำตอบว่า:

> คนที่มีอายุ เพศ น้ำหนัก ส่วนสูง และระดับกิจกรรมต่างกัน ต้องการพลังงานเท่าไหร่เพื่อรักษา energy balance

### 33.3 เขาทำวิจัย TDEE/EER อย่างไร

งานกลุ่มนี้ไม่ได้ใช้แค่แบบสอบถามอาหาร เพราะ self-report มี error สูง แต่ใช้ข้อมูลจากการวัด energy expenditure ด้วยวิธีที่น่าเชื่อถือกว่า เช่น:

| วิธี | ใช้วัดอะไร | หมายเหตุ |
|---|---|---|
| Doubly labeled water (DLW) | TEE ในชีวิตจริงหลายวัน | แม่นและใช้ในงาน energy requirement |
| Indirect calorimetry | BMR/REE หรือ energy expenditure ในห้องทดลอง | ใช้วัดตอนพักหรือกิจกรรมเฉพาะ |
| Activity logs / occupation categories | ช่วยจัดระดับกิจกรรม | ใช้ร่วมกับ PAL/PA coefficient |
| Regression analysis | สร้างสมการจาก age/sex/weight/height/activity | ได้ coefficient ในสมการ EER |

### 33.4 TDEE ประกอบด้วยอะไรบ้าง

TDEE ไม่ใช่แค่ BMR แต่เป็นผลรวมของหลายส่วน:

```text
TDEE = BMR/REE + TEF + physical activity + NEAT
```

| องค์ประกอบ | ความหมาย |
|---|---|
| BMR/REE | พลังงานพื้นฐานตอนพัก |
| TEF | Thermic Effect of Food หรือพลังงานที่ใช้ย่อย/ดูดซึมอาหาร |
| Exercise activity | พลังงานจากการออกกำลังกาย |
| NEAT | Non-exercise activity thermogenesis เช่น เดิน ขยับตัว ทำงานบ้าน |

แต่ในแอพ เรามักไม่คำนวณทุกองค์ประกอบแยก เพราะผู้ใช้ไม่มีข้อมูลละเอียดขนาดนั้น จึงใช้วิธี:

```text
TDEE = BMR * activity_factor
```

activity factor จึงเป็นตัวแทนของ TEF + activity + NEAT โดยประมาณ

### 33.5 Activity factor / PAL มาจากไหน

ในงาน FAO/WHO/UNU ใช้แนวคิด PAL:

```text
PAL = TEE / BMR
```

ถ้าคนหนึ่งมี:

```text
BMR = 1600 kcal/day
TEE = 2480 kcal/day
```

จะได้:

```text
PAL = 2480 / 1600 = 1.55
```

ดังนั้น:

```text
TDEE = 1600 * 1.55 = 2480 kcal/day
```

### 33.6 ตัวเลข activity factor 1.2 / 1.375 / 1.55 / 1.725 / 1.9 มาจากไหน

ตัวเลขเหล่านี้เป็นค่าที่แอพและ fitness calculators ใช้กันแพร่หลาย โดยอิงแนวคิด PAL จาก FAO/WHO/UNU และการจัดระดับกิจกรรมแบบเบา-ปานกลาง-หนัก

ควรอธิบายตรง ๆ ว่า:

> activity factor ชุดนี้เป็น practical approximation ที่ดัดแปลงจากแนวคิด PAL ไม่ใช่สมการเฉพาะบุคคลที่วัดจากร่างกายโดยตรง

ตารางที่ใช้ในแอพได้:

| Activity factor | ความหมายในแอพ | ตัวอย่าง |
|---|---|---|
| 1.2 | sedentary | นั่งทำงานส่วนใหญ่ ไม่ค่อยออกกำลังกาย |
| 1.375 | lightly active | ออกกำลังกายเบา 1-3 วัน/สัปดาห์ |
| 1.55 | moderately active | ออกกำลังกายปานกลาง 3-5 วัน/สัปดาห์ |
| 1.725 | very active | ออกกำลังกายหนัก 6-7 วัน/สัปดาห์ |
| 1.9 | extra active | ใช้แรงงานหนัก/ฝึกหนักมาก |

ข้อควรระวัง:

- ตัวเลขนี้ไม่แม่นทุกคน
- คนสองคนออกกำลังกายเท่ากันแต่ NEAT ต่างกันมากได้
- ถ้าใช้ Health Connect active calories ต้องระวัง double counting

### 33.7 สมการ EER ของ Institute of Medicine ต่างจาก TDEE = BMR * factor อย่างไร

IOM/National Academies ใช้สมการ EER ที่รวม age, sex, weight, height, และ PA coefficient โดยตรง ไม่ได้ให้ผู้ใช้คำนวณ BMR ก่อนแล้วคูณ factor แบบง่าย

ตัวอย่างสำหรับผู้ใหญ่:

```text
ผู้ชาย:
EER = 662 - (9.53 * age) + PA * [(15.91 * weight_kg) + (539.6 * height_m)]

ผู้หญิง:
EER = 354 - (6.91 * age) + PA * [(9.36 * weight_kg) + (726 * height_m)]
```

สูตรนี้มาจาก regression บนข้อมูล energy expenditure ที่รวม physical activity coefficient

ความหมายของตัวเลข:

| ตัวเลข | มาจากอะไร |
|---|---|
| 662 / 354 | intercept ของสมการแยกเพศ |
| 9.53 / 6.91 | age coefficient |
| 15.91 / 9.36 | weight coefficient |
| 539.6 / 726 | height coefficient |
| PA | physical activity coefficient |

### 33.8 แล้ว Calories Guard ควรใช้วิธีไหน

สำหรับแอพทั่วไป มี 2 แนวทาง:

#### ทางเลือก A: BMR/REE * activity factor

```text
BMR = Mifflin-St Jeor
TDEE = BMR * activity_factor
```

ข้อดี:

- อธิบายง่าย
- ผู้ใช้เข้าใจได้
- ใช้กันแพร่หลายใน nutrition/fitness app
- ปรับ activity factor ได้ง่าย

ข้อเสีย:

- activity factor เป็นค่าหยาบ
- ไม่แยก NEAT/exercise ชัด
- อาจ double-count ถ้าบวก wearable calories ซ้ำ

#### ทางเลือก B: IOM EER equation

```text
EER = sex-specific equation(age, weight, height, PA)
```

ข้อดี:

- มีฐานจาก DRI/National Academies
- สร้างจากข้อมูล energy expenditure โดยตรง
- ไม่ต้องคำนวณ BMR แยก

ข้อเสีย:

- อธิบายยากกว่า
- PA coefficient ต้องเลือกให้เหมาะ
- ผู้ใช้ทั่วไปอาจไม่คุ้น

### 33.9 Recommendation สำหรับ Calories Guard

เพื่อความเข้าใจง่ายและคง consistency กับแอพปัจจุบัน:

1. ใช้ Mifflin-St Jeor เพื่อคำนวณ BMR/REE โดยประมาณ
2. ใช้ activity factor/PAL เพื่อคำนวณ TDEE
3. เก็บ source และ version:

```text
bmr_formula = "mifflin_st_jeor"
tdee_method = "bmr_times_activity_factor"
activity_factor_source = "PAL/practical activity-factor approximation"
```

4. แสดง UI ว่า:

```text
TDEE คือพลังงานรวมต่อวันที่ประมาณจากพลังงานพื้นฐานและระดับกิจกรรมของคุณ
```

5. ถ้ามี Health Connect:

```text
do not automatically add all active calories if activity factor already includes exercise
```

### 33.10 ตัวอย่างคำนวณ TDEE แบบละเอียด

ผู้ใช้:

```text
เพศ: ชาย
อายุ: 25 ปี
น้ำหนัก: 70 kg
ส่วนสูง: 175 cm
กิจกรรม: moderately active
activity_factor = 1.55
```

คำนวณ BMR:

```text
BMR = 10W + 6.25H - 5A + 5
BMR = 10(70) + 6.25(175) - 5(25) + 5
BMR = 700 + 1093.75 - 125 + 5
BMR = 1673.75 kcal/day
```

คำนวณ TDEE:

```text
TDEE = BMR * activity_factor
TDEE = 1673.75 * 1.55
TDEE = 2594.31 kcal/day
```

ถ้าเป้าหมายรักษาน้ำหนัก:

```text
target = 2594 kcal/day
```

ถ้าเป้าหมายลดน้ำหนักแบบ moderate deficit 500 kcal:

```text
target = 2594 - 500 = 2094 kcal/day
```

ถ้าเป้าหมายเพิ่มกล้ามแบบ small surplus 200 kcal:

```text
target = 2594 + 200 = 2794 kcal/day
```

### 33.11 TDEE กับ wearable calories ต้องระวังอะไร

ถ้าผู้ใช้เลือก activity factor = 1.55 แปลว่า TDEE รวมกิจกรรมระดับหนึ่งแล้ว

ถ้าแอพนำ active calories จาก Health Connect มาบวกเพิ่มทุกวัน:

```text
wrong_target = BMR * 1.55 + wearable_active_calories
```

อาจเกิด double counting

แนวทางที่ควรใช้:

| Mode | วิธีคำนวณ |
|---|---|
| Activity factor mode | TDEE = BMR * activity_factor, wearable ใช้แสดงประกอบ |
| Sedentary + exercise mode | TDEE = BMR * 1.2 + adjusted_exercise_calories |
| Hybrid cautious mode | TDEE = BMR * activity_factor + partial adjustment เฉพาะวันที่ activity สูงผิดปกติ |

ข้อกำหนดในแอพ:

- ต้องเก็บ `tdee_mode`
- ต้องเก็บ `activity_factor`
- ถ้าบวก wearable calories ต้องมี `exercise_adjustment_policy`
- ต้อง label active calories ว่า estimate

### 33.12 QA Test สำหรับ TDEE

| Case | Expected |
|---|---|
| Profile male/female | BMR ตรงสูตร Mifflin |
| เลือก activity factor 1.55 | TDEE = BMR * 1.55 |
| เป้าหมายลดน้ำหนัก | target = TDEE - deficit |
| เป้าหมายเพิ่มกล้าม | target = TDEE + surplus |
| เป้าหมายรักษาน้ำหนัก | target = TDEE |
| มี Health Connect active calories | ไม่ double count ถ้าใช้ activity factor mode |
| Flutter fallback | ต้อง label ว่า estimated preview |
| Backend value exists | Flutter ต้องแสดง backend TDEE ก่อน |

### 33.13 แหล่งอ้างอิง TDEE/EER/PAL

1. FAO/WHO/UNU Human Energy Requirements report. https://www.fao.org/4/y5686e/y5686e00.htm
2. FAO Human Energy Requirements - Adults/PAL chapter. https://www.fao.org/4/y5686e/y5686e07.htm
3. FAO Human Energy Requirements - Principles and definitions. https://www.fao.org/4/y5686e/y5686e04.htm
4. National Academies / NCBI Bookshelf. Development of Prediction Equations for Estimated Energy Requirements. https://www.ncbi.nlm.nih.gov/sites/books/NBK591021/
5. Health Canada DRI table: Equations to estimate energy requirement. https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/equations-estimate-energy-requirement.html
6. National Academies DRI essential guide, energy chapter. https://nap.nationalacademies.org/read/11537/chapter/8
7. Westerterp. Physical activity and physical activity induced energy expenditure in humans. https://pmc.ncbi.nlm.nih.gov/articles/PMC3636460/

---

## 34. BMI - งานวิจัยและการนำไปใช้เพื่อบอกระดับความเสี่ยงเบื้องต้น

### 34.1 BMI คืออะไร

BMI ย่อมาจาก **Body Mass Index** หรือดัชนีมวลกาย เป็นสูตรที่ใช้ดูว่าน้ำหนักของผู้ใช้เหมาะสมกับส่วนสูงหรือไม่

สูตร:

```text
BMI = weight_kg / (height_m ^ 2)
```

ตัวอย่าง:

```text
น้ำหนัก = 70 kg
ส่วนสูง = 175 cm = 1.75 m

BMI = 70 / (1.75 ^ 2)
BMI = 70 / 3.0625
BMI = 22.86 kg/m²
```

### 34.2 งานวิจัย/แหล่งอ้างอิงหลักของ BMI

#### WHO - Obesity and Overweight

**ลิงก์:** https://www.who.int/en/news-room/fact-sheets/detail/obesity-and-overweight  
**WHO BMI data:** https://www.who.int/data/gho/data/themes/topics/indicator-groups/GHO/bmi-among-adults

WHO ใช้ BMI เป็น screening tool เพื่อจัดระดับ underweight, overweight และ obesity ในผู้ใหญ่

เกณฑ์ผู้ใหญ่ทั่วไป:

| BMI | ความหมายตาม WHO |
|---|---|
| < 18.5 | Underweight |
| 18.5-24.9 | Normal / healthy range |
| 25.0-29.9 | Overweight |
| >= 30.0 | Obesity |

#### CDC - Adult BMI Categories

**ลิงก์:** https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html

CDC ใช้ BMI เป็นวิธีคัดกรองที่ง่ายและต้นทุนต่ำ แต่ระบุชัดว่า BMI ไม่ได้วัด body fat โดยตรง

#### WHO Expert Consultation - Asian BMI risk

**ชื่อ:** Appropriate body-mass index for Asian populations and its implications for policy and intervention strategies  
**ลิงก์ PubMed:** https://pubmed.ncbi.nlm.nih.gov/14726171/  
**DOI:** https://doi.org/10.1016/S0140-6736(03)15268-3

งานนี้สำคัญมากสำหรับผู้ใช้ไทย/เอเชีย เพราะพบว่าในหลายประชากรเอเชีย ความเสี่ยงเบาหวานชนิดที่ 2 และโรคหัวใจหลอดเลือดเพิ่มขึ้นที่ BMI ต่ำกว่าเกณฑ์ overweight 25 ของ WHO ทั่วโลก

งานนี้ไม่ได้บอกให้เปลี่ยนเกณฑ์ WHO สากลทั้งหมด แต่เสนอ **public health action points** สำหรับเอเชีย เช่น:

| BMI | ความหมายเชิง action point สำหรับหลายประชากรเอเชีย |
|---|---|
| 23.0 ขึ้นไป | เริ่มมีความเสี่ยงเพิ่ม ควรเริ่มให้คำแนะนำ/ติดตาม |
| 27.5 ขึ้นไป | ความเสี่ยงสูงขึ้นมาก ควรมีการประเมินจริงจังขึ้น |

ข้อสำคัญ:

> สำหรับผู้ใช้ไทย แอพควรมี option หรือ note ว่า Asian risk threshold อาจเริ่มเตือนตั้งแต่ BMI 23 ไม่ใช่รอถึง 25 เสมอ

### 34.3 เขาวิจัย BMI ไปทำไม

BMI ถูกใช้เพราะ:

- คำนวณง่าย
- ใช้แค่ weight และ height
- ใช้คัดกรองประชากรจำนวนมากได้
- สัมพันธ์กับความเสี่ยงสุขภาพในระดับประชากร เช่น เบาหวาน ความดัน โรคหัวใจ

แต่ BMI ไม่ได้ถูกสร้างมาเพื่อบอกองค์ประกอบร่างกายอย่างละเอียด เช่น:

- กล้ามเนื้อเท่าไหร่
- ไขมันเท่าไหร่
- ไขมันอยู่บริเวณหน้าท้องหรือไม่

### 34.4 ใช้ formula/matrix อะไร

สูตร BMI:

```text
BMI = weight_kg / height_m²
```

classification matrix:

| Input | Process | Output |
|---|---|---|
| weight_kg | คำนวณ BMI | BMI number |
| height_m | เทียบกับ cut-off | BMI category |
| region/ethnicity setting | เลือก global หรือ Asian action points | risk message |
| waist circumference ถ้ามี | เพิ่มความแม่นด้าน cardiometabolic risk | risk note |

### 34.5 ตัวเลข 18.5 / 25 / 30 มาจากอะไร

ตัวเลขเหล่านี้เป็น cut-off ทางระบาดวิทยาและ public health ที่ WHO ใช้เพื่อจำแนกความเสี่ยงในระดับประชากร

| ตัวเลข | ความหมาย | เหตุผล |
|---|---|---|
| 18.5 | ขอบล่างของ normal range | ต่ำกว่านี้สัมพันธ์กับ undernutrition/health risk ในหลายบริบท |
| 25 | จุดเริ่ม overweight | ความเสี่ยง metabolic/cardiovascular เริ่มเพิ่มขึ้นในประชากรทั่วไป |
| 30 | obesity | ความเสี่ยงโรคเรื้อรังสูงขึ้นชัดเจน |

แต่สำหรับเอเชีย WHO Expert Consultation พบว่า risk อาจเริ่มที่ BMI ต่ำกว่า 25 จึงเสนอ action point เช่น 23 และ 27.5

### 34.6 BMI บอกว่า “อันตรายไหม” ได้แค่ไหน

BMI ใช้เป็น **screening** ไม่ใช่ diagnosis

แปลว่า:

- BMI สูงไม่ได้แปลว่าผู้ใช้ป่วยแน่นอน
- BMI ปกติไม่ได้แปลว่าผู้ใช้สุขภาพดีแน่นอน
- คนมีกล้ามมากอาจ BMI สูงแต่ไขมันไม่สูง
- คน BMI ปกติแต่อ้วนลงพุงอาจมี cardiometabolic risk

ดังนั้นข้อความในแอพควรเป็น:

```text
BMI ของคุณอยู่ในช่วง ... ซึ่งอาจสัมพันธ์กับความเสี่ยง ... ควรใช้ร่วมกับรอบเอว ประวัติสุขภาพ และคำแนะนำจากผู้เชี่ยวชาญ
```

ไม่ควรเขียนว่า:

```text
คุณอันตรายแล้ว / คุณเป็นโรคอ้วนแน่นอน / คุณสุขภาพดีแน่นอน
```

### 34.7 ควรใช้ BMI คู่กับ waist circumference

**NHLBI disease risk table:** https://www.nhlbi.nih.gov/health/educational/lose_wt/BMI/bmi_dis  
**NHLBI symptoms/diagnosis:** https://www.nhlbi.nih.gov/health/overweight-and-obesity/symptoms

NHLBI แนะนำให้ใช้ BMI ร่วมกับ waist circumference เพื่อประเมิน risk ได้ดีขึ้น เพราะไขมันหน้าท้องสัมพันธ์กับความเสี่ยง metabolic/cardiovascular

ตัวอย่าง:

| ข้อมูล | ใช้บอกอะไร |
|---|---|
| BMI | น้ำหนักสัมพันธ์กับส่วนสูง |
| waist circumference | ไขมันหน้าท้อง/central adiposity |
| weight trend | ทิศทางการเปลี่ยนแปลง |
| health markers | ความดัน น้ำตาล ไขมันเลือด |

ข้อกำหนดในแอพ:

- ถ้ามีเฉพาะ BMI ให้ label ว่า screening
- ถ้ามี waist circumference ให้แสดง risk context เพิ่ม
- อย่าใช้ BMI เดี่ยว ๆ เป็นคำวินิจฉัย

### 34.8 BMI สำหรับเด็ก วัยรุ่น ตั้งครรภ์ และนักกีฬา

Calories Guard ต้องระวังกลุ่มเหล่านี้:

| กลุ่ม | ทำไม BMI ผู้ใหญ่ใช้ตรง ๆ ไม่เหมาะ |
|---|---|
| เด็ก/วัยรุ่น | ต้องใช้ BMI-for-age percentile ไม่ใช่ adult cut-off |
| ตั้งครรภ์ | น้ำหนักเปลี่ยนตามการตั้งครรภ์ |
| นักกีฬา/คนกล้ามมาก | BMI สูงจากกล้าม ไม่ใช่ไขมัน |
| ผู้สูงอายุ | muscle loss ทำให้ BMI ปกติแต่เสี่ยง sarcopenia ได้ |
| คนมีบวมน้ำ/โรคบางอย่าง | น้ำหนักสะท้อนน้ำคั่ง ไม่ใช่ไขมัน |

ข้อกำหนด:

- ถ้าแอพรองรับเฉพาะผู้ใหญ่ทั่วไป ต้องเขียน scope ให้ชัด
- หากผู้ใช้เลือกอายุต่ำกว่า 18 ปี ควรไม่ใช้ adult BMI classification
- หากตั้งครรภ์หรือมีโรคเฉพาะ ควรแนะนำปรึกษาผู้เชี่ยวชาญ

### 34.9 Calories Guard ควรใช้ BMI อย่างไร

ฟีเจอร์ที่ควรมี:

1. คำนวณ BMI จากน้ำหนักและส่วนสูง
2. แสดง BMI category
3. แสดง Asian risk note สำหรับผู้ใช้ไทย/เอเชีย
4. แสดงคำอธิบายว่า BMI เป็น screening tool
5. แนะนำให้ใช้ร่วมกับ waist circumference และ trend
6. ใช้ BMI เพื่อช่วยเลือก goal mode เบื้องต้น แต่ไม่บังคับ

ตัวอย่าง UI copy:

```text
BMI ของคุณ: 22.9 kg/m²
อยู่ในช่วงปกติตามเกณฑ์ WHO สำหรับผู้ใหญ่ทั่วไป

หมายเหตุ: สำหรับประชากรเอเชีย ความเสี่ยงบางอย่างอาจเริ่มเพิ่มตั้งแต่ BMI ประมาณ 23 ขึ้นไป BMI เป็นเพียงตัวคัดกรอง ควรดูร่วมกับรอบเอว พฤติกรรมสุขภาพ และผลตรวจสุขภาพ
```

### 34.10 BMI formula/version ที่ควรบันทึกใน backend

ควรเก็บ:

```text
bmi_value
bmi_formula = "weight_kg / height_m_squared"
bmi_category_standard = "WHO_global" หรือ "WHO_asian_action_points"
height_cm
weight_kg
calculated_at
age_at_calculation
is_adult_classification_used
```

ถ้ามี waist:

```text
waist_cm
waist_source
waist_recorded_at
```

### 34.11 QA Test สำหรับ BMI

| Case | Expected |
|---|---|
| 70 kg, 175 cm | BMI = 22.86 |
| BMI < 18.5 | category underweight |
| BMI 18.5-24.9 | category normal/global |
| BMI 25-29.9 | category overweight/global |
| BMI >= 30 | category obesity/global |
| Asian mode BMI 23 | show increased-risk action note |
| Asian mode BMI 27.5 | show higher-risk action note |
| age < 18 | do not use adult BMI category |
| missing height | cannot calculate BMI, show setup needed |
| athlete mode | show limitation note |

### 34.12 แหล่งอ้างอิง BMI

1. WHO Obesity and overweight fact sheet. https://www.who.int/en/news-room/fact-sheets/detail/obesity-and-overweight
2. WHO BMI among adults data. https://www.who.int/data/gho/data/themes/topics/indicator-groups/GHO/bmi-among-adults
3. CDC Adult BMI Categories. https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html
4. WHO Expert Consultation. Appropriate body-mass index for Asian populations. https://pubmed.ncbi.nlm.nih.gov/14726171/
5. DOI for WHO Expert Consultation. https://doi.org/10.1016/S0140-6736(03)15268-3
6. NHLBI BMI, waist circumference and disease risk table. https://www.nhlbi.nih.gov/health/educational/lose_wt/BMI/bmi_dis
7. NHLBI Overweight and obesity symptoms/diagnosis. https://www.nhlbi.nih.gov/health/overweight-and-obesity/symptoms

---

## 35. Research Gap Audit - ตอนนี้ยังขาดงานวิจัยหมวดไหนอีก

หลังจากเพิ่ม BMI แล้ว หลักฐานของ Calories Guard ครอบคลุมแกนหลักมากขึ้น แต่ยังมีบางหมวดที่ควรเพิ่มหากต้องการให้เอกสาร “แน่น” สำหรับกรรมการหรือ production safety

### 35.1 Gap Summary

| หมวดที่ยังขาด/ควรเพิ่ม | สถานะตอนนี้ | ทำไมสำคัญ | ควรเพิ่มอะไร |
|---|---|---|---|
| BMI/body composition/waist | เพิ่ม BMI แล้ว แต่ body fat/waist ยังไม่ละเอียด | BMI อย่างเดียวอาจ misclassify นักกีฬา/คนอ้วนลงพุง | งาน waist-to-height ratio, body fat %, central obesity |
| Eating disorder / disordered eating safety | ยังมีแค่เตือนเชิงทั่วไป | calorie tracking อาจกระตุ้นพฤติกรรมหมกมุ่นในบางคน | งานวิจัยเรื่อง calorie tracking กับ eating disorder risk |
| Pregnancy/lactation | ยังไม่ได้รองรับ | สูตร BMR/TDEE และ weight goal ต่างจากผู้ใหญ่ทั่วไป | guideline โภชนาการหญิงตั้งครรภ์/ให้นม |
| Children/adolescents | ยังไม่ได้รองรับ | BMI และ nutrition targets ต้องใช้ percentile/age-sex specific | WHO/CDC BMI-for-age, pediatric nutrition guidance |
| Diabetes/CKD/clinical nutrition | มี AI no-diagnosis แต่ยังไม่มี guideline โรคเฉพาะ | ผู้ใช้บางคนอาจถามอาหารสำหรับโรค | ADA diabetes nutrition, kidney disease protein caution |
| Sodium/sugar/fiber/micronutrients | เน้น kcal/protein/carb/fat | แอพโภชนาการควรมีคุณภาพอาหาร ไม่ใช่แค่แคลอรี | WHO sodium/sugar, fiber DRI, Thai nutrition label guidance |
| Food allergies and intolerances | ยังไม่มี | recipe/AI suggestion อาจแนะนำอาหารแพ้ | allergy safety UX, allergen labeling |
| Thai dietary guidelines | มี ThaiFCD แต่ยังไม่มี guideline การกินของไทย | ช่วยให้คำแนะนำเหมาะกับผู้ใช้ไทย | Thai food-based dietary guidelines / nutrition flag |
| Portion-size estimation | มี AI food recognition แต่ portion ยังไม่ลึก | calorie error มักเกิดจาก portion | งาน portion estimation, household measure conversion |
| Long-term retention/user study | มี app behavior research แต่ไม่ใช่ของ Calories Guard | ต้องพิสูจน์กับผู้ใช้จริง | pilot study protocol และ analytics metrics |
| Data retention/deletion policy | มี privacy/security แล้วแต่ยังไม่ลงรายละเอียด retention | health data ต้องมี lifecycle | policy/standard เรื่อง retention, deletion, audit |
| Bias/fairness in AI Thai language | มี WHO/NIST แต่ยังไม่เจาะภาษาไทย | AI ภาษาไทยอาจตอบผิด/หลุด scope | Thai prompt benchmark, human evaluation rubric |

### 35.2 หมวดที่ควรเพิ่มเป็นลำดับถัดไป

ถ้าต้องเลือกเพิ่มเฉพาะที่สำคัญที่สุด ผมแนะนำ 5 หมวดนี้:

1. **BMI + waist/body composition**
   - เพราะใช้บอกผู้ใช้ว่าอยู่ระดับไหนและเสี่ยงไหม
   - ควรเพิ่ม waist circumference เพื่อไม่พึ่ง BMI เดี่ยว ๆ

2. **Eating disorder safety**
   - เพราะ calorie tracking มีความเสี่ยงด้านพฤติกรรมในผู้ใช้บางกลุ่ม
   - ควรมี safe copy, opt-out, gentle reminders

3. **Clinical exclusion / medical boundary**
   - เพราะ AI coach และ nutrition target อาจถูกเข้าใจว่าเป็นคำแนะนำทางการแพทย์
   - ต้องมี disclaimer สำหรับ pregnancy, CKD, diabetes, eating disorder, age < 18

4. **Thai dietary guideline**
   - เพราะ ThaiFCD เป็นข้อมูลสารอาหาร แต่ไม่ได้บอก pattern การกินที่เหมาะสม
   - ควรหา guideline ไทยเพื่อรองรับคำแนะนำเชิงอาหารไทย

5. **Internal validation protocol**
   - เพราะงานวิจัยภายนอกสนับสนุน concept แต่ยังไม่ได้พิสูจน์แอพเรา
   - ควรวัด retention, food-log accuracy, AI correction rate, goal adherence

### 35.3 Research-to-Feature Gap Matrix

| Feature | Evidence covered? | Missing evidence | Product action |
|---|---|---|---|
| Food logging | ครอบคลุมดี | Thai user adherence เฉพาะบริบท | ทำ pilot study |
| BMR/TDEE | ครอบคลุมดี | validation กับผู้ใช้ไทย/คนกล้ามมาก | label estimate + trend adjustment |
| BMI | เพิ่มแล้ว | waist/body fat adjunct | เพิ่ม waist field ในอนาคต |
| Macro/protein | ครอบคลุมดีสำหรับ adult/general/active | clinical disease-specific targets | medical boundary |
| Muscle gain | เพิ่มแล้ว | surplus optimum ยังไม่แน่นอน | ใช้ small surplus + trend |
| Maintain weight | เพิ่มแล้ว | maintenance range เป็น heuristic | ให้ผู้ใช้ปรับ range |
| Water | มี EFSA | Thai climate/activity personalization | allow edit + no medical claim |
| Ingredients/recipes | ครอบคลุมดี | yield/retention data ของอาหารไทย | source confidence |
| AI coach | ครอบคลุม governance | Thai benchmark | สร้าง test prompt set |
| Gamification | ครอบคลุม moderate | ผล long-term ในแอพเรา | A/B test |
| Security/privacy | ครอบคลุมดี | retention/deletion policy รายละเอียด | policy + audit |
| Accessibility | ครอบคลุมหลัก | Thai screen-reader/user testing | usability test |

### 35.4 คำตอบสำหรับกรรมการถ้าถามว่า “ยังขาดอะไรไหม”

ตอบได้ว่า:

> งานวิจัยปัจจุบันครอบคลุมแกนหลักของแอพ ได้แก่ self-monitoring, BMR/TDEE, macro/protein, BMI, food composition, recipe calculation, AI safety, gamification, privacy/security และ accessibility อย่างไรก็ตาม ยังมีงานที่ควรเพิ่มในอนาคต เช่น eating-disorder safety, pregnancy/adolescent exclusion, Thai dietary guideline, waist/body composition และ validation study กับผู้ใช้จริงของ Calories Guard

นี่เป็นคำตอบที่ตรงและน่าเชื่อถือ เพราะไม่ได้อ้างว่าเอกสารสมบูรณ์เกินจริง แต่แสดงให้เห็นว่าเรารู้ข้อจำกัดและมีแผนจัดการ
