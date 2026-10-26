with artists as (

    select * from {{ ref('stg_muse__artists') }}

),

tracks as (

    select artist_id, count(*) as n_tracks
    from {{ ref('stg_muse__tracks') }}
    group by 1

)

select
    artists.artist_id,
    artists.artist_name,
    artists.primary_genre,
    artists.country_code,
    coalesce(tracks.n_tracks, 0) as n_tracks
from artists
left join tracks using (artist_id)
