# เอกสารอ้างอิงงานวิจัยสำหรับ Calories Guard

**วันที่:** 6 พฤษภาคม 2569  
**บทบาท:** Senior Researcher and Analytics  
**ขอบเขต:** แอพ Calories Guard ทั้งฝั่งผู้ใช้, แอดมิน, backend, สูตรคำนวณ, ฐานข้อมูลอาหาร, AI coach, gamification, privacy/security และ QA

## 1. สรุปภาพรวม

แอพ Calories Guard สามารถอ้างอิงเชิงวิชาการได้ หากออกแบบและใช้งานตามหลักสำคัญต่อไปนี้:

1. ค่าพลังงาน เป้าหมายแคลอรี สารอาหาร และ progress ต้องยึดค่าที่ backend คำนวณและบันทึกไว้เป็นหลัก
2. ค่าที่มาจาก AI, wearable, water target, portion estimate หรือสูตรคำนวณทั่วไป ต้องแสดงว่าเป็น “ค่าประมาณ”
3. ข้อมูลอาหารและสูตรอาหารต้องมี source, version และ snapshot เพื่อไม่ให้ประวัติผู้ใช้เปลี่ยนย้อนหลังเมื่อแอดมินแก้เมนู
4. AI ต้องเป็นผู้ช่วย ไม่ใช่แพทย์ ไม่ควรวินิจฉัยโรคหรือสั่งการรักษา และต้องให้ผู้ใช้ยืนยันก่อนบันทึกข้อมูลอาหารจาก AI
5. Gamification ควรใช้เพื่อเพิ่มแรงจูงใจแบบสนับสนุน เช่น streak recovery, badge, pet progression, mission ไม่ใช่การลงโทษหรือทำให้ผู้ใช้รู้สึกผิด
6. ข้อมูลสุขภาพ โภชนาการ น้ำหนัก และ AI chat ต้องถือเป็นข้อมูลอ่อนไหว ต้องมี privacy, consent, security และ data deletion/export
7. อาหารไทยควรอ้างอิง ThaiFCD, ASEAN Food Composition Database, FAO/INFOODS และแหล่งข้อมูลที่มี provenance ชัดเจน

ข้อสำคัญ: งานวิจัยเหล่านี้ไม่ได้พิสูจน์ว่าแอพของเราทำให้ผู้ใช้ลดน้ำหนักได้แน่นอน แต่ช่วยยืนยันว่าแนวทางของแอพ “สอดคล้องกับหลักฐานทางวิชาการ” และมี guardrail ที่เหมาะสม

## 2. วิธีให้ระดับความน่าเชื่อถือของหลักฐาน

| ระดับ | ความหมาย |
|---|---|
| Strong | มี guideline, official standard, systematic review หรือแหล่งข้อมูลทางการรองรับ ใช้เป็นข้อกำหนดหลักของระบบได้ |
| Moderate | มีหลักฐานดี แต่ยังมีข้อจำกัด เช่น กลุ่มตัวอย่างไม่ตรงกับผู้ใช้ไทย หรือผลลัพธ์ขึ้นกับบริบท |
| Limited | เป็นงานวิจัยขนาดเล็ก งานทดลอง หรือหลักฐานยังใหม่ ใช้ได้แต่ควรติดตามผล |
| Mixed | งานวิจัยให้ผลไม่ตรงกัน ต้องใช้แนวทาง conservative และให้ผู้ใช้ควบคุมได้ |
| Not enough evidence | หลักฐานยังไม่พอ ห้ามอ้างผลลัพธ์แรง ต้องทดสอบกับผู้ใช้จริงเพิ่มเติม |

## 3. ตารางสรุปงานวิจัยและการนำไปใช้กับแอพ

