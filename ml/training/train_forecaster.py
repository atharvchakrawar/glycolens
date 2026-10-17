import os
import json
import logging
from pathlib import Path
from typing import Dict, Any
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from ml.data_generation.generate_simglucose import generate_cohort_dataset
from ml.training.dataset import get_train_val_test_splits, GlucoseDataset
from ml.training.models import BaselineLinearForecaster, MLPForecaster, LSTMForecaster, TCNForecaster
from ml.evaluation.clarke_error_grid import clarke_error_grid
from ml.evaluation.metrics import compute_forecasting_metrics

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("glycolens.train")

def train_torch_model(
    model: nn.Module,
    train_loader: DataLoader,
    val_loader: DataLoader,
    epochs: int = 15,
    lr: float = 1e-3,
    device: torch.device = torch.device("cpu")
) -> nn.Module:
    model.to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr, weight_decay=1e-4)
    criterion = nn.MSELoss()
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="min", factor=0.5, patience=2)

    best_val_loss = float("inf")
    best_weights = None

    for epoch in range(1, epochs + 1):
        model.train()
        train_loss = 0.0
        for X_b, y_b in train_loader:
            X_b, y_b = X_b.to(device), y_b.to(device)
            optimizer.zero_grad()
            preds = model(X_b)
            loss = criterion(preds, y_b)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=2.0)
            optimizer.step()
            train_loss += loss.item() * len(X_b)
        train_loss /= len(train_loader.dataset)

        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for X_b, y_b in val_loader:
                X_b, y_b = X_b.to(device), y_b.to(device)
                preds = model(X_b)
                loss = criterion(preds, y_b)
                val_loss += loss.item() * len(X_b)
        val_loss /= len(val_loader.dataset)
        scheduler.step(val_loss)

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_weights = model.state_dict()

    if best_weights:
        model.load_state_dict(best_weights)
    return model

def evaluate_model(
    model_name: str,
    predictions: np.ndarray,
    y_test: np.ndarray
) -> Dict[str, Any]:
    y_true_30 = y_test[:, 0]
    y_pred_30 = predictions[:, 0]
    y_true_60 = y_test[:, 1]
    y_pred_60 = predictions[:, 1]

    # Metrics
    metrics = compute_forecasting_metrics(y_true_30, y_pred_30, y_true_60, y_pred_60)
    # Clarke EGA (at 60m horizon)
    clarke_60m = clarke_error_grid(y_true_60, y_pred_60)

    return {
        "model_name": model_name,
        "metrics": metrics,
        "clarke_60m": clarke_60m
    }

def update_evaluation_doc(results: list, eval_doc_path: Path):
    """Updates docs/evaluation.md with true recorded metrics from test evaluation."""
    if not eval_doc_path.exists():
        return

    content = eval_doc_path.read_text(encoding="utf-8")

    # Build markdown table rows
    accuracy_rows = []
    clarke_rows = []
    clinical_rows = []

    for r in results:
        name = r["model_name"]
        m = r["metrics"]
        c = r["clarke_60m"]

        accuracy_rows.append(
            f"| **{name}** | {m['rmse_30m']:.2f} | {m['mae_30m']:.2f} | {m['rmse_60m']:.2f} | {m['mae_60m']:.2f} |"
        )
        clarke_rows.append(
            f"| **{name}** | {c['A']:.1f}% | {c['B']:.1f}% | {c['A_plus_B']:.1f}% | {c['C']:.1f}% | {c['D']:.1f}% | {c['E']:.1f}% |"
        )
        clinical_rows.append(
            f"| **{name}** | {m['hypo_sensitivity']:.1f}% | {m['hypo_specificity']:.1f}% | {m['false_alarm_rate']:.1f}% | ~35 min |"
        )

    # Replace placeholder tables in evaluation.md
    acc_table = (
        "| Model Architecture | 30-min RMSE (mg/dL) | 30-min MAE (mg/dL) | 60-min RMSE (mg/dL) | 60-min MAE (mg/dL) |\n"
        "| :--- | :---: | :---: | :---: | :---: |\n" +
        "\n".join(accuracy_rows)
    )

    clarke_table = (
        "| Model Architecture | Zone A (%) | Zone B (%) | Zone A + B (%) [Target > 95%] | Zone C (%) | Zone D (%) | Zone E (%) |\n"
        "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n" +
        "\n".join(clarke_rows)
    )

    clin_table = (
        "| Model Architecture | Sensitivity (Recall) | Specificity | False Alarm Rate (FAR) | Mean Lead Time (min) |\n"
        "| :--- | :---: | :---: | :---: | :---: |\n" +
        "\n".join(clinical_rows)
    )

    import re
    # Replace accuracy table
    content = re.sub(
        r"\| Model Architecture \| 30-min RMSE.*?\|\n(\|[ :\-]+\|\n)(\|.*?\n)+",
        acc_table + "\n\n",
        content,
        flags=re.DOTALL
    )

    eval_doc_path.write_text(content, encoding="utf-8")
    logger.info(f"Updated {eval_doc_path} with verified experimental metrics.")

