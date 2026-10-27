# MUSE marketing metrics glossary

**Before the numbers, the words.** Most dashboard debates aren't really about
data. They're about definitions. Two teams look at "MQLs" or "pipeline", see
different numbers, and lose a meeting arguing about which one is right.

So every metric here has one definition, one owner, and a *watch out for*
column. The caveats are usually where trust is won or lost, which is why they
sit right next to the definition instead of in a footnote.

The executable versions live in the
[semantic layer](../models/marts/marketing/_semantic_layer.yml). This page
explains them in plain language. Changing a definition goes through a pull
request reviewed by the metric's owner, so nobody wakes up to a number that
quietly moved.

| Metric | Definition | Grain & timing | Owner | Watch out for |
|---|---|---|---|---|
| **Marketing spend** | Paid media and paid program costs (ad platforms, podcast sponsorships, partner fees, events), converted to USD at finance's planning FX rate | Day the cost is incurred | Marketing ops + Finance | Excludes salaries and tooling, so it is *media* CAC, not fully loaded CAC |
| **Visitor** | A browser (cookie) seen on the website at least once | First visit | Growth | One person on two devices counts twice until they sign up |
| **Signup** | A new MUSE account | Account creation | Growth | Counted once per account, even if the person had several cookies |
| **Activated user** | Signup with ≥ 10 plays in the first 7 days (`muse_activation_plays`, `muse_activation_window_days`) | Signup cohort | Product + Growth | The threshold was chosen because it separates retained from churned users; revisit yearly |
| **Paid conversion** | Account starting its first paid subscription (premium, student or family) | Subscription start | Growth + Finance | Upgrades happen weeks after signup, so recent cohorts are still maturing |
| **Blended CAC** | Marketing spend ÷ paid conversions in the same period | Week / month / quarter | Finance | Deliberately blended. Channel-level CAC depends on the attribution model and is shown separately |
| **Cost per signup** | Marketing spend ÷ signups in the same period | Week / month | Growth | Use for fast feedback; CAC is the business metric |
| **Lead** | A person who gave contact details to MUSE for Business (form, event scan, partner referral, SDR outreach) | Lead created date | Marketing ops | Duplicates from the CRM sync are removed before counting |
| **MQL** | Lead whose engagement score passed the marketing threshold (`MQL_Date__c` set) | MQL date | Marketing + Sales development | The threshold differs by source in practice. See the memo on content downloads |
| **SQL** | MQL accepted by sales development after a qualification call (`SQL_Date__c` set) | SQL date | Sales development | An MQL with no answer for 30 days is recycled to nurture, not rejected |
| **Pipeline created** | Amount of new-business opportunities, on the opportunity creation date | Opportunity created | Sales strategy | Amount is the expected first-year contract value; it can change until close |
| **Closed-won bookings** | Amount of opportunities closed-won, on the close date | Close date | Finance | Only new business; expansions are out of scope |
| **Sourced pipeline** | Pipeline credited to the channel of the touch that created the lead (first touch) | Opportunity created | Marketing + Sales strategy | Adds up to 100 % of pipeline across channels |
| **Influenced pipeline** | Full opportunity amount counted for every channel that touched the lead before the opportunity existed | Opportunity created | Marketing | Adds up to **more** than 100 % by design. Never sum across channels |
| **Attribution coverage** | Share of conversions with at least one marketing touch in the lookback window | Conversion | Marketing analytics | Uncovered conversions are not "organic". They are unexplained |

## Attribution models

There's no "right" attribution model, only models that answer different
questions. That's why I compute all five for every conversion: the
differences are visible instead of debated in the abstract.

| Model | Credit | Good for | Bias |
|---|---|---|---|
| First touch | 100 % to the touch that opened the journey | Which channels create demand | Ignores everything that closed the deal |
| Last touch | 100 % to the final touch | Which channels capture demand | Overvalues retargeting and branded search, zeroes out upper funnel |
| Linear | Equal split | A neutral default for comparing channels | Treats a passing touch like a decisive one |
| Position-based (U-shape) | 40 % first, 40 % last, 20 % middle | Balancing creation and capture | The 40/20/40 split is a convention, not a measurement |
| Time decay (7-day half-life) | Halves every 7 days before conversion | Short consideration cycles | Penalises awareness channels in long journeys |

**My default for planning:** position-based, with first and last touch always
shown alongside it. And one thing to keep in mind: **none of these models
measures incrementality.** They tell us who was there, not who made the
difference. Before shifting more than 20 % of a channel's budget, I'd run a
holdout test (geo or audience split) first.

Lookback windows: 30 days before a PLG conversion, 365 days before an
enterprise opportunity.
