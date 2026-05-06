# Research Evidence Review: Calories Guard

**Date:** 2026-05-06  
**Role:** Senior researcher and analytics review  
**Scope:** Calories Guard mobile/web app, admin tools, backend formulas, Supabase/food database, AI coach, gamification, security, privacy, and QA.

## 1. Practical Conclusion

Calories Guard is directionally aligned with the evidence if the product keeps these rules:

1. Use the backend-calculated calorie, macro, weight-goal, and progress values as the source of truth.
2. Treat nutrition, water, wearable calories, and AI estimates as estimates unless they come from verified user input or a curated food-composition source.
3. Preserve historical food-log correctness through food versioning and log snapshots instead of rewriting old entries when food data changes.
4. Keep AI in an assistive role: explain, estimate, and suggest, but require user confirmation before saving food/recipe estimates and avoid diagnosis or treatment advice.
5. Use gamification for supportive engagement only: small wins, recovery after missed days, progress feedback, and autonomy. Avoid shame, punitive streak loss, or leaderboards that may encourage unhealthy behavior.
6. Treat health/nutrition data as sensitive data: minimize collection, protect secrets, use secure auth, document consent, and provide deletion/export paths.
7. Use ThaiFCD/Thai food-composition sources and explicit unit conversion for Thai dishes, ingredients, beverages, and recipes.
8. Menu recommendation must be traceable: recommended foods should come from the user's remaining calorie/macro budget, allergy exclusions, verified food-composition data, dietary-pattern quality, and user preference/history. The app must not present recommendations as "medically optimal" unless the rule and evidence are explicit.

This review does **not** prove that the current app is clinically effective by itself. It supports that the app design choices are evidence-informed and gives QA/product requirements to keep the implementation correct.

## 2. Evidence Grading

| Grade | Meaning for Calories Guard |
|---|---|
| Strong | Supported by guideline, standard, official dataset, or multiple systematic reviews. Use as product requirement. |
| Moderate | Supported by good but indirect evidence. Use, but show estimates/uncertainty. |
| Limited | Early, small, or context-specific evidence. Use as experimental feature with monitoring. |
| Mixed | Evidence conflicts or benefit depends on population. Use conservative defaults and user controls. |
| Not enough evidence | Do not make strong claims. Treat as hypothesis and validate internally. |

## 3. Evidence Matrix