| ส่วนของแอพ | งานวิจัย/แหล่งอ้างอิง | ทำไมเลือกงานนี้ | สรุปเนื้อหา | ระดับหลักฐาน | สิ่งที่แอพควรทำ |
|---|---|---|---|---|---|
| Food logging / self-monitoring | Burke et al. systematic review: https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/ | เป็นงาน review สำคัญเรื่องการบันทึกอาหาร น้ำหนัก และกิจกรรม | การ self-monitoring มีความสัมพันธ์กับผลลัพธ์การควบคุมน้ำหนักที่ดีขึ้น แต่ผู้ใช้จะเลิกใช้ถ้าการบันทึกยุ่งยาก | Strong | ระบบบันทึกอาหารต้องเร็ว แก้ไขได้ ค้นหาได้ และเลือกวันที่ได้ถูกต้อง |
| Digital dietary self-monitoring | Patel et al.: https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/ | ตรงกับแอพมือถือที่ให้ผู้ใช้บันทึกอาหาร | การบันทึกบ่อยและมี feedback ช่วยเพิ่ม adherence และสนับสนุน weight-loss behavior | Strong | dashboard ต้องแสดง progress รายวัน เป้าหมาย และข้อมูลที่ยังไม่ครบอย่างชัดเจน |
| Mobile health app behavior change | JMIR systematic review: https://mhealth.jmir.org/2020/3/e17046/ | ครอบคลุมแอพสุขภาพที่ใช้เปลี่ยนพฤติกรรม | แอพช่วยเปลี่ยนพฤติกรรมได้ดีขึ้นเมื่อมี goal, self-monitoring, feedback และ usability ดี | Moderate | แอพควรมี goal setting, feedback, reminder, dashboard และ user control |
| Diet/physical activity apps | Schoeppe et al.: https://pmc.ncbi.nlm.nih.gov/articles/PMC5142356/ | ใช้ดู evidence ของ app intervention ใน diet และ activity | แอพบางรูปแบบช่วยปรับพฤติกรรมได้ โดยเฉพาะเมื่อมี feedback, reinforcement, reward | Moderate | gamification ควรสนับสนุนพฤติกรรม ไม่ควรแทนที่การคำนวณโภชนาการที่ถูกต้อง |
| BMR / resting energy expenditure | Mifflin et al. 1990: https://doi.org/10.1093/ajcn/51.2.241 | เป็นงานต้นฉบับของสูตร Mifflin-St Jeor | สูตรคำนวณ resting energy expenditure จากน้ำหนัก ส่วนสูง อายุ และเพศ | Strong สำหรับค่าประมาณทั่วไป | backend ต้องบันทึกสูตร เวอร์ชันสูตร และ input ที่ใช้คำนวณ |
| Validation ของ BMR | Frankenfield et al.: https://pubmed.ncbi.nlm.nih.gov/15883556/ | เปรียบเทียบสูตร BMR หลายสูตร | Mifflin-St Jeor เป็นหนึ่งในสูตรที่แม่นกว่าในผู้ใหญ่ทั่วไป แต่ยังมี error ได้ | Strong with caveats | ห้ามแสดงว่าเป็นค่าที่แม่น 100% ต้องใช้คำว่า estimated |
| สูตร Harris-Benedict | Harris and Benedict: https://pubmed.ncbi.nlm.nih.gov/16576330/ | เป็นสูตรคลาสสิก ใช้เป็น baseline ทางประวัติศาสตร์ | สูตรเก่าและยังถูกอ้างอิงบ่อย แต่ไม่จำเป็นต้องเป็น default ที่ดีที่สุด | Moderate | ถ้าใช้หรือแสดง ต้องระบุชื่อสูตรให้ชัด |
| เป้าหมายการลดน้ำหนัก | CDC: https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html | แหล่ง public health ที่น่าเชื่อถือ | CDC สนับสนุนการลดน้ำหนักแบบค่อยเป็นค่อยไปและ realistic | Strong | ระบบควรเตือนเมื่อผู้ใช้ตั้งเป้าหมายลดเร็วหรือ deficit สูงเกินไป |
| Energy deficit | ADA criteria PDF: https://diabetes.org/sites/default/files/2023-09/Weight%20Loss%20Program%20Criteria.pdf | ใช้รองรับแนวทาง calorie deficit แบบปลอดภัย | โปรแกรมควบคุมน้ำหนักมักใช้ deficit ประมาณ 500-750 kcal/day พร้อม lifestyle support | Moderate-Strong | default deficit ควร conservative และไม่แนะนำ very low-calorie diet |
| Macronutrient ranges | National Academies DRI: https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids | เป็นแหล่งอ้างอิงทางการของ macro range | ช่วง AMDR ผู้ใหญ่: carb 45-65%, fat 20-35%, protein 10-35% ของพลังงาน | Strong | macro default ควรอยู่ในช่วงนี้ เว้นแต่ผู้ใช้ตั้ง custom |
| DRI reference tables | NCBI Bookshelf: https://www.ncbi.nlm.nih.gov/books/NBK208874/ | ใช้อ้างอิงค่าพลังงานและสารอาหารเชิงประชากร | ค่า DRI เป็นค่าอ้างอิง ไม่ใช่คำสั่งเฉพาะรายบุคคล | Strong | UI ต้องแยกคำว่า target, estimate, recommendation ให้ชัด |
| Behavior Change Technique | Michie et al. BCT Taxonomy: https://doi.org/10.1007/s12160-013-9486-6 | เป็น framework มาตรฐานสำหรับพฤติกรรมสุขภาพ | เทคนิคสำคัญได้แก่ goal setting, self-monitoring, feedback, prompts, rewards | Strong | map ฟีเจอร์ของแอพกับ BCT เช่น logging, dashboard, badge, reminder |
| Water target | EFSA water DRV: https://www.efsa.europa.eu/en/efsajournal/pub/1459 | เป็นแหล่งอ้างอิงทางการเรื่องน้ำ | ปริมาณน้ำที่เหมาะสมขึ้นกับเพศ อายุ อากาศ กิจกรรม และรวมน้ำจากอาหารด้วย | Strong | ไม่ควรใช้กฎ “8 แก้ว” แบบตายตัว ต้องให้แก้ไขได้และระบุว่าเป็นค่าประมาณ |
| Dietary reference values | EFSA DRV topic: https://www.efsa.europa.eu/en/topics/topic/dietary-reference-values | อธิบายหลักการ AI/PRI/DRV | ค่า adequate intake ไม่ใช่คำสั่งทางการแพทย์ | Strong | water logging ต้องผูกกับวันที่ผู้ใช้เลือกและ timezone |
| Food composition governance | FAO/INFOODS standards: https://www.fao.org/infoods/infoods/standards-guidelines/en/ | เป็นมาตรฐานหลักของฐานข้อมูลอาหาร | ข้อมูลอาหารต้องมี source, unit, conversion, documentation และ data check | Strong | ingredient/food ต้องมี source, unit basis, nutrient basis, version |
| Recipe calculation | FAO chapter: https://www.fao.org/4/y4705e/y4705e06.htm | รองรับการคำนวณอาหารจากสูตรและวัตถุดิบ | recipe nutrition ควรคำนวณจาก ingredient quantity, yield factor, retention factor | Strong | สูตรอาหารต้องคำนวณจาก ingredients ไม่ใช่ข้อความ static |
| Data checking | FAO/INFOODS PDF: https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/Guidelines_data_checking2012.pdf | ใช้เป็นแนวทาง QA ของฐานอาหาร | ต้องแปลง household unit เป็น edible grams และตรวจ missing nutrient | Strong | ต้องมี unit conversion tests และ flag nutrient ที่ขาด |
| ThaiFCD | FAO ThaiFCD 2025 entry: https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en | เป็นแหล่งทางการของข้อมูลอาหารไทย | ThaiFCD online version 3 โดย Institute of Nutrition, Mahidol University | Strong | อาหารไทยควร priority ThaiFCD และเก็บ source version |
| ASEAN Food Composition | INMU ASEAN DB: https://inmu.mahidol.ac.th/aseanfoods/composition_data.html | ใช้ fallback สำหรับอาหารภูมิภาค | รวมข้อมูลอาหารจากประเทศ ASEAN เหมาะกับการประมาณเมื่อไม่มี ThaiFCD | Moderate | ใช้เป็น fallback พร้อม source label |
| Thai FCT sources | FAO Thailand page: https://www.fao.org/infoods/infoods/tables-and-databases/thailand/en/ | ยืนยันว่ามีหลายเวอร์ชันของ food table ไทย | เน้นว่าต้องมี version tracking | Strong | data dictionary ต้องมี source_year/source_priority |
| USDA FoodData Central | USDA API: https://fdc.nal.usda.gov/api-guide | แหล่งข้อมูลอาหารสากลและ branded food | มี Foundation, SR Legacy, FNDDS, Branded Foods | Strong | ใช้เป็น fallback สำหรับอาหารนอกไทยหรือ branded food |
| User-submitted food data | Nutrition Journal: https://nutritionj.biomedcentral.com/articles/10.1186/s12937-018-0366-6 | วิเคราะห์ข้อมูลจาก food app และปัญหา data quality | ข้อมูลจากผู้ใช้มีประโยชน์แต่มีปัญหา privacy, quality, legal, ethics | Moderate | ต้องมี admin moderation, audit log, review status, rollback |
| Gamification | Digital health gamification review: https://pmc.ncbi.nlm.nih.gov/articles/PMC11701442/ | งานใหม่ที่ดู digital health app และ gamification | gamification อาจเพิ่ม engagement และพฤติกรรมสุขภาพ แต่ขึ้นกับการออกแบบ | Moderate | ใช้ reward/streak/pet แบบสนับสนุน ไม่ลงโทษ |
| Family/lifestyle gamification | https://pmc.ncbi.nlm.nih.gov/articles/PMC8460596/ | ชี้ข้อจำกัดของ gamification ที่ออกแบบผิวเผิน | หลายงานยังขาดการออกแบบที่เชื่อมกับ motivation จริง | Limited-Moderate | pet progression ควรสื่อ mastery, companionship, autonomy |
| Serious games diet/PA | https://pmc.ncbi.nlm.nih.gov/articles/PMC10056209/ | ใช้ดู evidence ของ game mechanic ต่อ diet/activity | ช่วย health promotion ได้ แต่ long-term evidence ยังจำกัด | Limited-Moderate | ห้ามอ้างว่า gamification ทำให้สุขภาพดีแน่นอน |
| AI for health governance | WHO AI health: https://www.who.int/publications/i/item/9789240029200 | guideline สำคัญของ AI ในสุขภาพ | AI ต้องโปร่งใส ปลอดภัย รับผิดชอบ เคารพ autonomy และ privacy | Strong | AI coach ต้องมี uncertainty, no diagnosis, user confirmation |
| AI Risk Management | NIST AI RMF: https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10 | framework สำหรับจัดการความเสี่ยง AI | ต้อง govern, map, measure, manage ความเสี่ยง AI | Strong | ต้องมี prompt/model version, health check, kill switch, fallback |
| LLM nutrition advice | LLM clinical nutrition study: https://pmc.ncbi.nlm.nih.gov/articles/PMC13026456/ | ตรงกับ AI ให้คำแนะนำอาหาร | LLM ให้คำตอบดูน่าเชื่อได้แต่คลาดเคลื่อนจาก guideline ได้ | Moderate warning | AI meal/coach ต้องเป็นคำแนะนำทั่วไปและตรวจทานโดยผู้ใช้ |
| Food image recognition | Systematic review: https://www.mdpi.com/2029682 | ตรงกับ AI food recognition/portion estimate | image recognition ดีขึ้น แต่ portion และ nutrition estimation ยังยาก | Moderate warning | ต้องให้ผู้ใช้ยืนยันชนิดอาหารและปริมาณ |
| Wearable accuracy | Consumer wearable review: https://pmc.ncbi.nlm.nih.gov/articles/PMC4683756/ | ใช้รองรับ Health Connect/steps/calories | step count มักดีกว่า energy expenditure; calorie จาก wearable error ได้ | Moderate | active calories ต้องแสดงว่า estimated และไม่ double count |
| Fitbit accuracy | https://pmc.ncbi.nlm.nih.gov/articles/PMC9047731/ | meta-analysis เฉพาะ Fitbit | energy expenditure มีความคลาดเคลื่อนสูงกว่า step/heart rate | Moderate | exercise calories ต้องมี source/timestamp |
| Health Connect | Android docs: https://developer.android.com/health-and-fitness/health-connect/availability | official platform docs | Android 14 รวม Health Connect permission ใน system privacy settings | Strong | ต้องขอ permission แบบ granular และให้ revoke ได้ |
| Notifications/JITAI | JITAI review: https://link.springer.com/article/10.1186/s12966-019-0792-7 | ใช้รองรับ reminder ที่เหมาะกับบริบท | just-in-time adaptive intervention มีศักยภาพ แต่ต้องออกแบบอย่างระวัง | Moderate | notification ต้องปรับเวลา/ความถี่ได้และไม่ guilt-based |
| Privacy sensitive data | EDPB basics: https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en | official EU data protection guidance | health data เป็น sensitive/special category ต้องปกป้องมากขึ้น | Strong | diet, weight, health integration, AI chat ต้องถือเป็นข้อมูลอ่อนไหว |
| Lawful processing | EDPB lawful processing: https://www.edpb.europa.eu/sme-data-protection-guide/process-personal-data-lawfully_en | ใช้อธิบาย lawful basis/consent | consent ต้อง specific, informed และ withdraw ได้ | Strong | ต้องมี consent สำหรับ Health Connect และ AI processing |
| PDPA Thailand | PDPC GPPC Plus: https://register-gppc-plus.pdpc.or.th/ | official Thai PDPA support platform | เน้น processing record, consent, data subject rights, breach process | Strong | ต้องมี consent log, export/delete, breach checklist |
| Mobile security | OWASP MASVS: https://mas.owasp.org/MASVS/ | มาตรฐานความปลอดภัย mobile app | ครอบคลุม storage, crypto, auth, network, platform, privacy | Strong | ห้าม service-role key ใน client, ใช้ secure storage, TLS, auth guard |
| Accessibility | WCAG 2.2: https://www.w3.org/TR/wcag/ | มาตรฐาน accessibility หลัก | UI ต้อง perceivable, operable, understandable, robust | Strong | chart ต้องมี text summary, contrast ดี, label ชัด |
| Health literacy | AHRQ toolkit: https://www.ahrq.gov/health-literacy/improve/precautions/index.html | ใช้รองรับภาษาที่เข้าใจง่าย | ข้อมูลสุขภาพควรอ่านง่ายและ actionable | Strong | ใช้ภาษาไทยง่าย ๆ อธิบายคำว่า estimated, target, remaining |

