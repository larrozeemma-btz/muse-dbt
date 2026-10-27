# Where last-touch reporting misleads us

*Emma Larroze · Period: July 2025 to September 2026 · Source: the `marketing`
marts in this project. The data is simulated (see README), so read the numbers
as a demonstration of the method, not as real results.*

## Why I wrote this

Every attribution model tells a slightly different story, and that's fine, as
long as we know which story we're reading. When I put all five models side by
side, one pattern jumped out: the channels that *start* customer journeys almost
disappear under last-touch. If we planned budget on last-touch alone, we'd cut
the things that bring people to us in the first place.

Here's what the data shows, what I'd change, and what I'd test before moving a
single dollar.

## The short version

1. **Last-touch would have us cut our cheapest demand creator, and misprice paid search.**
   Content opens a fifth of all signup journeys at **$11 per signup** (first
   touch) and gets **0 %** of last-touch credit. Paid search gets almost none
   (0.2 %), which makes it look **35× more expensive** than it is: $4,040 per
   signup under last-touch, against $115 under position-based. Paid search is
   still our priciest paid channel in every model, so the real question is how
   much of it to keep, not whether to cut it.
2. **Retargeting looks like a star. That's exactly why I'd test it.**
   The Meta retargeting campaign (part of paid social) gets 7 to 19 % of all
   signup credit depending on the model. Credit isn't
   proof, though. I'd run a four-week holdout before giving it more budget.
3. **Content downloads fill the MQL queue, not the pipeline.**
   They're 18 % of our leads but bring **$39 of bookings per lead**, against
   **$2,327** for partner referrals. That isn't marketing versus sales. It's a
   definition problem, and definitions can be fixed.
4. **We're judging ABM and webinars on the wrong number.**
   On sourced pipeline, LinkedIn ABM returns $0.9 per dollar. On influenced
   pipeline it returns $12. Webinars influence $77 per dollar. Both numbers
   belong in the review, side by side.
5. **Our activation definition misses half of our future payers.**
   48 % of paying users never hit "10 plays in the first 7 days". Switching to
   "active on 3 different days in the first 14 days" covers 69 % of payers and
   predicts payment 3.7× better than non-activation, against 2.6× today.

## 1. The models disagree most about who creates demand

Share of signup credit by channel, July 2025 to September 2026:

| Channel | First touch | Last touch | Linear | Position-based | Time decay |
|---|---:|---:|---:|---:|---:|
| Organic search | 24.5 % | 14.8 % | 16.7 % | 18.2 % | 14.3 % |
| Content (podcasts, blog, video) | 21.0 % | **0.0 %** | 9.5 % | 10.0 % | 5.3 % |
| Paid social | 19.9 % | 23.7 % | 27.7 % | 24.9 % | 30.8 % |
| Paid search | 12.0 % | **0.2 %** | 7.6 % | 6.7 % | 5.2 % |
| Referral | 8.9 % | 15.4 % | 8.5 % | 10.5 % | 9.4 % |
| Direct | 5.9 % | 37.7 % | 19.3 % | 20.6 % | 24.5 % |

What it costs us to get one signup, last 12 months:

| Paid channel | First touch | Last touch | Position-based | Time decay |
|---|---:|---:|---:|---:|
| Content (podcast sponsorships) | **$11** | n/a | $22 | $41 |
| Partnership | $28 | $20 | $27 | $31 |
| Paid social | $59 | $50 | $47 | $38 |
| Paid search | $64 | **$4,040** | $115 | $149 |

**What's going on.** A typical journey starts with a podcast, an article or a
search ad, and ends with a direct visit or a retargeting ad. Last-touch hands
the entire conversion to that final click, so everything that happened before
it simply vanishes.

**What I'd do.** Make position-based our planning default, and always show it
next to first and last touch so nobody has to take one model on faith. That's
how the dashboard's *Attribution* view is built. Don't cut content on
last-touch numbers. And judge paid search on its position-based cost ($115 per
signup, our most expensive paid channel), not on the $4,040 that last-touch
makes up.

## 2. Retargeting: test before we scale

Retargeting is a campaign inside the paid social channel. Here is its share of
**all** signup credit under each model:

| | First touch | Last touch | Linear | Position-based | Time decay |
|---|---:|---:|---:|---:|---:|
| Meta retargeting (inside paid social) | 7.0 % | 7.8 % | 15.7 % | 11.7 % | **18.9 %** |

It shows up right before people sign up in about a third of journeys, and every
model rewards it for that. That's what makes me cautious. It mostly
reaches people who were already about to convert, so the real question isn't
"does it get credit?" but "would these people have signed up anyway?"