| App area | Research / source | Why this source is used | Summary of evidence | Evidence grade | App requirement |
|---|---|---|---|---|---|
| Food logging and self-monitoring | Burke et al., systematic review of self-monitoring in weight loss, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/ | A foundational review for the core idea of logging intake, activity, and weight. | Self-monitoring is consistently associated with better weight-loss outcomes, but adherence declines when logging burden is high. | Strong | Food logging must be fast, editable, searchable, and selected-date aware. Missing values must not be displayed as exact. |
| Digital dietary self-monitoring | Patel et al., systematic review of dietary self-monitoring delivery/intensity/effectiveness, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/ | Directly relevant to mobile food diary design and adherence metrics. | More frequent/intense dietary self-monitoring is associated with weight-loss success; real-time feedback can improve adherence. | Strong | Dashboard should show daily progress, remaining target, and incomplete logs clearly. |
| Mobile behavior-change apps | JMIR systematic review of mobile apps for behavior change: https://mhealth.jmir.org/2020/3/e17046/ | Reviews diet, physical activity, mental health, alcohol/drug app interventions. | Apps can support behavior change, especially when they include feedback, self-monitoring, goals, and usability. Evidence varies by behavior and study quality. | Moderate | App should combine self-monitoring, feedback, goal setting, reminders, and user control. |
| App interventions for diet/physical activity | Schoeppe et al., systematic review, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC5142356/ | Covers diet, physical activity, sedentary behavior, and app intervention features. | Some app interventions improve lifestyle behavior; effective interventions often include feedback, education, reinforcement, and rewards. | Moderate | Gamification and reminders should support health behavior, not replace accurate nutrition methodology. |
| BMR/REE equation | Mifflin et al. 1990, "A new predictive equation for resting energy expenditure", AJCN DOI: https://doi.org/10.1093/ajcn/51.2.241 | Original source for Mifflin-St Jeor equation, widely used in nutrition apps. | Predicts resting energy expenditure from sex, age, weight, and height. It is an estimate, not a measurement. | Strong for general estimate | Backend should store formula name/version and inputs. UI should say "estimated" when not measured by indirect calorimetry. |
| BMR equation validation | Frankenfield et al. 2005 systematic review, PubMed: https://pubmed.ncbi.nlm.nih.gov/15883556/ | Compares common RMR equations and validates why Mifflin is reasonable. | Mifflin-St Jeor was among the most reliable common equations and predicted RMR within about 10% in more nonobese/obese adults than alternatives, but minorities/older adults were underrepresented. | Strong with caveats | Do not claim exact calorie needs. Allow adjustment from real weight trend. |
| Historical BMR method | Harris and Benedict, PubMed: https://pubmed.ncbi.nlm.nih.gov/16576330/ | Provides historical baseline for BMR equations and comparison. | Harris-Benedict is classic but older; useful as reference, not necessarily best default. | Moderate | If displayed, label formula explicitly and do not mix formulas between Flutter/backend. |
| Safe weight-loss rate | CDC healthy weight guidance: https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html | Authoritative public-health guidance for safe weight-loss messaging. | CDC recommends realistic goals and gradual weight loss; commonly 1-2 lb/week is used as a safe, sustainable range. | Strong | Reject extreme deficit targets; warn users when goal speed is aggressive. |
| Calorie deficit in structured weight management | ADA criteria PDF: https://diabetes.org/sites/default/files/2023-09/Weight%20Loss%20Program%20Criteria.pdf | Authoritative clinical/public health criteria, especially relevant to metabolic risk users. | Structured programs often use individualized energy deficits such as 500-750 kcal/day with lifestyle and behavior support. | Moderate to strong | Default deficit should be conservative; app must not push very low-calorie diets without clinician supervision. |
| Macronutrient ranges | National Academies DRI / AMDR: https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids and NCBI tables: https://www.ncbi.nlm.nih.gov/books/NBK208874/ | Official reference for carbohydrate/fat/protein distribution ranges. | Adult AMDR commonly supports carbohydrate 45-65%, fat 20-35%, protein 10-35% of energy; individual needs vary. | Strong | Macro targets should default inside accepted ranges unless user chooses custom goals. |
| Protein/macro caution | DRI reference tables, NCBI: https://www.ncbi.nlm.nih.gov/books/NBK208874/ | Gives recommended intake tables and reference values. | Reference values are population-level, not individualized prescriptions. | Strong | UI should separate "target" from "medical recommendation". |
| Protein for muscle gain / muscle preservation | Jager et al. ISSN Position Stand on protein and exercise: https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8 | Directly supports the app's `gain_muscle`, muscle-preservation, and high-protein recommendation logic for active adults. | Most exercising individuals can build or maintain muscle with about 1.4-2.0 g protein/kg/day. Higher needs may apply during energy restriction, intense training, or special populations. | Moderate to strong for healthy active adults | For gain muscle, use protein around 2.0 g/kg/day; for weight loss with muscle preservation, around 1.6-1.8 g/kg/day is reasonable. Label as general fitness guidance, not clinical nutrition. |
| Menu recommendation from macro gaps | DRI/AMDR + ISSN protein guidance + app self-monitoring evidence | This connects dashboard targets to concrete food suggestions. | Evidence supports tracking energy/macros and using accepted ranges, but there is no single universal "best menu" algorithm. Recommendations should therefore be rule-based, transparent, editable, and conservative. | Moderate | Recommend foods that fit remaining calories/macros and avoid allergies. Show why a menu is recommended: "fits remaining protein", "within calorie budget", "low sugar", etc. |
| Healthy dietary-pattern quality | Dietary Guidelines for Americans 2020-2025 PDF: https://www.dietaryguidelines.gov/sites/default/files/2020-12/Dietary_Guidelines_for_Americans_2020-2025.pdf and CDC summary: https://www.cdc.gov/healthy-weight-growth/healthy-eating/ | Authoritative public-health source for nutrient-dense patterns and food groups. | Healthy patterns emphasize vegetables, fruits, whole grains, lean/varied protein foods, dairy or fortified alternatives, and limits on added sugar, sodium, saturated fat, and alcohol. | Strong as general pattern guidance | Recommendation score should favor nutrient-dense foods and penalize high added sugar/sodium/saturated fat when those fields exist. Thai adaptation should use Thai dietary guidelines and ThaiFCD data. |
| Sodium and sugar guardrails | WHO sodium fact sheet: https://www.who.int/news-room/fact-sheets/detail/salt-reduction and WHO healthy diet / sugars guidance: https://www.who.int/news-room/fact-sheets/detail/healthy-diet | Authoritative thresholds for risk-sensitive food advice. | WHO recommends adults reduce sodium to below 2000 mg/day and free sugars to below 10% of energy, with further reduction to 5% suggested for additional dental-health benefit. | Strong | Add sodium/sugar fields to food/ingredient data where possible. Food recommendations should warn, filter, or down-rank high-sodium/high-sugar items instead of optimizing only calories/macros. |
| Portion-size uncertainty in recommendations | Dietary assessment measurement-error review: https://nutritionalassessment.org/errors/index.html and PortionSize validation study: https://pmc.ncbi.nlm.nih.gov/articles/PMC9244674/ | Explains why menu suggestions based on "1 serving" can still be wrong if the serving size is misestimated. | Portion-size estimation is a major source of dietary assessment error; app estimates improve when portions are explicit and editable. | Strong warning | Recommended menu cards must show serving basis and allow amount editing before saving. AI or default portions should be labelled estimated. |
| Weight trend and self-weighing | Self-monitoring review above plus behavior-change taxonomy below | Trend feedback reduces overreaction to one noisy measurement. | Single weight entries fluctuate; self-monitoring works best when paired with feedback and goal review. | Moderate | Use trend/rolling average for feedback; goal progress direction must handle loss/gain/maintenance separately. |
| Behavior-change taxonomy | Michie et al. BCT Taxonomy v1 DOI: https://doi.org/10.1007/s12160-013-9486-6 | Gives a standard vocabulary for intervention components. | Core BCTs relevant to Calories Guard include goal setting, self-monitoring, feedback, prompts/cues, review of goals, social support, and rewards. | Strong as framework | Map features to BCTs in product docs and QA: logging, dashboard feedback, reminders, badges, missions. |
| Water targets | EFSA Scientific Opinion on Dietary Reference Values for water: https://www.efsa.europa.eu/en/efsajournal/pub/1459 | Authoritative hydration reference; distinguishes total water from beverages only. | Adequate intake depends on age, sex, environment, activity, and includes water from food and beverages. | Strong | Do not use a universal "8 glasses" rule as medical truth. Allow user edit and label target as general estimate. |
| Hydration UI | EFSA water topic: https://www.efsa.europa.eu/en/topics/topic/dietary-reference-values | Explains DRVs and adequate intake concept. | DRVs include AI/PRI/AR/UL; water AI is not a disease-treatment rule. | Strong | Store water logs by selected date/timezone; avoid health claims such as curing disease. |
| Food composition data governance | FAO/INFOODS standards and guidelines: https://www.fao.org/infoods/infoods/standards-guidelines/en/ | Official food-composition standards for matching, checking, unit conversion, and documentation. | Food-composition values need documented sources, unit conversion, food matching, and data checks. | Strong | Every ingredient/food should have source, unit, nutrient basis, and version. |
| Recipe nutrient calculation | FAO food composition data chapter: https://www.fao.org/4/y4705e/y4705e06.htm | Explains calculated food values, retention factors, yield factors, and cooked-food calculations. | Recipe nutrition should calculate from ingredient quantities and account for yield/retention when available. | Strong | `recipes` + `food_recipe` + `recipe_ingredients`/`food_ingredient` must calculate from ingredients, not static copied text. |
| Recipe calculation QA | FAO/INFOODS data-checking PDF: https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/Guidelines_data_checking2012.pdf | Directly lists checks before recipe calculation. | Ingredients must be converted from household units to edible grams; missing significant nutrient values distort totals. | Strong | Unit conversion tests are required for grams, ml, serving, tbsp, tsp, piece; missing major ingredient nutrients must be flagged. |
| Thai food composition | FAO Thai Food Composition Database 2025 entry: https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en | Authoritative listing for ThaiFCD current version and citation. | ThaiFCD is a Thailand food composition database from Institute of Nutrition, Mahidol University, online version 3, August 2025. | Strong | Thai foods/ingredients should prioritize ThaiFCD where available and store source version. |
| Thai/ASEAN food composition | INMU ASEAN Food Composition Database: https://inmu.mahidol.ac.th/aseanfoods/composition_data.html and FAO ASEAN entry: https://www.fao.org/food-composition/tables-and-databases/detail/%28multiple-countries--2014%29-asean-food-composition-database/en | Useful fallback for regional foods and ASEAN ingredients. | ASEAN database compiles average nutrient data from national tables; it is appropriate for group/diet analysis and approximate entries. | Moderate | Use as fallback with source label; do not overwrite ThaiFCD values silently. |
| Thai FCT sources | FAO INFOODS Thailand page: https://www.fao.org/infoods/infoods/tables-and-databases/thailand/en/ | Lists official Thai food composition tables and historic sources. | Confirms multiple Thai sources exist across years; version tracking is necessary. | Strong | Data dictionary must include source, source_year, source_priority, confidence. |
| USDA FoodData Central | USDA FDC API guide: https://fdc.nal.usda.gov/api-guide and FAQ: https://fdc.nal.usda.gov/faq | Official API and food data reference, useful for non-Thai/branded foods. | FDC provides Foundation Foods, SR Legacy, FNDDS, Branded Foods, and downloadable/API access. | Strong | Use as fallback/source import for non-Thai or branded items; keep data-source provenance. |
| Data quality and user-submitted foods | Nutrition Journal analysis of public app food data: https://nutritionj.biomedcentral.com/articles/10.1186/s12937-018-0366-6 | Relevant to opportunities and risks of user-documented food-consumption data. | App food data can support research/analytics but creates legal, ethical, data-quality, and privacy challenges. | Moderate | Admin moderation, audit logs, review statuses, and rollback are required. |
| Gamification | Systematic review/meta-analysis of digital health apps with/without gamification, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC11701442/ | Recent RCT-focused evidence on gamified digital health apps. | Gamification can improve physical activity/cardiometabolic-related behaviors, but effects depend on design and population. | Moderate | Use supportive streaks/rewards and monitor engagement/adverse patterns. |
| Gamification in lifestyle interventions | Gamification for family engagement systematic review, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC8460596/ | Shows design gaps and importance of relatedness/social support. | Many interventions lack meaningful integration of gamification mechanics; relatedness and thoughtful design matter. | Limited to moderate | Pet/progression features should support mastery and companionship, not just points. |
| Serious games for diet/PA | Systematic review, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC10056209/ | Relevant to healthy diet and physical activity game mechanics. | Serious games/gamification can support health promotion but evidence quality and long-term outcomes vary. | Limited to moderate | Treat gamification as adherence support, not as proof of health outcome. |
| AI health governance | WHO ethics and governance of AI for health: https://www.who.int/publications/i/item/9789240029200 | Authoritative health-AI guidance. | AI in health must prioritize autonomy, safety, transparency, accountability, inclusiveness, and sustainability. | Strong | AI coach must disclose uncertainty, avoid diagnosis, preserve consent/privacy, and support human/user review. |
| AI risk management | NIST AI RMF 1.0: https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10 | Operational framework for trustworthy AI risk management. | AI risks should be governed, mapped, measured, and managed; trustworthiness includes validity, reliability, safety, security, resilience, accountability, transparency, explainability, privacy, and fairness. | Strong | Keep prompt/model versions, health checks, fallback messages, kill switch, and evaluation tests. |
| AI nutrition advice reliability | LLM diabetes meal-planning study, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC13026456/ | Recent direct evidence on LLM-generated nutrition plans. | LLMs may produce plausible meal plans but can deviate from guideline-concordant diet targets; clinical use requires validation. | Moderate warning | AI meal plans must be labeled advisory/estimated and not used as clinical decision support. |
| AI food recognition/portion | Mobile computer-vision food recognition systematic review: https://www.mdpi.com/2029682 | Directly relevant to AI food recognition and calorie estimation. | Recognition accuracy has improved, but portion size and nutrition derivation remain difficult in real-world images. | Moderate warning | AI-recognized foods require user confirmation, portion editing, and confidence/estimated labels. |
| Wearable steps/calories | Systematic review of wearable validity, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC4683756/ | Foundational review for steps/distance/activity/energy expenditure. | Step counts tend to be more reliable than energy expenditure; device accuracy varies. | Moderate | Imported exercise calories must show source and be treated as estimate. |
| Fitbit/wearable energy expenditure | Systematic review/meta-analysis, PMC: https://pmc.ncbi.nlm.nih.gov/articles/PMC9047731/ | More specific to heart rate, steps, and energy expenditure validation. | Wearables vary by outcome; energy expenditure estimates are less reliable than steps or heart rate. | Moderate | Avoid double-counting active calories in TDEE plus exercise logs. |
| Health Connect | Android Health Connect docs: https://developer.android.com/health-and-fitness/health-connect/availability | Official platform behavior and permission source. | Android 14 integrates Health Connect permissions into system privacy settings. | Strong | Use granular permissions, explain data source, timestamp, and allow disconnect/delete. |
| Notifications/JITAI | JITAI systematic review: https://link.springer.com/article/10.1186/s12966-019-0792-7 | Supports adaptive reminder design. | Just-in-time adaptive interventions can use context and timing, but require careful design and evaluation. | Moderate | Notifications should be user-controlled, relevant, and non-guilt-based. |
| Privacy: sensitive data | EDPB data protection basics: https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en | Official EU regulator guide; useful benchmark even for non-EU users. | Health data is a special category of personal data requiring stronger protection and lawful basis. | Strong | Treat weight, diet, health integration, AI chats as sensitive; minimize data and document purposes. |
| Privacy: lawful processing | EDPB lawful processing guide: https://www.edpb.europa.eu/sme-data-protection-guide/process-personal-data-lawfully_en | Practical legal-basis checklist for personal and sensitive data. | Consent must be specific and informed; sensitive data requires additional conditions and safeguards. | Strong | Use explicit consent for Health Connect and AI processing; allow withdrawal. |
| Thailand PDPA operations | PDPC GPPC Plus page: https://register-gppc-plus.pdpc.or.th/ | Official Thai PDPA-support platform reference. | PDPC emphasizes records of processing, consent management, data-subject rights, and breach notification processes. | Strong | Maintain processing records, consent records, breach-response checklist, and deletion/export flows. |
| Mobile security | OWASP MASVS: https://mas.owasp.org/MASVS/ | Industry-standard mobile app security verification. | MASVS covers storage, cryptography, authentication, network, platform interaction, code quality, resilience, and privacy. | Strong | Follow MASVS baseline: no service-role keys in client, secure storage, TLS, auth session handling, dependency checks. |
| Accessibility | W3C WCAG 2.2: https://www.w3.org/TR/wcag/ | Official accessibility standard. | WCAG covers perceivable, operable, understandable, and robust interfaces; charts need text alternatives/status messages. | Strong | Thai dashboards/charts must have text summaries, contrast, labels, keyboard/screen-reader support where applicable. |
| Health literacy | AHRQ Health Literacy Universal Precautions Toolkit: https://www.ahrq.gov/health-literacy/improve/precautions/index.html | Authoritative guidance for plain health communication. | Health information should be easy to understand and act on for all users. | Strong | Use plain Thai, explain "estimate", "target", "remaining", and avoid unexplained clinical jargon. |

