import numpy as np
from typing import Dict, Any

def compute_forecasting_metrics(
    y_true_30: np.ndarray,
    y_pred_30: np.ndarray,
    y_true_60: np.ndarray,
    y_pred_60: np.ndarray,
    hypo_threshold: float = 70.0
) -> Dict[str, Any]:
    """
    Computes statistical and clinical metrics for +30m and +60m glucose forecasting.
    """
    y_true_30 = np.asarray(y_true_30, dtype=float)
    y_pred_30 = np.asarray(y_pred_30, dtype=float)
    y_true_60 = np.asarray(y_true_60, dtype=float)
    y_pred_60 = np.asarray(y_pred_60, dtype=float)

    # 1. Error metrics
    mae_30 = float(np.mean(np.abs(y_pred_30 - y_true_30)))
    rmse_30 = float(np.sqrt(np.mean((y_pred_30 - y_true_30) ** 2)))

    mae_60 = float(np.mean(np.abs(y_pred_60 - y_true_60)))
    rmse_60 = float(np.sqrt(np.mean((y_pred_60 - y_true_60) ** 2)))

    # 2. Hypoglycemia event classification metrics (at 60m horizon)
    actual_hypo = y_true_60 < hypo_threshold
    pred_hypo = y_pred_60 < hypo_threshold

    tp = int(np.sum(actual_hypo & pred_hypo))
    fp = int(np.sum((~actual_hypo) & pred_hypo))
    fn = int(np.sum(actual_hypo & (~pred_hypo)))
    tn = int(np.sum((~actual_hypo) & (~pred_hypo)))

    sensitivity = round((tp / (tp + fn)) * 100.0, 2) if (tp + fn) > 0 else 0.0
    specificity = round((tn / (tn + fp)) * 100.0, 2) if (tn + fp) > 0 else 100.0
    false_alarm_rate = round((fp / (tp + fp)) * 100.0, 2) if (tp + fp) > 0 else 0.0

    return {
        "rmse_30m": round(rmse_30, 2),
        "mae_30m": round(mae_30, 2),
        "rmse_60m": round(rmse_60, 2),
        "mae_60m": round(mae_60, 2),
        "hypo_sensitivity": sensitivity,
        "hypo_specificity": specificity,
        "false_alarm_rate": false_alarm_rate,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "tn": tn
    }
