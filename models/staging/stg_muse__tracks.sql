with source as (

    select * from {{ ref('raw_tracks') }}

),

genres as (

    select * from {{ ref('stg_muse__genres') }}

)

select
    source.track_id,
    trim(source.title)                          as track_title,
    source.artist_id,
    -- raw labels look like "  house " → map back to the canonical taxonomy spelling
    genres.genre_name,
    source.release_date,
    source.duration_ms,
    round(source.duration_ms / 1000.0, 0)       as duration_seconds,
    source.is_explicit
from source
left join genres
    on lower(trim(source.genre)) = lower(genres.genre_name)