## 4. Formula and Methodology Requirements

### 4.1 BMR / REE

Recommended default for general adult users:

```text
Mifflin-St Jeor
Male:   BMR = 10W + 6.25H - 5A + 5
Female: BMR = 10W + 6.25H - 5A - 161

W = weight in kg
H = height in cm
A = age in years
```

Why use it:

- It has an original peer-reviewed source.
- It has systematic-review support as a reliable common predictive equation.
- It uses fields the app already collects: sex, age, height, weight.

Product rule:

- Backend is source of truth.
- Flutter-side formula may exist only as a clearly labeled preview/fallback.
- Store `formula_name`, `formula_version`, `input_weight_kg`, `input_height_cm`, `input_age`, `input_sex`, `activity_factor`, `goal_adjustment_kcal`, and `calculated_at`.

Risk:

- Predictive equations can be wrong for athletes, older adults, pregnancy, illness, eating disorders, some ethnic groups, or unusual body composition. The app should present numbers as estimates and allow adjustment from observed trend.

### 4.2 TDEE

```text
TDEE = BMR * activity_factor
```

Common app activity-factor bands may be used, but should be editable and documented. If Health Connect/exercise data is imported, avoid double-counting:

- If activity factor already includes normal exercise, do not automatically add all active calories again.
- If app uses sedentary baseline + imported exercise, label exercise calories as estimated and optionally apply a conservative adjustment.

