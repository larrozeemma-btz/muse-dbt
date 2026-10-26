{#
    Candidate pool: every listener × every track, minus (in discovery mode)
    the tracks the listener has already played. This is MUSE's `songList`.
#}

with users as (

    select user_id from {{ ref('stg_muse__users') }}

),

tracks as (

    select track_id, artist_id, genre_name from {{ ref('stg_muse__tracks') }}

),

already_listened as (

    select user_id, track_id
    from {{ ref('int_user_track_engagement') }}
    where n_plays > 0 or n_likes > 0

)

select
    users.user_id,
    tracks.track_id,
    tracks.artist_id,
    tracks.genre_name
from users
cross join tracks
{% if var('muse_exclude_listened_tracks') %}
left join already_listened
    on  already_listened.user_id  = users.user_id
    and already_listened.track_id = tracks.track_id
where already_listened.track_id is null
{% endif %}
