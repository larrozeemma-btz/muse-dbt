select
    Id                          as campaign_id,
    utm_campaign                as campaign_code,
    Name                        as campaign_name,
    Channel__c                  as channel,
    Motion__c                   as motion,
    lower(Type)                 as campaign_type,
    cast(StartDate as date)     as start_date
from {{ source('web_analytics', 'marketing_campaigns') }}