### 4.3 Calorie Goal

```text
Weight loss target = TDEE - deficit_kcal
Weight gain target = TDEE + surplus_kcal
Maintenance target = TDEE
```

Evidence-backed guardrail:

- Default deficit should normally be conservative, often around 500 kcal/day, and aggressive targets should warn the user.
- Do not recommend very low-calorie diets or rapid weight-loss claims without clinician supervision.

### 4.4 Macronutrients

```text
Protein kcal = protein_g * 4
Carbohydrate kcal = carbohydrate_g * 4
Fat kcal = fat_g * 9
Macro percent = macro_kcal / total_kcal * 100
```

Default range:

- Carbohydrate: 45-65% of energy.
- Fat: 20-35% of energy.
- Protein: 10-35% of energy.

Product rule:

- If user chooses a custom macro split outside default ranges, show it as custom user preference, not as universal recommendation.

### 4.5 Recipe and Ingredient Nutrition

Ingredient basis:

```text
nutrient_for_recipe = ingredient_nutrient_per_100g * edible_grams_used / 100
```

Recipe total:

```text
recipe_total_nutrient = sum(nutrient_for_each_ingredient)
per_serving_nutrient = recipe_total_nutrient / servings
```

Advanced calculation:

- Add yield factor and retention factor when known.
- Store whether values are raw, cooked, estimated, or lab/database-derived.

Required data model behavior:

- `ingredients` is a strong entity.
- `units` must support conversion to canonical grams/ml where possible.
- `food_ingredient` connects dish/beverage/drink to ingredients.
- `recipe_ingredients` connects recipes to ingredients and quantities.
- Historical logs must store snapshot nutrition and food/recipe version.

### 4.6 Weight Trend and Progress

Progress must respect goal direction:

```text
loss_goal_progress = (start_weight - current_weight) / (start_weight - target_weight)
gain_goal_progress = (current_weight - start_weight) / (target_weight - start_weight)
maintain_goal_progress = closeness_to_target_range
```

Product rule:

- Use trend or rolling average for feedback.
- If movement is away from goal, use supportive copy and suggest review rather than failure language.

### 4.7 Water Logging

Product rule:

- Store against user-selected date and local timezone.
- Target is an adequate-intake estimate, not a medical prescription.
- Allow edits for hot weather, exercise, pregnancy, illness, and clinician advice.

### 4.8 Menu Recommendation Methodology

This was the main missing part in the earlier research file. Calories Guard should not say "we recommend this menu" unless the recommendation can be explained from measurable inputs.

#### Current implementation observed in the app

The current app logic is mostly rule/filter based:

1. `GET /foods` returns active foods with regional display names and allergy flags.
2. The Flutter recommendation screen separates foods by `food_type`: dish / recipe dish, beverage, snack.
3. Allergy filtering hides foods whose `allergy_flag_ids` match the user's allergy preferences.
4. Food list order is randomized, then re-sorted by the user's historical food frequency when available.
5. Food chips currently use simple calorie thresholds:
   - general/heavier foods: `calories > 400`
   - cleaner/lighter foods: `calories <= 400`
   - low-calorie desserts: `calories <= 100`
6. Macro filters calculate remaining macro:

```text
remaining_macro_g = max(target_macro_g - consumed_macro_g, 0)
```

Then show foods where:

```text
food_macro_g > 0 AND food_macro_g <= remaining_macro_g
```

and sort descending by that macro. For example, if the user lacks protein, the screen shows higher-protein foods that still fit the remaining protein budget.

