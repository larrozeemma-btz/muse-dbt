select
    spend.spend_id,
    spend.spend_date,
    {{ month_start('spend.spend_date') }}   as spend_month,
    spend.platform,
    spend.campaign_code,
    campaigns.channel,
    campaigns.motion,
    spend.currency,
    spend.spend_local,
    spend.spend_usd,
    spend.impressions,
    spend.clicks
from {{ ref('stg_ad_platforms__spend') }} as spend
left join {{ ref('stg_marketing__campaigns') }} as campaigns using (campaign_code)