## 4. สูตรคำนวณและเหตุผล

### 4.1 BMR / REE

สูตรแนะนำสำหรับผู้ใหญ่ทั่วไปคือ Mifflin-St Jeor:

```text
ชาย:
BMR = 10W + 6.25H - 5A + 5

หญิง:
BMR = 10W + 6.25H - 5A - 161

W = น้ำหนัก kg
H = ส่วนสูง cm
A = อายุ ปี
```

เหตุผลที่ใช้:

- เป็นสูตรที่มีงานต้นฉบับชัดเจน
- มีงาน validation สนับสนุนว่าเหมาะกับผู้ใหญ่ทั่วไปมากกว่าสูตรเก่าหลายสูตร
- ใช้ข้อมูลที่แอพมีอยู่แล้ว ได้แก่ เพศ อายุ น้ำหนัก ส่วนสูง

ข้อจำกัด:

- เป็นค่าประมาณ ไม่ใช่ค่าที่วัดจริงจากเครื่องวัด metabolic rate
- อาจคลาดเคลื่อนในนักกีฬา ผู้สูงอายุ ผู้ตั้งครรภ์ ผู้มีโรคเฉพาะ หรือ body composition ผิดจากค่าเฉลี่ย

สิ่งที่แอพต้องทำ:

- backend ต้องเป็น source of truth
- Flutter formula ใช้ได้เฉพาะ fallback/preview และต้องมี label ว่าเป็นค่าประมาณ
- ต้องเก็บ formula version และ input ที่ใช้คำนวณ

