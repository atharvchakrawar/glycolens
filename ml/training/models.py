import torch
import torch.nn as nn
import numpy as np

class BaselineLinearForecaster:
    """
    Non-learning clinical baseline:
    Uses current glucose and recent velocity with exponential biological decay.
    """
    def predict(self, X: np.ndarray) -> np.ndarray:
        # X shape: (N, 12, 4) where feature 0 is glucose, feature 3 is velocity
        curr_glucose = X[:, -1, 0]
        curr_velocity = X[:, -1, 3]
        active_insulin = X[:, -1, 1]
        carbs = X[:, -1, 2]

        pred_30m = curr_glucose + (curr_velocity * 30.0 * 0.75) + (carbs * 0.3) - (active_insulin * 8.0)
        pred_60m = curr_glucose + (curr_velocity * 60.0 * 0.50) + (carbs * 0.7) - (active_insulin * 15.0)

        preds = np.stack([pred_30m, pred_60m], axis=1)
        return np.clip(preds, 35.0, 500.0)

class MLPForecaster(nn.Module):
    """
    Multilayer Perceptron (MLP) baseline:
    Flattens 12x4 input window and processes with Dense + BatchNorm + ReLU + Dropout.
    """
    def __init__(self, input_dim: int = 12 * 4, hidden_dim: int = 128, output_dim: int = 2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Flatten(),
            nn.Linear(input_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.BatchNorm1d(hidden_dim // 2),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(hidden_dim // 2, output_dim)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)

class LSTMForecaster(nn.Module):
    """
    PyTorch Recurrent Forecaster:
    2-layer LSTM capturing temporal dependency of glucose rate-of-change,
    bolus clearance, and carb absorption curves.
    """
    def __init__(self, input_dim: int = 4, hidden_dim: int = 64, num_layers: int = 2, output_dim: int = 2):
        super().__init__()
        self.lstm = nn.LSTM(
            input_size=input_dim,
            hidden_size=hidden_dim,
            num_layers=num_layers,
            batch_first=True,
            dropout=0.2 if num_layers > 1 else 0.0
        )
        self.head = nn.Sequential(
            nn.Linear(hidden_dim, 32),
            nn.ReLU(),
            nn.Linear(32, output_dim)
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x shape: (batch_size, seq_len=12, num_features=4)
        out, (h_n, _) = self.lstm(x)
        # Use last hidden state
        last_hidden = out[:, -1, :]
        return self.head(last_hidden)

class Chomp1d(nn.Module):
    """Ensures causal convolution by trimming future padding."""
    def __init__(self, chomp_size: int):
        super().__init__()
        self.chomp_size = chomp_size

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x[:, :, :-self.chomp_size].contiguous() if self.chomp_size > 0 else x

class TemporalBlock(nn.Module):
    def __init__(self, in_channels: int, out_channels: int, kernel_size: int, stride: int, dilation: int, padding: int):
        super().__init__()
        self.conv1 = nn.Conv1d(in_channels, out_channels, kernel_size, stride=stride, padding=padding, dilation=dilation)
        self.chomp1 = Chomp1d(padding)
        self.relu1 = nn.ReLU()
        self.conv2 = nn.Conv1d(out_channels, out_channels, kernel_size, stride=stride, padding=padding, dilation=dilation)
        self.chomp2 = Chomp1d(padding)
        self.relu2 = nn.ReLU()
        self.downsample = nn.Conv1d(in_channels, out_channels, 1) if in_channels != out_channels else None

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        out = self.relu1(self.chomp1(self.conv1(x)))
        out = self.relu2(self.chomp2(self.conv2(out)))
        res = x if self.downsample is None else self.downsample(x)
        return torch.relu(out + res)

class TCNForecaster(nn.Module):
    """
    Temporal Convolutional Network (TCN):
    Dilated causal 1D convolutions with residual layers to model multi-scale temporal horizons.
    """
    def __init__(self, input_dim: int = 4, num_channels: list = [32, 64], kernel_size: int = 3, output_dim: int = 2):
        super().__init__()
        layers = []
        num_levels = len(num_channels)
        for i in range(num_levels):
            dilation_size = 2 ** i
            in_ch = input_dim if i == 0 else num_channels[i - 1]
            out_ch = num_channels[i]
            padding = (kernel_size - 1) * dilation_size
            layers.append(TemporalBlock(in_ch, out_ch, kernel_size, stride=1, dilation=dilation_size, padding=padding))
            
        self.network = nn.Sequential(*layers)
        self.fc = nn.Linear(num_channels[-1], output_dim)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x is (batch, seq_len=12, channels=4) -> transpose to (batch, channels=4, seq_len=12)
        x = x.transpose(1, 2)
        out = self.network(x)
        last_timestep = out[:, :, -1]
        return self.fc(last_timestep)
