select
    Id                              as opportunity_id,
    AccountId                       as account_id,
    Name                            as opportunity_name,
    Type                            as opportunity_type,
    StageName                       as stage_name,
    Amount                          as amount_usd,
    cast(CreatedDate as timestamp)  as created_at,
    cast(CloseDate as date)         as close_date,
    IsClosed                        as is_closed,
    IsWon                           as is_won,
    LeadSource                      as lead_source
from {{ source('salesforce', 'crm_opportunities') }}
