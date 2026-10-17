import logging
from typing import Tuple, List, Dict
import numpy as np
import pandas as pd
from torch.utils.data import Dataset

logger = logging.getLogger("glycolens.dataset")

def create_windowed_sequences(
    df: pd.DataFrame,
    input_window: int = 12,    # 12 steps * 5m = 60 minutes history
    horizon_30m: int = 6,      # +6 steps * 5m = +30 minutes
    horizon_60m: int = 12      # +12 steps * 5m = +60 minutes
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Constructs sequence samples from patient time-series:
      X: shape (N, input_window, num_features)
      y: shape (N, 2) where targets are [glucose_+30m, glucose_+60m]
    """
    X_list = []
    y_list = []

    # Process each patient trace independently to prevent cross-subject sequence boundary errors
    for pid, group in df.groupby("patient_id"):
        group = group.sort_values("timestamp").reset_index(drop=True)
        
        glucose = group["glucose_mg_dl"].values
        insulin = group["insulin_units"].values
        carbs = group["carbs_grams"].values
        
        # Calculate velocity (rate of change in mg/dL/min, sampled every 5m)
        velocity = np.zeros_like(glucose)
        velocity[1:] = (glucose[1:] - glucose[:-1]) / 5.0

        features = np.stack([glucose, insulin, carbs, velocity], axis=1)  # (T, 4)
        total_len = len(glucose)
        max_idx = total_len - horizon_60m

        for i in range(input_window, max_idx):
            x_seq = features[i - input_window:i]  # shape (12, 4)
            target_30 = glucose[i + horizon_30m]
            target_60 = glucose[i + horizon_60m]
            
            X_list.append(x_seq)
            y_list.append([target_30, target_60])

    X = np.array(X_list, dtype=np.float32)
    y = np.array(y_list, dtype=np.float32)
    return X, y

class GlucoseDataset(Dataset):
    def __init__(self, X: np.ndarray, y: np.ndarray):
        import torch
        self.X = torch.tensor(X, dtype=torch.float32)
        self.y = torch.tensor(y, dtype=torch.float32)

    def __len__(self):
        return len(self.X)

    def __getitem__(self, idx):
        return self.X[idx], self.y[idx]

def get_train_val_test_splits(
    df: pd.DataFrame
) -> Tuple[Tuple[np.ndarray, np.ndarray], Tuple[np.ndarray, np.ndarray], Tuple[np.ndarray, np.ndarray]]:
    """
    Splits cohort by subjects to guarantee zero data leakage between training and testing.
    Train: 7 subjects
    Val:   1 subject
    Test:  2 subjects (held-out test cohort)
    """
    patients = sorted(df["patient_id"].unique())
    train_pids = patients[:7]
    val_pids = [patients[7]]
    test_pids = patients[8:]

    logger.info(f"Cohort splits -> Train: {train_pids}, Val: {val_pids}, Test: {test_pids}")

    train_df = df[df["patient_id"].isin(train_pids)]
    val_df = df[df["patient_id"].isin(val_pids)]
    test_df = df[df["patient_id"].isin(test_pids)]

    X_train, y_train = create_windowed_sequences(train_df)
    X_val, y_val = create_windowed_sequences(val_df)
    X_test, y_test = create_windowed_sequences(test_df)

    logger.info(f"Sequence counts -> Train: {len(X_train)}, Val: {len(X_val)}, Test: {len(X_test)}")
    return (X_train, y_train), (X_val, y_val), (X_test, y_test)
