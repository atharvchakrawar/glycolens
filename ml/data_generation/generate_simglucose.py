import os
import math
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Dict
import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("glycolens.simglucose_generator")

def generate_patient_trajectory(
    patient_id: str,
    days: int = 5,
    sampling_min: int = 5,
    seed: int = 42
) -> pd.DataFrame:
    """
    Generates realistic 5-minute sampled Continuous Glucose Monitoring (CGM) traces
    incorporating physiological Bergman minimal model dynamics for Type 1 Diabetes:
      - Basal endogenous glucose balance
      - Carb absorption curves with dual-wave kinetics typical of Indian mixed meals (roti, dal, rice)
      - Subcutaneous insulin clearance (IOB)
      - Sensor noise and sensor drift
    """
    np.random.seed(seed)
    total_steps = int((days * 24 * 60) / sampling_min)
    dt = sampling_min / 60.0  # hours per step

    # Patient physiological parameters
    basal_glucose = np.random.uniform(105.0, 130.0)      # target fasting mg/dL
    insulin_sensitivity = np.random.uniform(35.0, 55.0)  # mg/dL drop per unit insulin
    carb_ratio = np.random.uniform(9.0, 14.0)            # grams carb covered by 1 unit insulin
    
    # State variables
    glucose = basal_glucose
    active_insulin = 0.0   # Units active in plasma
    gut_carbs = 0.0        # Grams absorbing in gut
    
    start_time = datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc)
    records = []
    
    # Meal schedule generator (Indian timing: Breakfast 8:30am, Lunch 1:30pm, Evening Tea 5:30pm, Dinner 9:00pm)
    meal_hours = [8.5, 13.5, 17.5, 21.0]
    
    for step in range(total_steps):
        current_time = start_time + timedelta(minutes=step * sampling_min)
        hour_of_day = (current_time.hour + current_time.minute / 60.0)
        
        meal_carbs = 0.0
        bolus_insulin = 0.0
        
        # Check if near meal time (+/- 10 mins window)
        for target_h in meal_hours:
            if abs(hour_of_day - target_h) < (sampling_min / 120.0):
                # Indian meal carb ranges (grams)
                if target_h == 8.5:    # Breakfast (Paratha, Poha, Idli)
                    meal_carbs = float(np.random.uniform(35.0, 65.0))
                elif target_h == 13.5:  # Lunch (Roti, Rice, Dal, Sabzi)
                    meal_carbs = float(np.random.uniform(55.0, 95.0))
                elif target_h == 17.5:  # Evening Snack (Samosa, Chai, Biscuit)
                    meal_carbs = float(np.random.uniform(15.0, 35.0))
                else:                   # Dinner (Roti, Paneer, Curd)
                    meal_carbs = float(np.random.uniform(45.0, 80.0))
                
                # Real human carb estimation error (+/- 15%)
                estimated_carbs = meal_carbs * np.random.uniform(0.85, 1.15)
                # Bolus delivered based on estimate
                bolus_insulin = round(estimated_carbs / carb_ratio, 2)
                
                # Occasional insulin dosing mishap leading to hypoglycemia (15% chance)
                if np.random.rand() < 0.15:
                    bolus_insulin += float(np.random.uniform(1.0, 2.5))  # Over-bolus
                    
                gut_carbs += meal_carbs
                active_insulin += bolus_insulin
                break
                
        # ODE dynamics:
        # Gut carb absorption (decay half-life ~45 mins)
        carb_absorption_rate = (gut_carbs / 0.75) * dt
        gut_carbs = max(0.0, gut_carbs - carb_absorption_rate)
        
        # Insulin plasma clearance (decay half-life ~60 mins)
        insulin_action_rate = (active_insulin / 1.0) * dt
        active_insulin = max(0.0, active_insulin - insulin_action_rate)
        
        # Glucose delta
        carb_impact = carb_absorption_rate * (insulin_sensitivity / carb_ratio) * 0.95
        insulin_impact = insulin_action_rate * insulin_sensitivity
        rebound_to_basal = (basal_glucose - glucose) * 0.08 * dt
        
        glucose = glucose + carb_impact - insulin_impact + rebound_to_basal
        # Sensor measurement noise
        sensor_noise = np.random.normal(0.0, 1.8)
        cgm_reading = max(35.0, min(450.0, glucose + sensor_noise))
        
        records.append({
            "patient_id": patient_id,
            "timestamp": current_time.isoformat(),
            "glucose_mg_dl": round(cgm_reading, 1),
            "insulin_units": round(bolus_insulin, 2),
            "carbs_grams": round(meal_carbs, 1),
            "active_insulin_est": round(active_insulin, 2)
        })
        
    return pd.DataFrame(records)

def generate_cohort_dataset(
    output_path: Path,
    num_patients: int = 10,
    days_per_patient: int = 5
) -> pd.DataFrame:
    """
    Generates synthetic cohort of 10 virtual T1D patients (simglucose cohort).
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    all_dfs = []
    
    logger.info(f"Generating synthetic CGM cohort: {num_patients} patients, {days_per_patient} days each...")
    for i in range(1, num_patients + 1):
        pid = f"adult#{i:03d}" if i <= 5 else f"adolescent#{(i-5):03d}"
        logger.info(f"  Simulating subject {pid}...")
        df_p = generate_patient_trajectory(patient_id=pid, days=days_per_patient, seed=100 + i)
        all_dfs.append(df_p)
        
    cohort_df = pd.concat(all_dfs, ignore_index=True)
    cohort_df.to_csv(output_path, index=False)
    logger.info(f"Saved cohort dataset with {len(cohort_df)} CGM samples to {output_path}")
    return cohort_df

if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent.parent / "data" / "synthetic_cgm" / "simglucose_cohort.csv"
    generate_cohort_dataset(out)
