with source as (

    select * from {{ ref('raw_user_genre_preferences') }}

)

select
    user_id,
    trim(genre_name)                    as genre_name,
    affinity,
    cast(declared_at as timestamp)      as declared_at
from source
