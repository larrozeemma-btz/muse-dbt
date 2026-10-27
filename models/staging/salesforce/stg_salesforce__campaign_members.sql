select
    members.Id                              as campaign_member_id,
    members.LeadId                          as lead_id,
    members.CampaignId                      as campaign_id,
    campaigns.campaign_code,
    campaigns.channel,
    cast(members.CreatedDate as timestamp)  as responded_at
from {{ source('salesforce', 'crm_campaign_members') }} as members
left join {{ ref('stg_marketing__campaigns') }} as campaigns
    on campaigns.campaign_id = members.CampaignId
where members.HasResponded
