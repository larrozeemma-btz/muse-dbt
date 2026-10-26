-- Every listener (cold-start included) receives exactly min(N, #candidates) tracks.
with expected as (

    select user_id, least({{ var('muse_top_n') }}, count(*)) as expected_n
    from {{ ref('int_user_track_candidates') }}
    group by 1

),

actual as (

    select user_id, count(*) as actual_n
    from {{ ref('rpt_top_recommendations') }}
    group by 1

)

select u.user_id, e.expected_n, coalesce(a.actual_n, 0) as actual_n
from {{ ref('dim_users') }} u
left join expected e using (user_id)
left join actual a using (user_id)
where coalesce(e.expected_n, 0) <> coalesce(a.actual_n, 0)