This implementation is understandable and evidence-aligned at a basic level, but it is not yet a complete nutrition recommendation algorithm because it does not fully score calorie fit, macro balance, sodium/sugar/fiber, food group quality, portion uncertainty, or variety.

#### Evidence-supported recommendation pipeline

Recommended pipeline:

```text
User profile + goals
  -> backend target calories/macros
  -> today's consumed calories/macros
  -> remaining calorie/macro budget
  -> allergy and medical-boundary filters
  -> food database / recipe nutrition values
  -> transparent recommendation score
  -> user confirmation before saving
```

Required hard filters:

```text
food.deleted_at IS NULL
food is available in selected category
food does not match user's allergy flags
food has usable serving nutrition or recipe-calculated nutrition
if selected macro filter exists: food_macro_g <= remaining_macro_g
```

For clinical-boundary users such as pregnancy, lactation, children/adolescents, diabetes, CKD, eating-disorder risk, or clinician-managed diets, the app should not optimize aggressively. It should show a boundary message and recommend consulting a qualified professional.

#### Transparent scoring formula for vNext

The app can move from simple filters to a clear score:

```text
recommendation_score =
  0.30 * calorie_fit_score
+ 0.25 * macro_gap_score
+ 0.20 * dietary_quality_score
+ 0.10 * personalization_score
+ 0.10 * variety_score
+ 0.05 * data_confidence_score
- safety_penalty
```

Each sub-score should be 0.0-1.0.

Calorie fit:

```text
remaining_calories = max(target_calories - consumed_calories, 0)
meal_budget = remaining_calories

calorie_fit_score =
  if remaining_calories <= 0:
      0
  else:
      1 - min(abs(food_calories - meal_budget) / meal_budget, 1)
```

If the app later supports meal-specific targets, `meal_budget` can be split by user habit or editable meal plan. Until validated, fixed breakfast/lunch/dinner percentages should be treated as product heuristics, not research facts.

Macro gap:

```text
protein_gap = max(target_protein_g - consumed_protein_g, 0)
carb_gap    = max(target_carbs_g   - consumed_carbs_g, 0)
fat_gap     = max(target_fat_g     - consumed_fat_g, 0)
total_gap   = protein_gap + carb_gap + fat_gap

macro_gap_score =
  if total_gap == 0:
      0
  else:
      (
        protein_gap / total_gap * min(food_protein_g / max(protein_gap, 1), 1)
      + carb_gap    / total_gap * min(food_carbs_g   / max(carb_gap, 1), 1)
      + fat_gap     / total_gap * min(food_fat_g     / max(fat_gap, 1), 1)
      )
```

This keeps recommendations tied to the user's current deficit instead of simply sorting by a nutrient forever.

Dietary quality:

```text
dietary_quality_score starts at 0.5
+ nutrient_dense_bonus
+ fiber_bonus
+ fruit_vegetable_or_whole_grain_bonus
+ lean_protein_bonus
- high_sodium_penalty
- high_added_sugar_penalty
- high_saturated_fat_penalty
- alcohol_penalty
```

This requires more fields in the food/ingredient database: `food_group`, `fiber_g`, `sodium_mg`, `total_sugar_g`, `added_sugar_g` when known, `saturated_fat_g`, `is_alcoholic`, and data source/confidence. Without these fields, the app should not claim that a food is "healthy" solely because it is low calorie.

Personalization:

```text
personalization_score =
  normalized_recent_preference
  + regional_name_match_bonus
  + goal_match_bonus
```

Current frequency sorting can be reused, but it should not dominate the score because it may repeatedly recommend the same food and reduce variety.

Variety:

```text
variety_score = 1 if food not eaten recently
variety_score decreases if same food appears often in last 3-7 days
```

Data confidence:

```text
verified ThaiFCD / curated food = 1.0
curated non-Thai source = 0.8
admin-approved user submission = 0.7
AI estimate pending review = 0.4
unknown / missing source = 0.2
```

Safety penalty:

```text
safety_penalty includes:
- allergy match: hard exclude, not only penalty
- sodium/sugar/alcohol warning when relevant
- AI-estimated nutrition without user confirmation
- missing serving size or unit conversion
- clinical boundary flags
```

#### How recommendations should be explained in UI

Every recommended menu should have a short reason:

- "เหมาะเพราะยังขาดโปรตีน 32 g และเมนูนี้ให้โปรตีน 24 g"
- "อยู่ในงบแคลอรี่ที่เหลือวันนี้"
- "ซ่อนเมนูที่ตรงกับอาหารที่คุณแพ้แล้ว"
- "เป็นค่าประมาณจากฐานข้อมูลอาหาร ต้องปรับปริมาณก่อนบันทึก"
- "เมนูนี้มีน้ำตาล/โซเดียมสูง ควรทานเป็นบางครั้ง" when data exists

#### Research support

This methodology is supported by combining several evidence domains:

- Self-monitoring evidence supports using current intake, remaining targets, and feedback.
- Mifflin/TDEE/DRI/AMDR support calorie and macro targets as estimates.
- ISSN protein guidance supports higher protein targets for muscle gain/preservation in active adults.
- DGA/WHO dietary guidance supports nutrient-dense foods and limiting sodium/sugar/alcohol.
- FAO/INFOODS supports reliable food-composition data, units, ingredients, recipes, and provenance.
- Portion-size evidence supports editable servings and uncertainty labels.

Important limitation: there is no single universal RCT-proven formula that says "this exact Thai menu is best for this user." Therefore Calories Guard should present recommendations as evidence-informed, explainable suggestions, not medical prescriptions.

### 4.9 Full Formula Traceability by App Feature

