# 🎙️ GlycoLens: 3-Minute Hackathon Pitch & Demo Script

> **Product Definition**: AI-powered hypoglycemia early-warning & Indian meal carbohydrate estimator for Type 1 Diabetes self-management. Decision-support only (non-medical device).

---

## ⏱️ Minute-by-Minute Pitch Script

### Minute 0:00 – 1:00 | The Hook & The Problem
**[Speaker holds up phone showing the GlycoLens dashboard or slides]**

> *"Over 8 million people live with Type 1 Diabetes worldwide, and India has one of the highest pediatric and young adult cohorts. For a person with T1D, food is math: every meal requires calculating grams of carbs to match insulin.*
> 
> *Here is the problem: **Existing calorie counters fail completely on Indian diets.** Western databases assume a uniform slice of bread or a single apple. In an Indian home, a thali contains complex carbohydrates, mixed lentils, and variable ghee that drastically alters glycemic absorption kinetics.*
> 
> *A 20% carb estimation error can cause severe **hypoglycemia**—where blood glucose crashes below 70 mg/dL, causing tremors, seizures, or coma.*
> 
> *Meet **GlycoLens**: An AI decision-support platform designed specifically for Indian meals that detects dishes, calibrates portions using standard Indian katoris, and forecasts glucose 60 minutes into the future to alert users before a low occurs."*

---

### Minute 1:00 – 2:00 | Live Demo on Phone / Camera
**[Speaker switches to phone screen running GlycoLens]**

1. **Dashboard & Scenario 1 (Post-Meal Low)**:
   > *"On our dashboard, you see real-time CGM readings and our PyTorch LSTM forecast band. Notice this red alert: glucose is 72 mg/dL and falling rapidly at 1.6 mg/dL/min. The model projects a crash to 58 mg/dL in 35 minutes.*
   > 
   > *With one tap on the alert, GlycoLens opens our **Rule of 15 Recovery Protocol** with an active 15-minute clinical timer and exact fast-acting carb guidance."*

2. **Indian Meal Capture & Calibration**:
   > *"Now watch our carb estimator in action. We go to 'Capture Meal'. The patient places their plate next to a standard Indian steel **katori** (which has an exact 9 cm diameter and 150 ml reference capacity).*
   > 
   > *Our YOLOv8 detector segments the dishes—here detecting Roti, Dal Tadka, and Steamed Basmati Rice. Using bounding-box area ratios against the katori, it estimates grams and queries the official **ICMR Indian Food Composition Tables (IFCT)** to compute exact net carbs, dietary fiber, and glycemic load.*
   > 
   > *And if the estimate needs a tweak? The user can **one-tap adjust with our tactile sliders** (-25g, +25g, ½ katori). Once confirmed, carbs immediately feed back into our forecaster."*

---

### Minute 2:00 – 3:00 | ML Rigor, Clinical Metrics & Safety
**[Speaker displays the Clarke Error Grid slide from docs/evaluation.md]**

> *"Unlike hackathon projects with toy loss curves, we evaluated GlycoLens against real clinical standards:*
> 
> 1. **Physiological Simulator**: *We simulated a 10-patient T1D cohort (adults and adolescents) over 11,520 readings using the FDA-accepted simglucose Bergman minimal model ODEs.*
> 2. **PyTorch LSTM**: *Benchmarked against Linear Baselines, MLPs, and TCNs, our PyTorch LSTM achieved a 60-minute RMSE of **6.87 mg/dL**.*
> 3. **Clarke Error Grid (EGA)**: *The gold-standard clinical metric for diabetes tech. GlycoLens achieved **99.2% in Zone A + B**, well exceeding the 95% clinical acceptance threshold.*
> 4. **Early Warning Sensitivity**: *We achieved **94.2% sensitivity** in detecting hypoglycemia with an advance lead time of **~40 minutes**.*
> 
> *Finally, **Safety & Regulatory Compliance**: GlycoLens is strictly non-diagnostic decision-support. It never automates insulin dosing and displays clear clinical disclaimers.*
> 
> *GlycoLens turns diabetes meal anxiety into proactive, culture-aware early warning. Thank you!"*

---

## 🎯 Judges' FAQ Cheat Sheet

| Question from Judges | Your Winning Answer |
| :--- | :--- |
| **"Why not use ChatGPT / GPT-4V for food photos?"** | *"LLM vision models suffer from hallucination and high latency (4-8 seconds). GlycoLens uses an on-device/local YOLOv8 engine that runs in **< 50 milliseconds**, operates offline, and grounds every carb calculation in deterministic ICMR nutrition tables."* |
| **"How do you measure portion volume from a 2D photo?"** | *"We use reference-object visual area calibration. Every Indian household uses standard steel katoris (9cm diameter). By computing $\frac{\text{Dish Area}}{\text{Katori Area}} \times \text{Density}$, we estimate grams without requiring expensive 3D LiDAR sensors. If no katori is detected, the app automatically flags the item for 1-tap review."* |
| **"What if your ML model predicts wrong and harms the patient?"** | *"GlycoLens is strictly decision-support and never doses insulin. Alongside the ML model, we have a hard-coded deterministic clinical rule engine based on ISPAD guidelines. If glucose is falling $>2\text{ mg/dL/min}$, the deterministic safety alert fires regardless of model predictions."* |
| **"What is the future roadmap?"** | *"1. Bluetooth integration with Dexcom G7 / Abbott FreeStyle Libre CGMs. 2. Regional dataset expansions for South Indian, Gujarati, and Bengali cuisines. 3. Observational clinical trial partnership with local endocrinology clinics."* |
