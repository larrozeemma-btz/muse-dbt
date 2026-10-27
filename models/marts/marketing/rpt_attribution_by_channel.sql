{#
    Month × channel × attribution model × conversion type: how much credit each
    channel earns, what it cost, and the resulting cost per credited conversion
    and return on ad spend. Comparing models row by row is the point.
#}

with credited as (

    select
        conversion_month                    as month_start,
        motion,
        conversion_type,
        attribution_model,
        channel,
        sum(credit)                         as credited_conversions,
        sum(credited_value_usd)             as credited_value_usd
    from {{ ref('fct_marketing_attribution') }}
    group by 1, 2, 3, 4, 5

),

spend as (

    select spend_month as month_start, motion, channel, sum(spend_usd) as spend_usd
    from {{ ref('fct_ad_spend') }}
    group by 1, 2, 3

)

select
    credited.*,
    coalesce(spend.spend_usd, 0)                                                        as spend_usd,
    round(spend.spend_usd / nullif(credited.credited_conversions, 0), 2)                as cost_per_credited_conversion_usd,
    round(credited.credited_value_usd / nullif(spend.spend_usd, 0), 2)                  as roas
from credited
left join spend
    on  spend.month_start = credited.month_start
    and spend.motion      = credited.motion
    and spend.channel     = credited.channel