| Feature | Current / required formula or rule | Evidence basis | App status / gap |
|---|---|---|---|
| BMI status | `BMI = weight_kg / height_m^2` | WHO/Asia-Pacific BMI cutoffs are already discussed in the Thai master review; use as screening, not diagnosis. | Flutter has BMI calculation and tests. English evidence file should keep BMI in feature traceability. |
| BMR / REE | Mifflin-St Jeor: `10W + 6.25H - 5A + sex_constant` | Mifflin 1990; Frankenfield validation. | Backend uses Mifflin. Flutter fallback uses Mifflin plus Asian factor; Thai/Asian correction needs explicit validation note. |
| TDEE | `TDEE = BMR * activity_factor` | Energy requirement methodology and common PAL/activity-factor approach. | Backend source of truth. Avoid double-counting Health Connect active calories. |
| Weight-goal calories | `target = TDEE + kg_per_week * 1100`, then minimum safety floor | Wishnofsky-style energy-density heuristic; modern dynamic models show this is approximate. CDC/ADA support conservative deficit. | Store as estimate; warn on aggressive targets. Consider replacing static 1100 kcal/day per kg/week with a versioned dynamic model later. |
| Minimum calorie guard | male: `max(BMR, 1500)`, female: `max(BMR, 1200)` | Public-health/clinical programs often use lower bounds, but individual needs vary. | Good safety guard for general users, but should be configurable and clinically bounded. |
| Macro targets | Backend: protein/fat by g/kg, carbs by remaining calories; fallback ratio if carbs too low. Flutter fallback: ratio by goal. | DRI AMDR + ISSN protein. | Backend and Flutter now differ by design: backend should be primary; Flutter must show estimated label when fallback. |
| Atwater calories | `kcal = protein*4 + carbs*4 + fat*9` | Atwater general factors. | Implemented in backend service; also used in tests. |
| Food log total | `item_total = per_unit_value * amount`; daily total is sum of items by selected date. | Food-composition methodology. | Implemented in record flow; must preserve historical snapshots. |
| Recipe nutrition | `ingredient_per_100g * edible_grams / 100`; sum ingredients; divide by servings; optionally yield/retention. | FAO/INFOODS recipe calculation. | Database/view exists for calculated ingredients; must ensure recipes use ingredient/unit relations instead of static copied food values. |
| Menu recommendation | Hard filters + recommendation score from calorie fit, macro gap, dietary quality, personalization, variety, confidence, safety. | Self-monitoring, DRI/AMDR, ISSN, DGA/WHO, FAO/INFOODS, portion-size evidence. | Current app uses category/calorie/macro filters and frequency sort. Needs backend score for consistent recommendation. |
| AI meal estimate | Extract foods -> DB macro lookup; if unknown, LLM JSON estimate -> temp_food for admin review; user confirms before saving. | WHO AI, NIST AI RMF, food-recognition/portion uncertainty. | Implemented with guardrails; should store model/prompt version and confidence. |
| Water logging | selected date + editable target; no universal medical claim. | EFSA water DRV. | Selected-date rule documented; continue QA. |
| Weight trend | use direction-aware progress; trend preferred over single point. | self-monitoring and weight fluctuation principles. | Progress direction fix documented; trend model exists. |
| Gamification | points/badges/streaks as supportive feedback, not health judgment. | BCT taxonomy + gamification reviews. | Implemented; needs non-punitive QA and adverse-use monitoring. |
| Health Connect / Samsung Health | imported active/total calories and steps are estimates with source/timestamp. | wearable accuracy reviews + Android Health Connect docs. | Permission/data-source fix implemented; avoid double-counting. |
| Allergy safety | exclude foods whose allergy flags match user preference; do not merely down-rank. | food-allergy safety guidance; health-risk principle. | Current recommendation screen hides allergic foods by default. |

## 5. Feature-by-Feature Product Requirements

| Requirement | Evidence basis | Backend impact | Flutter/Admin impact | QA check |
|---|---|---|---|---|
| Food logs must preserve past nutrition after catalog edits | FAO/INFOODS, data governance | Use food/recipe version and log snapshot tables | Show historical value, not latest catalog value | Edit food after logging; old log remains unchanged |
| Ingredient nutrients must calculate through units | FAO/INFOODS unit conversion | `ingredients`, `units`, conversion factor, edible portion | Recipe editor shows grams/ml basis | 1 tbsp oil, 100 g pork, 1 serving rice calculate correctly |
| Backend formula is source of truth | Mifflin validation, formula consistency risk | Store calculated targets | Flutter displays backend target first | Change formula backend; Flutter display updates without local mismatch |
| Menu recommendations must be explainable | Self-monitoring, DRI/AMDR, ISSN, DGA/WHO | Add backend recommendation score and reason codes | Show reason chips such as "fits protein gap" or "within calorie budget" | Recommended food reason matches score inputs |
| Recommendation must exclude allergy matches | Food allergy safety + app allergy flags | Hard filter by `food_allergy_flags` / `allergy_flag_ids` | Hide allergic foods by default; allow explicit reviewed override only if safe | Food with matching allergy flag never appears in default recommendations |
| Recommendation must not optimize only calories | DGA/WHO/Thai dietary guidance | Add sodium, sugar, fiber, food-group fields where possible | Display high-sodium/high-sugar warning when data exists | Low-calorie but high-sugar item is not labelled "healthy" |
| Recommendation confidence must follow data source | FAO/INFOODS, AI safety | Store `source`, `source_version`, `confidence`, `is_ai_estimate` | Show "verified", "admin approved", or "estimated" | AI-estimated food is lower confidence and requires confirmation |
| AI meal estimate must require confirmation | WHO AI, NIST AI RMF, food image review | Save only after user confirms | Show "estimated by AI" and editable portion | AI estimate cannot silently write final food log |
| AI coach must avoid diagnosis | WHO AI ethics | Prompt guard + scope guard + fallback | Copy: "general nutrition guidance" | Ask medical/disease diagnosis; response refuses or redirects |
| Gamification must avoid punishment | Gamification reviews + BCT taxonomy | Store streak freeze/recovery rules | Supportive streak UI | Missed day does not shame user or reset irreversibly |
| Water selected date must be correct | Hydration logging requirement | Store selected date, timezone | Date picker persists before save | Save yesterday water; appears yesterday only |
| Exercise calories must not double count | Wearable energy-expenditure evidence | Store source and calculation mode | Show source/timestamp/estimate label | TDEE active factor + Health Connect exercise does not add twice |
| Notifications must be controllable | JITAI and behavior-change evidence | Store notification preferences | Frequency/time controls | User can disable or change reminder windows |
| Admin food moderation must be auditable | Food data quality evidence | audit table, review status, reviewer_id | Admin review, reject reason, rollback | Food submission rejected with reason and audit row |
| Health data must be protected | PDPA/GDPR/OWASP | No service-role key in client; secure tokens | Consent screens and delete/export | Static scan and runtime check no secrets in Flutter bundle |
| Charts must be accessible | WCAG/AHRQ | API provides text summaries if useful | Text alternative for charts, contrast | Screen reader can understand chart status |

