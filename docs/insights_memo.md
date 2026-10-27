# Marketing measurement memo: where last-touch reporting misleads us

*Period: July 2025 to September 2026 · Source: `marketing` marts in this
project · Data is simulated (see README), so the numbers illustrate the
method and are not real results.*

## TL;DR

1. **Last-touch reporting would cut our two cheapest demand creators.**
   Content and paid search open about 33 % of signup journeys but get **0 %**
   of last-touch credit. Under last-touch, paid search costs **$35k per signup**.
   Under position-based it costs **$841**.
2. **Retargeting looks great, but nothing proves it adds signups we would not
   have had anyway.** The Meta retargeting campaign gets 7 to 19 % of all signup
   credit depending on the model. Run a 4-week audience holdout before raising
   its budget.
3. **In enterprise, content downloads fill the MQL queue but not the pipeline.**
   They are 17 % of leads but bring **$20 of bookings per lead**, against **$1,906** for
   partner referrals. Tighten the MQL rule for content leads and move the
   capacity freed up to the partner program.
4. **LinkedIn ABM and webinars are judged on the wrong number.** On *sourced*
   pipeline, LinkedIn returns $1.1 per dollar spent. On *influenced* pipeline it returns
   $13. Webinars influence $69 of pipeline per dollar. Report both and set
   targets on influenced pipeline for these two programs.

## 1. Attribution models disagree most on demand creation

Share of signup credit by channel (Jul 2025 to Sep 2026):

| Channel | First touch | Last touch | Linear | Position-based | Time decay |
|---|---:|---:|---:|---:|---:|
| Organic search | 23.6 % | 15.5 % | 16.7 % | 18.2 % | 14.7 % |
| Content (podcasts, blog, video) | 20.8 % | **0.0 %** | 9.4 % | 9.9 % | 5.1 % |
| Paid social | 20.0 % | 24.2 % | 27.9 % | 25.1 % | 31.0 % |
| Paid search | 12.2 % | **0.2 %** | 7.4 % | 6.7 % | 5.0 % |
| Referral | 9.2 % | 14.9 % | 8.5 % | 10.4 % | 9.2 % |
| Direct | 6.3 % | 37.5 % | 19.3 % | 20.6 % | 24.5 % |

Cost per credited signup, last 12 months:

| Paid channel | First touch | Last touch | Position-based | Time decay |
|---|---:|---:|---:|---:|
| Content (podcast sponsorships) | **$85** | n/a | $179 | $347 |
| Partnership | $202 | $159 | $205 | $241 |
| Paid social | $443 | $363 | $352 | $286 |
| Paid search | $460 | **$35,477** | $841 | $1,113 |

**Why:** journeys usually start with a podcast, an article or a search ad, and
end with a direct visit or a retargeting ad. Last touch hands the whole
conversion to that final step.

**Recommendation:** use position-based as the planning default, always shown
next to first and last touch (dashboard, *Attribution* tab). Do not cut content
or paid search on last-touch numbers.

## 2. Test retargeting's incrementality before scaling it

The Meta retargeting campaign shows up right before conversion in about a third
of journeys. Every model credits it, but credit is not incrementality: it
mostly reaches people who were already about to sign up.

**Recommendation:** hold out 10 % of the retargeting audience for four weeks and
compare signup rates. Keep the budget flat until then.

## 3. Content-download leads: high volume, low value

| Lead source | Leads | Lead to MQL | Win rate | Bookings per lead |
|---|---:|---:|---:|---:|
| Partner referral | 198 | 83 % | 40 % | **$1,906** |
| Website demo request | 852 | 78 % | 29 % | $804 |
| Trade show | 572 | 59 % | 22 % | $396 |
| Webinar | 625 | 58 % | 22 % | $296 |
| Content download | 679 | 31 % | 17 % | **$20** |

**Recommendation:**
- Content-download leads become MQLs only after a second high-intent action:
  a demo-page visit or a webinar attended. Until then they stay in nurture.
- Partner referrals are the most efficient source, with the fastest path to a
  win. Grow the reseller program before adding events.

## 4. Sourced vs influenced pipeline

| Enterprise channel | Spend | Sourced pipeline per $ | Influenced pipeline per $ |
|---|---:|---:|---:|
| Paid search | $115k | $23.4 | $32.4 |
| Partnership | $50k | $13.8 | $13.8 |
| Webinar | $42k | $14.1 | **$68.6** |
| Events | $85k | $13.2 | $21.4 |
| LinkedIn ABM (paid social) | $212k | **$1.1** | $13.1 |

LinkedIn ABM and webinars rarely create the lead, but they show up in most
deals before the opportunity exists. Judged on sourced pipeline alone, they
would be cut.

**Recommendation:** report sourced and influenced pipeline side by side in the
weekly review. For programs meant to accelerate deals (ABM, webinars), set
targets on influenced pipeline and opportunity velocity.

## Data caveats

- 12 % of paid conversions have **no** marketing touch in the 30-day window
  (upgrades happen long after signup). Attribute marketing to signups and treat
  the upgrade to paid as a product metric.
- Spend excludes salaries and tooling, so all CACs here are media CACs.
- Influenced pipeline adds up to more than 100 %. Never sum it across channels.
