# BHI (Bird Health Index) Mathematical Model

BHI is a proprietary composite health score designed to quantitatively assess companion bird health status.

## Overall Structure

```
BHI = WeightScore + FoodScore + WaterScore
         (60)         (25)        (15)       = 0 ~ 100
```

| Component | Max Score | Weight | Description |
|-----------|-----------|--------|-------------|
| Weight Score | 60 | 60% | Stability assessment based on weight change rate |
| Food Score | 25 | 25% | Food intake fulfillment vs target |
| Water Score | 15 | 15% | Water intake adequacy |

## Weight Score (0–60)

Different formulas are applied depending on the growth stage.

### Adult Stage

Calculates the Weight Change Index (WCI) by comparing with weight from 7 days ago:

```
WCI_7 = (W_t - W_{t-7}) / W_{t-7}
```

Both weight gain and loss are penalized:

```
WeightScore = 60 × (1 - clamp(|WCI_7| / 0.10, 0, 1))
```

- `W_t`: Weight on measurement day
- `W_{t-7}`: Weight 7 days prior (±3 day search window)
- Threshold 0.10 = score drops to 0 at ≥10% change

### Post-Growth Stage

Only weight loss is penalized; gain is allowed:

```
WCI_7 = (W_t - W_{t-7}) / W_{t-7}
WeightScore = 60 × (1 - clamp(|min(WCI_7, 0)| / 0.10, 0, 1))
```

### Rapid-Growth Stage

Compares with previous day's weight, rewarding healthy growth:

```
WCI_1 = (W_t - W_{t-1}) / W_{t-1}
WeightScore = 60 × clamp(min(WCI_1, 0.10) / 0.10, 0, 1)
```

- Daily growth up to 10% is evaluated as maximum score

## Food Score (0–25)

Only penalizes deficit relative to target intake:

```
Δf = (f_t - f_0) / f_0
FoodScore = 25 × (1 - clamp(|min(Δf, 0)| / 0.30, 0, 1))
```

- `f_t`: Actual daily food intake (g)
- `f_0`: Target daily food intake (g)
- Threshold 0.30 = score drops to 0 at ≥30% deficit
- Excess intake is not penalized

## Water Score (0–15)

Symmetrically penalizes both excess and deficit:

```
Δd = (d_t - d_0) / d_0
WaterScore = 15 × (1 - clamp(|Δd| / 0.40, 0, 1))
```

- `d_t`: Actual daily water intake (ml)
- `d_0`: Target daily water intake (ml)
- Threshold 0.40 = score drops to 0 at ≥40% deviation

## Threshold Summary

| Parameter | Value | Description |
|-----------|-------|-------------|
| Weight threshold (adult/post-growth) | 0.10 | 10% change → full score to 0 |
| Weight threshold (rapid-growth) | 0.10 | 10% daily growth as ideal max |
| Food threshold | 0.30 | 30% deficit tolerance |
| Water threshold | 0.40 | 40% deviation tolerance |
| Weight comparison period (adult) | 7 days | Weekly weight tracking |
| Weight comparison period (rapid-growth) | 1 day | Daily growth tracking |
| Weight search window | ±3 days | Allowed range for comparison weight lookup |

## WCI Level Mapping

BHI scores are converted into a user-friendly 5-tier level system:

| BHI Score | WCI Level | Status | Description |
|-----------|-----------|--------|-------------|
| 81–100 | 5 | Excellent | Overall healthy condition |
| 61–80 | 4 | Good | Stable condition |
| 41–60 | 3 | Fair | Observation needed |
| 21–40 | 2 | Caution | Diet/condition check required |
| 1–20 | 1 | Critical | Immediate attention needed |
| 0 | 0 | — | Insufficient data |

## Fallback Logic

- If no data exists for the measurement date, automatically falls back to the most recent record
- If no comparison weight exists, uses the closest record within ±3 day range
- If target value is 0, the component score is set to 0 (division-by-zero prevention)
- If growth stage is not set, defaults to `adult`