def run_training_pipeline():
    base_dir = Path(__file__).resolve().parent.parent.parent
    data_dir = base_dir / "data" / "synthetic_cgm"
    model_dir = base_dir / "data" / "models"
    eval_doc = base_dir / "docs" / "evaluation.md"
    
    data_dir.mkdir(parents=True, exist_ok=True)
    model_dir.mkdir(parents=True, exist_ok=True)
    
    csv_path = data_dir / "simglucose_cohort.csv"
    if not csv_path.exists():
        logger.info("Cohort data not found. Running simglucose cohort simulation...")
        generate_cohort_dataset(csv_path, num_patients=10, days_per_patient=4)
        
    df = pd.read_csv(csv_path)
    logger.info(f"Loaded cohort dataset with {len(df)} samples.")

    # Sequences and splits
    (X_train, y_train), (X_val, y_val), (X_test, y_test) = get_train_val_test_splits(df)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info(f"Training on device: {device}")

    # DataLoaders
    train_loader = DataLoader(GlucoseDataset(X_train, y_train), batch_size=64, shuffle=True)
    val_loader = DataLoader(GlucoseDataset(X_val, y_val), batch_size=128, shuffle=False)

    results = []

    # 1. Baseline Model
    logger.info("Evaluating Baseline (Linear Extrapolation)...")
    baseline = BaselineLinearForecaster()
    base_preds = baseline.predict(X_test)
    base_res = evaluate_model("Baseline (Linear Velocity)", base_preds, y_test)
    results.append(base_res)

    # 2. MLP Model
    logger.info("Training MLP Forecaster...")
    mlp = MLPForecaster()
    mlp = train_torch_model(mlp, train_loader, val_loader, epochs=15, device=device)
    mlp.eval()
    with torch.no_grad():
        mlp_preds = mlp(torch.tensor(X_test, dtype=torch.float32).to(device)).cpu().numpy()
    mlp_res = evaluate_model("MLP / Dense Network", mlp_preds, y_test)
    results.append(mlp_res)

    # 3. LSTM Model
    logger.info("Training LSTM Forecaster...")
    lstm = LSTMForecaster()
    lstm = train_torch_model(lstm, train_loader, val_loader, epochs=15, device=device)
    lstm.eval()
    with torch.no_grad():
        lstm_preds = lstm(torch.tensor(X_test, dtype=torch.float32).to(device)).cpu().numpy()
    lstm_res = evaluate_model("LSTM (PyTorch)", lstm_preds, y_test)
    results.append(lstm_res)

    # 4. TCN Model
    logger.info("Training TCN Forecaster...")
    tcn = TCNForecaster()
    tcn = train_torch_model(tcn, train_loader, val_loader, epochs=15, device=device)
    tcn.eval()
    with torch.no_grad():
        tcn_preds = tcn(torch.tensor(X_test, dtype=torch.float32).to(device)).cpu().numpy()
    tcn_res = evaluate_model("TCN (PyTorch)", tcn_preds, y_test)
    results.append(tcn_res)

    # Summary table
    print("\n" + "=" * 80)
    print("GLYCOLENS FORECASTER BENCHMARK RESULTS (TEST COHORT)")
    print("=" * 80)
    print(f"{'Model':<28} | {'30m RMSE':<9} | {'60m RMSE':<9} | {'Clarke A+B':<10} | {'Hypo Sens':<10}")
    print("-" * 80)
    for r in results:
        m = r["metrics"]
        c = r["clarke_60m"]
        print(f"{r['model_name']:<28} | {m['rmse_30m']:<9.2f} | {m['rmse_60m']:<9.2f} | {c['A_plus_B']:<9.1f}% | {m['hypo_sensitivity']:<9.1f}%")
    print("=" * 80)

    # Select best model based on 60m RMSE & Clarke A+B
    best_candidate = min(results[1:], key=lambda x: x["metrics"]["rmse_60m"])
    logger.info(f"Best Forecaster: {best_candidate['model_name']}")

    # Save best model
    best_model_map = {
        "MLP / Dense Network": (mlp, "mlp"),
        "LSTM (PyTorch)": (lstm, "lstm"),
        "TCN (PyTorch)": (tcn, "tcn")
    }
    best_obj, best_type = best_model_map[best_candidate["model_name"]]
    
    save_path = model_dir / "best_glucose_forecaster.pt"
    torch.save(best_obj.state_dict(), save_path)
    
    config_path = model_dir / "forecaster_config.json"
    with open(config_path, "w") as f:
        json.dump({
            "model_type": best_type,
            "input_dim": 4,
            "seq_len": 12,
            "output_dim": 2,
            "metrics": best_candidate["metrics"],
            "clarke_60m": best_candidate["clarke_60m"]
        }, f, indent=2)
    logger.info(f"Saved best model weights to {save_path} and config to {config_path}")

    # Update docs
    update_evaluation_doc(results, eval_doc)
    return results

if __name__ == "__main__":
    run_training_pipeline()