### 4.2 TDEE

```text
TDEE = BMR * activity_factor
```

ข้อควรระวัง:

- ถ้าใช้ activity factor ที่รวมกิจกรรมประจำวันแล้ว ไม่ควรนำ active calories จาก wearable มาบวกซ้ำทั้งหมด
- ถ้าใช้ sedentary baseline แล้วค่อยบวก exercise ควรแสดง exercise calories เป็น estimate

### 4.3 เป้าหมายแคลอรี

```text
ลดน้ำหนัก:
target_kcal = TDEE - deficit_kcal

เพิ่มน้ำหนัก:
target_kcal = TDEE + surplus_kcal

รักษาน้ำหนัก:
target_kcal = TDEE
```

ข้อกำหนด:

- default deficit ควร conservative
- ถ้าผู้ใช้ตั้งเป้าหมายเร็วเกินไป ต้องเตือน
- ไม่ควรแนะนำ very low-calorie diet โดยไม่มีผู้เชี่ยวชาญ

### 4.4 Macronutrients

```text
protein_kcal = protein_g * 4
carb_kcal = carb_g * 4
fat_kcal = fat_g * 9

macro_percent = macro_kcal / total_kcal * 100
```

ช่วงอ้างอิงทั่วไป:

- carbohydrate: 45-65%
- fat: 20-35%
- protein: 10-35%

