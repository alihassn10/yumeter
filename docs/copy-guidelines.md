# Copy guidelines

Rules for any user-facing string in the app, the store listing, or marketing.

## Never state an accuracy or success figure

The Stitch designs carry several numbers that cannot be substantiated. None of
them ship:

| In the design | Why it is out |
| --- | --- |
| "99.4% Acc." (welcome) | Photo calorie estimation is nowhere near this. |
| "91% Accuracy" (progress) | Same, and presented as a measured result. |
| "92% probability of success based on your biological markers" (plan reveal) | Invented statistic, and no biological marker is measured. |
| "6 of 7 days within metabolic zone" (progress) | Implies a clinical measure that does not exist. |
| "40% more accurate than manual logging" | Comparative claim with no study behind it. |

Apple reviews health claims under App Review guideline 1.4.1, and an
unsubstantiated performance claim is also an advertising problem under FTC
rules. A number a reviewer can ask us to prove is a number we do not print.

Say what the product does instead:

- "Review and edit every result in one tap."
- "Estimates from a photo — adjust portions to match your plate."

## Never imply a capability we do not have

| In the design | Reality |
| --- | --- |
| "Core ML Ready", "Biometric Vision AI" (splash) | Analysis runs on a server-side vision model, not on device. |
| "LIDAR Depth Mapped" (camera) | No depth sensor is used, and LiDAR is Pro-iPhone only. |
| "Smart Scale (Withings) — Live" (settings) | Not integrated. |
| "Health Score 9.4/10" (meal result) | No scoring model exists. |

Build the screen without the control rather than shipping a dead one.

## No invented social proof

"120,000+ members transformed", "4.9 on iOS" and similar go in only once they
are true and sourced.

## Estimates are estimates

Anywhere a calorie or macro figure comes from a photo, the user must be able to
edit it, and the app should read as an estimate rather than a measurement.

## Not medical advice

The app sets calorie targets from the Mifflin-St Jeor equation, a population
estimate. It does not diagnose, treat, or give medical advice, and the plan
reveal and settings both need a visible disclaimer to that effect.

`GoalCalculator` holds daily targets above a safe floor (1500 kcal for men,
1200 otherwise) and reports `clampedToFloor` when it has to. Surface that
rather than promising a pace the plan does not deliver.
