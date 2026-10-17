import pytest
import numpy as np
from ml.evaluation.clarke_error_grid import clarke_error_grid
from ml.evaluation.metrics import compute_forecasting_metrics
from ml.training.models import BaselineLinearForecaster

def test_clarke_error_grid_perfect_accuracy():
    # When predictions equal reference, 100% must be in Zone A
    ref = np.array([80, 110, 150, 70, 60, 200, 250], dtype=float)
    pred = np.array([80, 110, 150, 70, 60, 200, 250], dtype=float)
    
    zones = clarke_error_grid(ref, pred)
    assert zones["A"] == 100.0
    assert zones["A_plus_B"] == 100.0
    assert zones["C"] == 0.0
    assert zones["D"] == 0.0
    assert zones["E"] == 0.0

def test_clarke_error_grid_benign_errors():
    # 10% errors should remain in Zone A
    ref = np.array([100, 150, 200], dtype=float)
    pred = np.array([110, 160, 215], dtype=float)
    
    zones = clarke_error_grid(ref, pred)
    assert zones["A"] == 100.0

def test_clarke_error_grid_dangerous_failure_zone_d():
    # Hypo missed: True glucose is 50 mg/dL, but predicted is 120 mg/dL
    ref = np.array([50.0])
    pred = np.array([120.0])
    
    zones = clarke_error_grid(ref, pred)
    assert zones["D"] == 100.0

def test_forecasting_metrics_computation():
    y_true_30 = np.array([100, 120, 80])
    y_pred_30 = np.array([105, 125, 75])
    y_true_60 = np.array([65, 130, 90])  # One true hypo at index 0 (<70)
    y_pred_60 = np.array([62, 135, 92])  # Correctly flagged hypo at index 0 (<70)
    
    metrics = compute_forecasting_metrics(y_true_30, y_pred_30, y_true_60, y_pred_60)
    assert metrics["mae_30m"] == 5.0
    assert metrics["hypo_sensitivity"] == 100.0  # 1/1 detected
    assert metrics["false_alarm_rate"] == 0.0

def test_baseline_forecaster_output_shape():
    # Batch of 4 samples, 12 time steps, 4 features
    X = np.random.uniform(70.0, 180.0, size=(4, 12, 4)).astype(np.float32)
    baseline = BaselineLinearForecaster()
    preds = baseline.predict(X)
    
    assert preds.shape == (4, 2)
    assert np.all(preds >= 35.0)
    assert np.all(preds <= 500.0)
