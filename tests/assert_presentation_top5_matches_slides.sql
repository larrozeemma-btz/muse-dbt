-- Slide 8 of the MUSE deck: the expected demo output with the default weights.
{{ config(enabled=(var('muse_weight_genre') == 0.5 and var('muse_weight_history') == 0.3 and var('muse_weight_popularity') == 0.2)) }}

with expected as (

    select * from (values
        (1, 'Midnight Drive', 91.6),
        (2, 'Golden Hour',    90.4),
        (3, 'Electric Heart', 89.4),
        (4, 'City Lights',    88.3),
        (5, 'Soft Focus',     83.9)
    ) as t(recommendation_rank, track_title, recommendation_score)

),

actual as (

    select recommendation_rank, track_title, recommendation_score
    from {{ ref('presentation_top5') }}

)

select coalesce(e.recommendation_rank, a.recommendation_rank) as recommendation_rank,
       e.track_title as expected_title, a.track_title as actual_title,
       e.recommendation_score as expected_score, a.recommendation_score as actual_score
from expected e
full outer join actual a using (recommendation_rank)
where e.track_title is distinct from a.track_title
   or abs(e.recommendation_score - a.recommendation_score) > 0.01
   or e.recommendation_rank is null
   or a.recommendation_rank is null
