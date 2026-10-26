with days as (

    {{ date_series('2024-01-01', '2026-12-31') }}

)

select
    date_day,
    extract(year from date_day)                         as calendar_year,
    extract(quarter from date_day)                      as calendar_quarter,
    extract(month from date_day)                        as calendar_month,
    {{ format_date_name('date_day', 'month') }}         as month_name,
    {{ month_start('date_day') }}                       as month_start,
    {{ date_add_days('date_day', '1 - (' ~ iso_day_of_week('date_day') ~ ')') }} as week_start,
    {{ iso_day_of_week('date_day') }}                   as iso_day_of_week,
    {{ format_date_name('date_day', 'day') }}           as day_name,
    {{ iso_day_of_week('date_day') }} in (6, 7)         as is_weekend
from days