**What I'd do.** Hold out 10 % of the retargeting audience for four weeks and
compare signup rates. Keep the budget flat until we know. Four weeks of
patience is cheaper than six months scaling something we can't prove works.

## 3. Content-download leads: lots of volume, very little value

| Lead source | Leads | Lead to MQL | Win rate | Bookings per lead |
|---|---:|---:|---:|---:|
| Partner referral | 193 | 85 % | 43 % | **$2,327** |
| Website demo request | 833 | 79 % | 27 % | $710 |
| Trade show | 539 | 60 % | 23 % | $473 |
| Webinar | 587 | 49 % | 24 % | $284 |
| Content download | 734 | 30 % | 14 % | **$39** |
| Paid search | 400 | 49 % | 12 % | **$25** |

On a dashboard, a full MQL queue looks like success. But sales development
spends the same time on a content-download MQL as on a demo request, and the
two are worth wildly different amounts. B2B paid-search leads have the same
problem at a smaller scale: plenty of form fills, very few wins.

**What I'd do.**
- A content download alone shouldn't make someone an MQL. Wait for a second
  high-intent signal, like a demo-page visit or a webinar attended, and keep
  everyone else in nurture. The same rule should apply to paid-search leads
  that didn't ask for a demo.
- Partner referrals convert best and close fastest. I'd grow the reseller
  program before adding another event to the calendar.

## 4. Sourced and influenced pipeline: show both

| Enterprise channel | Spend | Sourced pipeline per $ | Influenced pipeline per $ |
|---|---:|---:|---:|
| Paid search | $115k | $22.9 | $32.0 |
| Partnership | $50k | $16.9 | $16.9 |
| Webinar | $42k | $11.8 | **$77.2** |
| Events | $85k | $13.5 | $26.2 |
| LinkedIn ABM (paid social) | $212k | **$0.9** | $11.8 |

I always report these two together, because each one alone tells a half-truth.
Sourced pipeline undersells programs like ABM and webinars, which rarely create
a lead but show up in most deals before the opportunity exists. Influenced
pipeline gives them their due, but it adds up to more than 100 %, so it can
never be summed across channels.

**What I'd do.** Put both in the weekly review. For programs designed to
accelerate deals, set targets on influenced pipeline and deal velocity, not on
sourced pipeline.

## 5. Rethinking what "activated" means

The funnel counts a user as *activated* after 10 plays in their first 7 days.
Activated users do pay more often (14 % vs 5 %), but **48 % of paying users never
reach that bar**. A definition that misses half of the people it's supposed to
predict won't be trusted for long, so I tested alternatives on the July 2025 to
June 2026 signup cohorts:

| Definition | Activated | Pay rate if activated | Pay rate if not | Lift | Payers covered |
|---|---:|---:|---:|---:|---:|
| ≥ 10 plays in 7 days (today) | 30 % | 14.2 % | 5.4 % | 2.6× | 52 % |
| ≥ 20 plays in 14 days | 29 % | 15.7 % | 4.8 % | 3.3× | 58 % |
| ≥ 1 like or playlist add in 14 days | 52 % | 11.4 % | 4.3 % | 2.6× | 74 % |
| ≥ 4 active days in 14 days | 24 % | 18.1 % | 4.7 % | 3.8× | 55 % |
| **≥ 3 active days in 14 days** | 37 % | 14.8 % | 3.9 % | **3.7×** | **69 %** |

*Paid = upgraded between day 14 and day 90. Users who paid in their first two
weeks are left out, because a definition has to be observable before the
outcome it predicts.*

**What it tells us:** coming back matters more than listening a lot in one go.
Habit predicts payment better than volume.

**What I'd do.** Propose "active on 3 different days in the first 14 days" as
the new activation definition. Before switching, I'd check it on a cohort the
analysis didn't see, agree on it with product and growth (it changes the
numbers they're measured on), and restate the history so the trend line doesn't
jump on the day we switch.

## What this analysis can't tell us

Being clear about the limits is part of what makes the numbers trustworthy:

- **47 % of paid upgrades have no marketing touch** in the 30-day window,
  because people upgrade months after they sign up. That's why I attribute
  marketing to signups and treat the upgrade to paid as a product metric.
  Attributing upgrades would quietly drop half of them.
- **These are media CACs.** Spend excludes salaries and tooling. Consumer
  spend is only ever divided by consumer outcomes, and enterprise spend by
  pipeline, so neither motion inflates the other's CAC.
- **No attribution model measures incrementality.** That's what holdout tests
  are for, and why I'd run one before any budget shift above 20 %.
