with source as (

    select * from {{ ref('raw_artists') }}

)

select
    artist_id,
    trim(artist_name)               as artist_name,
    trim(primary_genre)             as primary_genre,
    upper(trim(country))            as country_code
from source
