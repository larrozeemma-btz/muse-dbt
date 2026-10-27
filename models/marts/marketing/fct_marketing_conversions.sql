select
    conversion_id,
    conversion_type,
    motion,
    person_key,
    converted_at,
    cast(converted_at as date)  as conversion_date,
    value_usd
from {{ ref('int_marketing_conversions') }}
