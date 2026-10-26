with source as (

    select * from {{ ref('raw_genres') }}

)

select
    trim(genre_name)                as genre_name,
    trim(parent_genre)              as parent_genre
from source
