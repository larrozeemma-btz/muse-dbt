select
    subscription_id,
    user_id,
    lower(trim(plan))                       as plan,
    monthly_price_eur,
    cast(started_at as timestamp)           as started_at,
    cast(ended_at as timestamp)             as ended_at,
    end_reason,
    ended_at is null                        as is_active
from {{ source('muse_app', 'subscriptions') }}
