-- Spend in the reporting layer must equal spend loaded from the ad platforms (to the cent).
select staged, reported
from (
    select
        (select round(sum(spend_usd), 2) from {{ ref('stg_ad_platforms__spend') }})   as staged,
        (select round(sum(spend_usd), 2) from {{ ref('fct_ad_spend') }})              as reported
) as totals
where abs(staged - reported) > 0.01
