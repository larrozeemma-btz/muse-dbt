-- Every listener — cold start included — receives exactly N recommendations.
select u.user_id, count(r.track_id) as n_recommendations
from {{ ref('dim_users') }} u
left join {{ ref('rpt_top_recommendations') }} r using (user_id)
group by 1
having count(r.track_id) <> {{ var('muse_top_n') }}
