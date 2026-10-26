{% set as_of = "timestamp '" ~ var('muse_as_of_date') ~ " 23:59:59'" %}

with subscriptions as (

    select * from {{ ref('stg_muse__subscriptions') }}

)

select
    subscription_id,
    user_id,
    plan,
    plan <> 'free'                                                  as is_paid,
    monthly_price_eur,
    started_at,
    ended_at,
    end_reason,
    is_active,
    row_number() over (partition by user_id order by started_at)   as subscription_sequence,
    lag(plan) over (partition by user_id order by started_at)      as previous_plan,
    round({{ dbt.datediff('started_at', 'coalesce(ended_at, ' ~ as_of ~ ')', 'day') }} / 30.44, 2) as months_active,
    round(monthly_price_eur
          * {{ dbt.datediff('started_at', 'coalesce(ended_at, ' ~ as_of ~ ')', 'day') }} / 30.44, 2) as revenue_eur
from subscriptions