ข้อกำหนด:

- ถ้าผู้ใช้ตั้ง custom macro นอกช่วงนี้ ต้องบอกว่าเป็น custom preference ไม่ใช่คำแนะนำสากล

### 4.5 สูตรอาหารและวัตถุดิบ

การคำนวณจาก ingredient:

```text
สารอาหารจากวัตถุดิบ = nutrient_per_100g * edible_grams_used / 100
```

การคำนวณสูตรอาหาร:

```text
recipe_total = sum(สารอาหารของวัตถุดิบทุกตัว)
per_serving = recipe_total / จำนวน serving
```

สิ่งที่ระบบต้องรองรับ:

- `ingredients` เป็น strong entity
- `units` ต้องแปลงเป็น grams/ml ได้
- `food_ingredient` เชื่อม dish/beverage/drink กับ ingredients
- `recipe_ingredients` เชื่อม recipes กับ ingredients
- historical food log ต้อง snapshot nutrition ไว้

### 4.6 Weight progress

ต้องคำนวณตามทิศทางเป้าหมาย:

```text
เป้าลดน้ำหนัก:
progress = (start_weight - current_weight) / (start_weight - target_weight)

เป้าเพิ่มน้ำหนัก:
progress = (current_weight - start_weight) / (target_weight - start_weight)

เป้ารักษาน้ำหนัก:
progress = ความใกล้เคียงกับ target range
```

