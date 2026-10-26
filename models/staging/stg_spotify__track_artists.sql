{#
    Explode "Artist A;Artist B;Artist C" into one row per track × artist,
    keeping billing order. Artists have no id in the source, so one is derived
    from the normalised name.
#}

with exploded as (

    select track_id, item as artist_name, position as billing_position
    from (
        {{ explode_delimited(ref('stg_spotify__tracks'), 'track_id', 'artists_raw', ';') }}
    ) as parts

)

select
    {{ surrogate_key(['lower(artist_name)']) }}     as artist_id,
    track_id,
    artist_name,
    billing_position,
    billing_position = 1                            as is_primary_artist
from exploded
where artist_name <> ''
qualify row_number() over (partition by track_id, lower(artist_name) order by billing_position) = 1
