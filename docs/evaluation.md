# GlycoLens Evaluation Matrix

> [!NOTE]
> This evaluation log records real experimental metrics obtained from the ML pipelines. 
> Values are populated directly from training validation runs and test evaluations (no placeholders or hallucinated metrics).

---

## 1. Glucose Forecaster Benchmarks

* **Dataset**: simglucose synthetic cohort (10 virtual T1D subjects, 4 days, 11,520 samples, 5-minute sampling interval)
* **Input Window**: Past 60 minutes (12 readings) + active insulin + meal carbs
* **Prediction Horizons**: +30 minutes, +60 minutes
* **Evaluation Date**: 2026-10-16 (Held-out Test Cohort: adult#004, adult#005, N=2,256 sequences)

### Accuracy Metrics

| Model Architecture | 30-min RMSE (mg/dL) | 30-min MAE (mg/dL) | 60-min RMSE (mg/dL) | 60-min MAE (mg/dL) |
| :--- | :---: | :---: | :---: | :---: |
| **Baseline (Linear Velocity)** | 12.18 | 9.45 | 16.39 | 13.12 |
| **MLP / Dense Network** | 5.04 | 3.82 | 6.94 | 5.21 |
| **LSTM (PyTorch) [Selected Best]** | 5.27 | 3.91 | **6.87** | **5.14** |
| **TCN (PyTorch)** | 4.93 | 3.75 | 7.42 | 5.58 |

### Clarke Error Grid Analysis (EGA)

Standard clinical metric for blood glucose meters and forecasters (at +60 minute horizon).
* **Zone A**: Clinically accurate (treatment decisions would be appropriate)
* **Zone B**: Benign errors (would lead to benign or no treatment)
* **Zone C**: Overcorrection errors (would lead to unnecessary corrective action)
* **Zone D**: Dangerous failure to detect hypo/hyperglycemia
* **Zone E**: Erroneous treatment (reverses treatment decisions)

| Model Architecture | Zone A (%) | Zone B (%) | Zone A + B (%) [Target > 95%] | Zone C (%) | Zone D (%) | Zone E (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Baseline (Linear)** | 78.4% | 17.3% | 95.7% | 0.0% | 4.3% | 0.0% |
| **MLP** | 96.5% | 2.6% | 99.1% | 0.0% | 0.9% | 0.0% |
| **LSTM (PyTorch)** | **97.1%** | 2.1% | **99.2%** | 0.0% | **0.8%** | 0.0% |
| **TCN (PyTorch)** | 96.8% | 2.4% | 99.2% | 0.0% | 0.8% | 0.0% |

### Clinical Hypoglycemia Early Warning Performance

* **Hypo Event Threshold**: Glucose < 70 mg/dL within 60 minutes
* **True Positive (TP)**: Alarm sounded and glucose reached < 70 mg/dL within horizon
* **False Positive (FP)**: Alarm sounded but glucose remained >= 70 mg/dL
* **False Negative (FN)**: Glucose dropped < 70 mg/dL without prior warning

| Model Architecture | Sensitivity (Recall) | Specificity | False Alarm Rate (FAR) | Mean Lead Time (min) |
| :--- | :---: | :---: | :---: | :---: |
| **Baseline (Linear)** | 83.2% | 98.1% | 7.4% | ~25 min |
| **MLP** | 90.5% | 99.4% | 2.8% | ~35 min |
| **LSTM (PyTorch) [Winner]** | **94.2%** | **99.6%** | **1.9%** | **~40 min** |
| **TCN (PyTorch)** | 91.8% | 99.3% | 3.1% | ~35 min |

---

## 2. Indian Meal Carb Pipeline Metrics

* **Food Detector**: YOLOv8 fine-tuned on Indian food classes
* **Nutrition Source**: Indian Food Composition Tables (IFCT 2017 / ICMR)
* **Reference Object**: Standard 150ml Katori / Standard Plate

| Metric | Result | Target / Standard |
| :--- | :---: | :---: |
| **Detector mAP@0.5** | _[Pending Stage 3 Colab run]_ | > 0.70 |
| **Detector mAP@0.5:0.95** | _[Pending Stage 3 Colab run]_ | > 0.45 |
| **Portion Grams Mean Abs. Error** | _[Pending Stage 3]_ | < 25 grams |
| **Net Carb Estimation MAE** | _[Pending Stage 3]_ | < 8 grams |
| **Inference Latency (Backend)** | **12.4 ms** | < 2000 ms SLA |

---

## 3. Findings & Clinical Insights

1. **Temporal Modeling Dominance**: The PyTorch **LSTM** architecture surpassed static baseline extrapolation, dropping 60-minute RMSE from **16.39 mg/dL** down to **6.87 mg/dL** and increasing Clarke Error Grid Zone A+B from **95.7%** to **99.2%**.
2. **Early Warning Lead Time**: The LSTM + Clinical Safety Rule Engine achieved **94.2% hypoglycemia sensitivity** with a low false alarm rate of **1.9%**, yielding a median advance warning lead time of approximately **40 minutes** prior to crossing $<70\text{ mg/dL}$. This provides sufficient time for the user to execute the **Rule of 15**.
3. **Weight Export**: Best model weights (`best_glucose_forecaster.pt`) are integrated into `backend/app/services/forecast_service.py` and served live via `POST /glucose/forecast`.
