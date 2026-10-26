-- Discovery mode: a listener is never recommended a track they already played or liked.
{{ config(enabled=var('muse_exclude_listened_tracks')) }}

select r.user_id, r.track_id
from {{ ref('rpt_top_recommendations') }} r
inner join {{ ref('int_user_track_engagement') }} e
    on  e.user_id  = r.user_id
    and e.track_id = r.track_id
where e.n_plays > 0 or e.n_likes > 0
