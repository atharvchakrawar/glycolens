import numpy as np
from typing import Dict, Tuple

def clarke_error_grid(ref_values: np.ndarray, pred_values: np.ndarray) -> Dict[str, float]:
    """
    Computes Clarke Error Grid Analysis (EGA) zones (A, B, C, D, E)
    for reference (true) vs predicted blood glucose values (in mg/dL).
    
    Zones:
      - Zone A: Clinically accurate (leads to correct treatment)
      - Zone B: Benign errors (acceptable, no harm)
      - Zone C: Overcorrection (unnecessary treatment)
      - Zone D: Dangerous failure to detect hypo/hyperglycemia
      - Zone E: Erroneous treatment (reverses clinical decision)
    """
    ref = np.asarray(ref_values, dtype=float)
    pred = np.asarray(pred_values, dtype=float)
    
    n_points = len(ref)
    if n_points == 0:
        return {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0, "E": 0.0, "A_plus_B": 0.0}

    zone_counts = {"A": 0, "B": 0, "C": 0, "D": 0, "E": 0}

    for r, p in zip(ref, pred):
        # 1. Zone A:
        # |p - r| <= 0.20 * r OR (r <= 70 and p <= 70)
        if (p <= 70.0 and r <= 70.0) or (abs(p - r) <= 0.20 * r):
            zone_counts["A"] += 1
            continue

        # 2. Zone E:
        # (r <= 70 and p >= 180) OR (r >= 180 and p <= 70)
        if (r <= 70.0 and p >= 180.0) or (r >= 180.0 and p <= 70.0):
            zone_counts["E"] += 1
            continue

        # 3. Zone D:
        # Failure to detect: (r < 70 and p > 70) OR (r > 240 and p < 180)
        # except when in Zone B
        if (r < 70.0 and p > 70.0 and p < 180.0) or (r > 240.0 and p >= 70.0 and p <= 180.0):
            zone_counts["D"] += 1
            continue

        # 4. Zone C:
        # Overcorrection: (r >= 70 and r <= 180 and p > 180) OR (r >= 70 and r <= 180 and p < 70)
        # or when treatment would overcorrect
        if (70.0 <= r <= 180.0 and (p > (r + 110.0) or p < (r - 110.0))):
            zone_counts["C"] += 1
            continue

        # 5. Zone B:
        # Benign deviations that do not cause severe treatment errors
        zone_counts["B"] += 1

    zone_percentages = {
        k: round((v / n_points) * 100.0, 2)
        for k, v in zone_counts.items()
    }
    zone_percentages["A_plus_B"] = round(zone_percentages["A"] + zone_percentages["B"], 2)
    return zone_percentages
