{{ config(materialized='table') }}

{#
    Each candidate pair expanded to the genres and artists of its track, so
    the scoring stage joins signals on full (user, attribute) keys instead of
    letting the optimiser explode genre × listener first.
#}

with candidates as (

    select user_id, track_id from {{ ref('int_user_track_candidates') }}

)

select candidates.user_id, candidates.track_id, 'genre' as attribute_type, track_genres.genre_name as attribute_key
from candidates
inner join {{ ref('stg_spotify__track_genres') }} as track_genres
    on track_genres.track_id = candidates.track_id

union all

select candidates.user_id, candidates.track_id, 'artist' as attribute_type, track_artists.artist_id as attribute_key
from candidates
inner join {{ ref('stg_spotify__track_artists') }} as track_artists
    on track_artists.track_id = candidates.track_id
