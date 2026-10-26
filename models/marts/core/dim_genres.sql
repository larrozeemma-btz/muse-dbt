with families as (

    select * from {{ ref('genre_families') }}

),

catalog as (

    select genre_name, count(*) as n_tracks
    from {{ ref('stg_spotify__track_genres') }}
    group by 1

)

select
    families.genre_name,
    families.genre_family,
    coalesce(catalog.n_tracks, 0) as n_tracks
from families
left join catalog using (genre_name)
