{% docs __overview__ %}
# MUSE — music recommendation warehouse

MUSE ranks songs for each listener with a transparent score:

`score = 0.5 × genre match + 0.3 × listening history + 0.2 × popularity`

and returns the top five.

**Layers**
- `raw` — seeds (synthetic, fictional data)
- `staging` — cleaned 1:1 views (dedup, casing, taxonomy mapping)
- `intermediate` — the three scoring signals
- `core` — dimensions & incremental event fact
- `recommendations` — scores for every listener × track, top-N playlist
- `presentation` — reproduction of the pitch deck demo

Weights, playlist size and event points are dbt `vars` in `dbt_project.yml`.
{% enddocs %}