ข้อกำหนด:

- ไม่ควรใช้ค่าน้ำหนักวันเดียวตัดสินว่าล้มเหลว
- ควรใช้ trend หรือ rolling average
- ถ้า progress ถอยหลัง ต้องใช้ข้อความสนับสนุน ไม่ใช่ blame

### 4.7 Water logging

ข้อกำหนด:

- บันทึกตามวันที่ผู้ใช้เลือก ไม่ใช่วันที่ server ปัจจุบันเสมอ
- target น้ำเป็น estimate และควรแก้ไขได้
- ไม่อ้างว่าน้ำรักษาโรค

## 5. ข้อกำหนดเชิงระบบจากงานวิจัย

| Requirement | Backend | Flutter/Admin | QA |
|---|---|---|---|
| backend formula เป็น source of truth | บันทึก target ที่คำนวณแล้ว | แสดงค่าจาก backend เป็นหลัก | เปลี่ยนสูตร backend แล้ว Flutter ต้องไม่แสดงค่าผิด |
| food versioning | มี version/snapshot | แสดงประวัติผู้ใช้ตาม snapshot | แก้เมนูแล้ว log เก่าไม่เปลี่ยน |
| ingredient-unit conversion | มี unit conversion factor | recipe editor แสดงกรัม/ml | tbsp/tsp/piece/serving คำนวณถูก |
| AI estimate confirmation | AI output เป็น draft | ผู้ใช้ต้องกดยืนยันก่อนบันทึก | AI ห้ามบันทึก final log เอง |
| no medical diagnosis | scope guard/prompt guard | แจ้งว่าเป็นคำแนะนำทั่วไป | ถามวินิจฉัยโรคแล้วต้องปฏิเสธ |
| gamification supportive | streak recovery rule | ข้อความไม่ shame | missed day ไม่ reset แบบลงโทษ |
| water selected date | save selected date/timezone | date picker ต้องส่งค่าถูก | บันทึกเมื่อวานต้องไปอยู่เมื่อวาน |
| wearable calories estimated | store source/timestamp | แสดงแหล่งข้อมูล | ไม่ double count exercise |
| privacy/security | ไม่ expose secret | consent/delete/export UI | scan client ไม่มี service-role key |
| accessibility | summary data | chart มี text summary | screen reader อ่านสถานะได้ |

## 6. ความเสี่ยงและวิธีควบคุม

