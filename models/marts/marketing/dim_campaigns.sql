with spend as (

    select campaign_code, min(spend_date) as first_spend_date, sum(spend_usd) as lifetime_spend_usd
    from {{ ref('stg_ad_platforms__spend') }}
    group by 1

)

select
    campaigns.*,
    channels.channel_group,
    channels.is_paid,
    spend.first_spend_date,
    coalesce(spend.lifetime_spend_usd, 0) as lifetime_spend_usd
from {{ ref('stg_marketing__campaigns') }} as campaigns
left join {{ ref('marketing_channels') }} as channels using (channel)
left join spend using (campaign_code)
