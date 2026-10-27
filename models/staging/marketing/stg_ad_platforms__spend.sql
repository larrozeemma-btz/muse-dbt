{#
    Ad platforms report in the ad account's currency. Everything is converted
    to USD at finance's planning rate (`muse_eur_to_usd`) so spend can be
    compared with pipeline and revenue.
#}

select
    {{ surrogate_key(['platform', 'campaign', 'date']) }}  as spend_id,
    cast(date as date)                                      as spend_date,
    platform,
    campaign                                                as campaign_code,
    upper(currency)                                         as currency,
    spend                                                   as spend_local,
    round(spend * case when upper(currency) = 'EUR' then {{ var('muse_eur_to_usd') }} else 1 end, 2) as spend_usd,
    impressions,
    clicks
from {{ source('ad_platforms', 'ad_platform_spend') }}