| ความเสี่ยง | ทำไมสำคัญ | วิธีควบคุม |
|---|---|---|
| ผู้ใช้เชื่อสูตรว่าแม่น 100% | BMR/TDEE เป็นค่าประมาณ | ใช้คำว่า estimated และปรับจาก trend ได้ |
| ลดน้ำหนักเร็วเกินไป | อาจไม่ปลอดภัย | เตือน deficit สูงและไม่แนะนำ very low-calorie diet |
| calorie tracking ทำให้กดดัน | ผู้ใช้บางกลุ่มอาจหมกมุ่น | ใช้ภาษาสนับสนุน มีพัก streak ได้ |
| ข้อมูลอาหารผิด | กระทบ calorie/macro ทั้งระบบ | source/version/admin moderation/audit |
| หน่วยวัตถุดิบผิด | recipe nutrition ผิดมาก | unit conversion test |
| AI hallucination | AI ตอบมั่นใจแต่ผิด | scope guard, confirmation, kill switch |
| wearable calories ผิด | active calories มี error | label estimate และไม่บวกซ้ำ |
| notification fatigue | ผู้ใช้ปิดแอพหรือเลิกใช้ | ให้ปรับเวลา/ความถี่ได้ |
| privacy leak | ข้อมูลสุขภาพอ่อนไหว | consent, secure storage, no secret in client |

## 7. QA Checklist จากหลักฐานวิจัย

### สูตรและเป้าหมาย

- BMR ชาย/หญิงตรงกับสูตร backend
- Flutter แสดง target จาก backend ก่อน fallback
- สูตรมี version และ calculated_at
- deficit สูงต้องมี warning
- progress loss/gain/maintain คำนวณทิศทางถูก

### อาหาร สูตรอาหาร และวัตถุดิบ

- 100 g ingredient คำนวณ nutrient ถูก
- unit conversion ไม่เสีย precision
- recipe total เท่ากับผลรวม ingredient
- per serving ถูกต้อง
- แก้ข้อมูลอาหารแล้ว log เก่าไม่เปลี่ยน
- missing nutrient ต้อง flag
- ThaiFCD source/version แสดงใน admin ได้

### AI

- off-topic ต้องถูกปฏิเสธ
- medical diagnosis ต้องไม่ตอบเป็นการรักษา
- AI estimate ต้องให้ผู้ใช้ confirm
- model JSON ผิดต้องเกิด typed error
- Ollama ล่มต้อง fallback friendly
- `/api/chat/health` ไม่ leak secret
- kill switch ปิด AI endpoint ได้

### Privacy/Security

- Flutter bundle ไม่มี Supabase service role key
- Health Connect revoke ได้
- account deletion/export ทำได้ตาม policy
- sensitive endpoint ต้อง require auth
- audit log แก้ไม่ได้โดย user ปกติ

### UX/Accessibility

- chart มี text summary
- ภาษาไทยอ่านง่าย
- contrast และ label ผ่านเกณฑ์
- notification ปิด/เปลี่ยนเวลาได้
- streak ที่ขาดใช้ข้อความสนับสนุน

## 8. ช่องว่างงานวิจัยที่ควรทดสอบเอง

| ช่องว่าง | ทำไมต้องทดสอบ | วิธีทดสอบ |
|---|---|---|
| ผู้ใช้ไทยบันทึกอาหารต่อเนื่องแค่ไหน | งานวิจัยส่วนใหญ่ไม่ใช่บริบทไทย | pilot 2-4 สัปดาห์ วัด logs/day และ retention |
| portion อาหารไทยแม่นแค่ไหน | อาหารไทยมีรูปแบบจานหลากหลาย | เทียบ AI/user estimate กับน้ำหนักจริง |
| pet/gamification ช่วย retention ไหม | evidence ยังขึ้นกับ design | A/B test pet progression |
| AI coach ภาษาไทยปลอดภัยไหม | LLM อาจตอบผิดหรือมั่ว | สร้าง Thai benchmark prompt |
| water target เหมาะกับผู้ใช้ไหม | target น้ำไม่ควรตายตัว | ทดสอบ editable target |
| admin moderation workload | user-submitted food อาจเยอะ | track submission/rejection/reviewer time |

## 9. รายการอ้างอิงพร้อมลิงก์

