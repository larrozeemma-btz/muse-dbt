{#
    Monthly subscription economics per plan: MRR at month end, paying base,
    new paid starts and paid churn.
#}

with months as (

    select distinct month_start, last_day(month_start) as month_end
    from {{ ref('dim_date') }}
    where month_start <= date '{{ var("muse_as_of_date") }}'

),

subscriptions as (

    select * from {{ ref('fct_subscriptions') }} where is_paid

),

active_at_month_end as (

    select
        months.month_start,
        subscriptions.plan,
        count(distinct subscriptions.user_id)           as paying_subscribers,
        round(sum(subscriptions.monthly_price_eur), 2)  as mrr_eur
    from months
    inner join subscriptions
        on  cast(subscriptions.started_at as date) <= months.month_end
        and (subscriptions.ended_at is null or cast(subscriptions.ended_at as date) > months.month_end)
    group by 1, 2

),

starts as (

    select {{ month_start('started_at') }} as month_start, plan, count(*) as new_paid_subscriptions
    from subscriptions
    group by 1, 2

),

ends as (

    select {{ month_start('ended_at') }} as month_start, plan, count(*) as ended_paid_subscriptions
    from subscriptions
    where ended_at is not null
    group by 1, 2

),

spine as (

    select months.month_start, plans.plan
    from months
    cross join (select distinct plan from subscriptions) as plans

)

select
    spine.month_start,
    spine.plan,
    coalesce(active_at_month_end.paying_subscribers, 0)  as paying_subscribers,
    coalesce(active_at_month_end.mrr_eur, 0)             as mrr_eur,
    coalesce(starts.new_paid_subscriptions, 0)           as new_paid_subscriptions,
    coalesce(ends.ended_paid_subscriptions, 0)           as ended_paid_subscriptions
from spine
left join active_at_month_end using (month_start, plan)
left join starts using (month_start, plan)
left join ends using (month_start, plan)