## 6. Risks and Guardrails

| Risk | Why it matters | Guardrail |
|---|---|---|
| Formula false precision | BMR/TDEE equations are estimates. | Display "estimated"; store formula version; allow adjustment from weight trend. |
| Extreme dieting | Rapid deficit may be unsafe. | Conservative default, minimum calorie warnings, clinician disclaimer. |
| Eating-disorder reinforcement | Calorie tracking can become compulsive for vulnerable users. | Avoid shame language, allow breaks, provide gentle warnings and support resources when appropriate. |
| Incorrect food database values | User-submitted and copied foods can be wrong. | Admin moderation, source provenance, versioning, confidence labels. |
| Recipe calculation error | Units/edible portion/yield can distort nutrient totals. | Unit conversion tests, missing nutrient flags, source documentation. |
| AI hallucination | LLMs can generate plausible but false advice. | Scope guard, no diagnosis, user confirmation, model/prompt logging, kill switch. |
| AI privacy leakage | Chat may contain sensitive health/diet data. | Minimize prompt data, avoid external unnecessary providers, document consent. |
| Wearable calorie overtrust | Energy expenditure estimates vary widely. | Treat as estimate; show source; avoid double counting. |
| Notification fatigue | Too many reminders reduce adherence. | User-controlled schedule, quiet hours, relevance rules. |
| Gamification harm | Punitive streaks can demotivate or shame. | Recovery mechanics, non-punitive copy, opt-out. |
| Security leakage | Health data and Supabase keys are sensitive. | OWASP MASVS controls, no service role keys in clients, secrets only in backend/Railway. |

## 7. QA Test Ideas Derived From Evidence

### Formula QA

1. BMR calculation matches backend formula for male/female test profiles.
2. Flutter displays backend-calculated value even when local fallback differs.
3. Formula version is stored and returned with user goal.
4. Aggressive deficit triggers warning.
5. Gain, loss, and maintenance progress use correct direction.

### Food and Recipe QA

1. Ingredient 100 g basis calculates macros correctly.
2. Unit conversions do not lose precision.
3. Recipe total equals sum of ingredient nutrients.
4. Per-serving values equal total divided by serving count.
5. Editing food catalog does not mutate historical log snapshot.
6. Missing significant nutrient data is flagged.
7. ThaiFCD source/version is visible in admin data dictionary.

### Recommendation QA

1. Recommended menu excludes foods matching the user's allergy flags.
2. Protein recommendation uses `remaining_protein = target_protein - consumed_protein` and does not suggest foods that exceed the remaining macro budget.
3. Calorie fit uses backend `target_calories` and today's consumed calories, not an unlabelled Flutter-only fallback.
4. Recommendation reason text matches the actual score driver: protein gap, calorie fit, low sugar, low sodium, user preference, or data confidence.
5. Frequency personalization does not permanently repeat the same food; variety score reduces repeated foods in the last 3-7 days.
6. Low-calorie but high-sugar/high-sodium foods are warned or down-ranked when data exists.
7. AI-estimated or user-submitted foods show lower confidence and require confirmation before saving.
8. Changing food data source/version changes confidence/reason labels but does not mutate historical logs.

### AI QA

1. Off-topic prompt is rejected.
2. Medical diagnosis prompt is refused or redirected.
3. AI meal estimate requires user confirmation.
4. Bad JSON from model raises typed error.
5. Ollama unavailable returns friendly fallback.
6. `/api/chat/health` reports AI enabled/model/base URL without leaking secrets.
7. Kill switch disables AI endpoints.

### Security and Privacy QA

1. Flutter bundle contains no Supabase service-role key.
2. Health Connect permission denial is handled gracefully.
3. User can revoke health integration.
4. Account deletion removes or anonymizes personal logs according to policy.
5. Sensitive endpoints require auth.
6. Admin audit logs cannot be edited by normal users.

### UX and Accessibility QA

1. Chart has text summary.
2. Thai labels are plain language.
3. Buttons and status messages meet WCAG contrast and announcement requirements.
4. Notification settings can be changed or disabled.
5. Missed streak state uses supportive copy.

## 8. Research Gaps and Internal Validation Plan

| Gap | Why it matters | Suggested validation |
|---|---|---|
| Thai-specific food logging adherence | Most self-monitoring studies are not Thai-context apps. | Run 2-4 week pilot with Thai users; measure logs/day, drop-off, correction rate. |
| Thai dish portion estimation | Portion size is a major error source. | Compare AI/user estimates with weighed portions for common Thai dishes. |
| Gamification/pet progression effect | Evidence supports engagement, not guaranteed health outcomes. | A/B test pet progression vs no pet progression for retention and logging adherence. |
| AI coach trust and safety in Thai | LLM nutrition advice accuracy varies. | Create Thai nutrition prompt benchmark with expected safe answers. |
| Water target personalization | Universal targets are weak. | Test editable conservative default vs personalized target satisfaction. |
| Food database moderation workload | User-submitted data can scale badly. | Track submission volume, rejection rate, duplicate rate, reviewer time. |
| Thai menu recommendation algorithm | Evidence supports ingredients, macro targets, and dietary patterns, but not one universal Thai-menu scoring formula. | A/B test simple macro filter vs explainable score; measure selection rate, correction rate, allergy near-miss rate, repeat-food rate, and user trust. |
| Sodium/sugar/fiber completeness | Recommendation quality is limited if food records have only calories/protein/carbs/fat. | Prioritize ThaiFCD/import fields for sodium, sugar, fiber, saturated fat, food group, and source confidence. |
| Asian BMR correction in Flutter fallback | Current Flutter fallback applies an Asian correction factor, but backend does not. | Decide one source-of-truth formula version; validate Thai/Asian equation choice and show fallback as estimated when used. |

## 9. Source List With Links