1. Burke et al. Self-Monitoring in Weight Loss. https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/
2. Patel et al. Dietary Self-Monitoring Review. https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/
3. Mobile Apps for Health Behavior Change. https://mhealth.jmir.org/2020/3/e17046/
4. Schoeppe et al. App interventions for diet and physical activity. https://pmc.ncbi.nlm.nih.gov/articles/PMC5142356/
5. Mifflin et al. Resting Energy Expenditure Equation. https://doi.org/10.1093/ajcn/51.2.241
6. Frankenfield et al. RMR Equation Validation. https://pubmed.ncbi.nlm.nih.gov/15883556/
7. Harris and Benedict Basal Metabolism. https://pubmed.ncbi.nlm.nih.gov/16576330/
8. CDC Losing Weight. https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
9. ADA Weight Loss Program Criteria. https://diabetes.org/sites/default/files/2023-09/Weight%20Loss%20Program%20Criteria.pdf
10. National Academies DRI. https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids
11. NCBI DRI Tables. https://www.ncbi.nlm.nih.gov/books/NBK208874/
12. Michie et al. BCT Taxonomy. https://doi.org/10.1007/s12160-013-9486-6
13. EFSA Water DRV. https://www.efsa.europa.eu/en/efsajournal/pub/1459
14. EFSA Dietary Reference Values. https://www.efsa.europa.eu/en/topics/topic/dietary-reference-values
15. FAO/INFOODS Standards. https://www.fao.org/infoods/infoods/standards-guidelines/en/
16. FAO Food Composition Data. https://www.fao.org/4/y4705e/y4705e06.htm
17. FAO/INFOODS Data Checking Guidelines. https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/Guidelines_data_checking2012.pdf
18. FAO ThaiFCD 2025. https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en
19. INMU ASEAN Food Composition Database. https://inmu.mahidol.ac.th/aseanfoods/composition_data.html
20. FAO Thailand Food Composition Tables. https://www.fao.org/infoods/infoods/tables-and-databases/thailand/en/
21. USDA FoodData Central API. https://fdc.nal.usda.gov/api-guide
22. USDA FoodData Central FAQ. https://fdc.nal.usda.gov/faq
23. User-documented food app data. https://nutritionj.biomedcentral.com/articles/10.1186/s12937-018-0366-6
24. Digital health gamification review. https://pmc.ncbi.nlm.nih.gov/articles/PMC11701442/
25. Family engagement gamification. https://pmc.ncbi.nlm.nih.gov/articles/PMC8460596/
26. Serious games diet and physical activity. https://pmc.ncbi.nlm.nih.gov/articles/PMC10056209/
27. WHO AI for Health. https://www.who.int/publications/i/item/9789240029200
28. NIST AI RMF. https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10
29. LLM Clinical Nutrition Decision Tools. https://pmc.ncbi.nlm.nih.gov/articles/PMC13026456/
30. Food recognition systematic review. https://www.mdpi.com/2029682
31. Consumer wearable review. https://pmc.ncbi.nlm.nih.gov/articles/PMC4683756/
32. Fitbit accuracy meta-analysis. https://pmc.ncbi.nlm.nih.gov/articles/PMC9047731/
33. Android Health Connect. https://developer.android.com/health-and-fitness/health-connect/availability
34. JITAI systematic review. https://link.springer.com/article/10.1186/s12966-019-0792-7
35. EDPB Data Protection Basics. https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en
36. EDPB Lawful Processing. https://www.edpb.europa.eu/sme-data-protection-guide/process-personal-data-lawfully_en
37. Thailand PDPC GPPC Plus. https://register-gppc-plus.pdpc.or.th/
38. OWASP MASVS. https://mas.owasp.org/MASVS/
39. WCAG 2.2. https://www.w3.org/TR/wcag/
40. AHRQ Health Literacy Toolkit. https://www.ahrq.gov/health-literacy/improve/precautions/index.html

## 10. คำอธิบายที่ควรใช้กับแอพ

ควรอธิบาย Calories Guard ว่า:

> Calories Guard เป็นแอพช่วยบันทึกและติดตามโภชนาการ น้ำหนัก น้ำดื่ม กิจกรรม และเป้าหมายสุขภาพ โดยใช้สูตรคำนวณและฐานข้อมูลอาหารที่มีแหล่งอ้างอิง พร้อม AI ที่ทำหน้าที่เป็นผู้ช่วยให้คำแนะนำทั่วไปและแสดงความไม่แน่นอนเมื่อเป็นค่าประมาณ

ไม่ควรอธิบายว่า:

> Calories Guard เป็นระบบวินิจฉัยโรค รักษาโรค หรือรับประกันผลการลดน้ำหนัก

การแยกสองประโยคนี้สำคัญมาก เพราะช่วยลดความเสี่ยงด้านความปลอดภัย ความเข้าใจผิดของผู้ใช้ และความเสี่ยงด้านกฎหมาย/ความเป็นส่วนตัว

