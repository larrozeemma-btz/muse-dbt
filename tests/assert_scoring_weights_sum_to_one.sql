-- The three MUSE weights must sum to 1 so scores stay on a 0–100 scale.
select total_weight
from (
    select
        {{ var('muse_weight_genre') }}
      + {{ var('muse_weight_history') }}
      + {{ var('muse_weight_popularity') }} as total_weight
) as weights
where abs(total_weight - 1) > 0.0001
