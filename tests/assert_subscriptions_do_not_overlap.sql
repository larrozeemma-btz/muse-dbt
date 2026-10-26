-- A listener holds at most one subscription at a time.
select a.user_id, a.subscription_id, b.subscription_id as overlapping_subscription_id
from {{ ref('fct_subscriptions') }} a
inner join {{ ref('fct_subscriptions') }} b
    on  a.user_id = b.user_id
    and a.subscription_id < b.subscription_id
    and a.started_at < coalesce(b.ended_at, timestamp '9999-12-31')
    and b.started_at < coalesce(a.ended_at, timestamp '9999-12-31')