1. Burke et al. Self-Monitoring in Weight Loss: A Systematic Review of the Literature. https://pmc.ncbi.nlm.nih.gov/articles/PMC3268700/
2. Patel et al. A systematic review of dietary self-monitoring in behavioural weight loss interventions. https://pmc.ncbi.nlm.nih.gov/articles/PMC8928602/
3. Mobile Apps for Health Behavior Change in Physical Activity, Diet, Drug and Alcohol Use, and Mental Health: Systematic Review. https://mhealth.jmir.org/2020/3/e17046/
4. Schoeppe et al. Efficacy of interventions that use apps to improve diet, physical activity and sedentary behaviour. https://pmc.ncbi.nlm.nih.gov/articles/PMC5142356/
5. Mifflin et al. A New Predictive Equation for Resting Energy Expenditure in Healthy Individuals. https://doi.org/10.1093/ajcn/51.2.241
6. Frankenfield et al. Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults. https://pubmed.ncbi.nlm.nih.gov/15883556/
7. Harris and Benedict. A Biometric Study of Human Basal Metabolism. https://pubmed.ncbi.nlm.nih.gov/16576330/
8. CDC. Steps for Losing Weight. https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
9. American Diabetes Association weight-loss program criteria PDF. https://diabetes.org/sites/default/files/2023-09/Weight%20Loss%20Program%20Criteria.pdf
10. National Academies. Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids. https://nap.nationalacademies.org/catalog/10490/dietary-reference-intakes-for-energy-carbohydrate-fiber-fat-fatty-acids-cholesterol-protein-and-amino-acids
11. NCBI Bookshelf DRI reference tables. https://www.ncbi.nlm.nih.gov/books/NBK208874/
12. Michie et al. Behavior Change Technique Taxonomy v1. https://doi.org/10.1007/s12160-013-9486-6
13. EFSA. Scientific Opinion on Dietary Reference Values for water. https://www.efsa.europa.eu/en/efsajournal/pub/1459
14. EFSA. Dietary reference values topic. https://www.efsa.europa.eu/en/topics/topic/dietary-reference-values
15. FAO/INFOODS Standards and Guidelines. https://www.fao.org/infoods/infoods/standards-guidelines/en/
16. FAO. Food Composition Data chapter. https://www.fao.org/4/y4705e/y4705e06.htm
17. FAO/INFOODS Guidelines for Checking Food Composition Data. https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/Guidelines_data_checking2012.pdf
18. FAO. Thai Food Composition Database 2025 entry. https://www.fao.org/food-composition/tables-and-databases-2/detail/%28thailand--2025%29-thai-food-composition-database/en
19. Institute of Nutrition, Mahidol University. ASEAN Food Composition Database. https://inmu.mahidol.ac.th/aseanfoods/composition_data.html
20. FAO. Food composition tables for Thailand. https://www.fao.org/infoods/infoods/tables-and-databases/thailand/en/
21. USDA FoodData Central API guide. https://fdc.nal.usda.gov/api-guide
22. USDA FoodData Central FAQ. https://fdc.nal.usda.gov/faq
23. User-documented food consumption data from publicly available apps. https://nutritionj.biomedcentral.com/articles/10.1186/s12937-018-0366-6
24. Effect of digital health applications with or without gamification. https://pmc.ncbi.nlm.nih.gov/articles/PMC11701442/
25. Gamification for Family Engagement in Lifestyle Interventions. https://pmc.ncbi.nlm.nih.gov/articles/PMC8460596/
26. Serious games for healthy diet and physical activity. https://pmc.ncbi.nlm.nih.gov/articles/PMC10056209/
27. WHO. Ethics and governance of artificial intelligence for health. https://www.who.int/publications/i/item/9789240029200
28. NIST AI Risk Management Framework 1.0. https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-ai-rmf-10
29. Large Language Models as Clinical Nutrition Decision Tools. https://pmc.ncbi.nlm.nih.gov/articles/PMC13026456/
30. Mobile computer vision food recognition and calorific estimation systematic review. https://www.mdpi.com/2029682
31. Systematic review of consumer wearable activity trackers. https://pmc.ncbi.nlm.nih.gov/articles/PMC4683756/
32. Accuracy and Precision of Energy Expenditure, Heart Rate, and Steps Measured by Fitbits. https://pmc.ncbi.nlm.nih.gov/articles/PMC9047731/
33. Android Health Connect availability and permissions. https://developer.android.com/health-and-fitness/health-connect/availability
34. Systematic review of JITAIs for physical activity. https://link.springer.com/article/10.1186/s12966-019-0792-7
35. EDPB. Data protection basics. https://www.edpb.europa.eu/sme-data-protection-guide/data-protection-basics_en
36. EDPB. Process personal data lawfully. https://www.edpb.europa.eu/sme-data-protection-guide/process-personal-data-lawfully_en
37. Thailand PDPC GPPC Plus. https://register-gppc-plus.pdpc.or.th/
38. OWASP MASVS. https://mas.owasp.org/MASVS/
39. W3C WCAG 2.2. https://www.w3.org/TR/wcag/
40. AHRQ Health Literacy Universal Precautions Toolkit. https://www.ahrq.gov/health-literacy/improve/precautions/index.html
41. Dietary Guidelines for Americans 2020-2025. https://www.dietaryguidelines.gov/sites/default/files/2020-12/Dietary_Guidelines_for_Americans_2020-2025.pdf
42. CDC. Healthy Eating for a Healthy Weight. https://www.cdc.gov/healthy-weight-growth/healthy-eating/
43. Jager et al. International Society of Sports Nutrition Position Stand: protein and exercise. https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8
44. Morton et al. Protein supplementation and resistance training meta-analysis. https://pubmed.ncbi.nlm.nih.gov/28698222/
45. WHO. Salt reduction. https://www.who.int/news-room/fact-sheets/detail/salt-reduction
46. WHO. Healthy diet. https://www.who.int/news-room/fact-sheets/detail/healthy-diet
47. PortionSize validation study. https://pmc.ncbi.nlm.nih.gov/articles/PMC9244674/
48. Dietary assessment measurement error overview. https://nutritionalassessment.org/errors/index.html

## 10. Final App Positioning Statement

Calories Guard should describe itself as:

> A nutrition self-monitoring and behavior-support app that estimates calorie and nutrient targets using evidence-based formulas and curated food-composition data, helps users log meals, recipes, hydration, weight, and activity, and uses AI only as an assistive feature with uncertainty labels and user confirmation.

It should **not** describe itself as:

> A medical diagnosis, disease-treatment, or guaranteed weight-loss system.

That distinction is important for safety, user trust, and regulatory/privacy risk.

