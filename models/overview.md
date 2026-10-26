{% docs __overview__ %}
# MUSE — music recommendation warehouse

A real music catalog (Spotify Tracks Dataset, ~90k tracks, 114 genres) plus millions
of simulated listening events, modelled into a tested warehouse that powers:

- a **personalised top-5 playlist** per listener —
  `score = 0.5 × genre match + 0.3 × listening history + 0.2 × popularity`
- **product analytics** — daily KPIs, retention cohorts, subscription revenue,
  recommendation-surface performance

**Layers**: `raw` (loaded by `scripts/load_raw_data.py`) → `staging` → `intermediate`
→ `core` (star schema) → `recommendations` / `analytics`.
{% enddocs %}
