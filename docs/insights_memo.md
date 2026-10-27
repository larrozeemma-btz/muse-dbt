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

1. **Last-touch would have us cut our two cheapest demand creators.**
   Content and paid search open a third of all signup journeys and get **zero**
   last-touch credit. Under last-touch, paid search costs **$35k per signup**.
   Under position-based it costs **$841**. Same spend, same signups, a 40×
   different story.
2. **Retargeting looks like a star. That's exactly why I'd test it.**
   It gets 7 to 19 % of all signup credit depending on the model. Credit isn't
   proof, though. I'd run a four-week holdout before giving it more budget.
3. **Content downloads fill the MQL queue, not the pipeline.**
   They're 17 % of our leads but bring **$20 of bookings per lead**, against
   **$1,906** for partner referrals. That isn't marketing versus sales. It's a
   definition problem, and definitions can be fixed.
4. **We're judging ABM and webinars on the wrong number.**
   On sourced pipeline, LinkedIn ABM returns $1.1 per dollar. On influenced
   pipeline it returns $13. Webinars influence $69 per dollar. Both numbers
   belong in the review, side by side.

## 1. The models disagree most about who creates demand

Share of signup credit by channel, July 2025 to September 2026:

| Channel | First touch | Last touch | Linear | Position-based | Time decay |
|---|---:|---:|---:|---:|---:|
| Organic search | 23.6 % | 15.5 % | 16.7 % | 18.2 % | 14.7 % |
| Content (podcasts, blog, video) | 20.8 % | **0.0 %** | 9.4 % | 9.9 % | 5.1 % |
| Paid social | 20.0 % | 24.2 % | 27.9 % | 25.1 % | 31.0 % |
| Paid search | 12.2 % | **0.2 %** | 7.4 % | 6.7 % | 5.0 % |
| Referral | 9.2 % | 14.9 % | 8.5 % | 10.4 % | 9.2 % |
| Direct | 6.3 % | 37.5 % | 19.3 % | 20.6 % | 24.5 % |

What it costs us to get one signup, last 12 months:

| Paid channel | First touch | Last touch | Position-based | Time decay |
|---|---:|---:|---:|---:|
| Content (podcast sponsorships) | **$85** | n/a | $179 | $347 |
| Partnership | $202 | $159 | $205 | $241 |
| Paid social | $443 | $363 | $352 | $286 |
| Paid search | $460 | **$35,477** | $841 | $1,113 |

**What's going on.** A typical journey starts with a podcast, an article or a
search ad, and ends with a direct visit or a retargeting ad. Last-touch hands
the entire conversion to that final click, so everything that happened before
it simply vanishes.

**What I'd do.** Make position-based our planning default, and always show it
next to first and last touch so nobody has to take one model on faith. That's
how the dashboard's *Attribution* view is built. And no channel gets cut on
last-touch numbers alone.

## 2. Retargeting: test before we scale

Retargeting shows up right before people sign up in about a third of journeys,
and every model rewards it for that. That's what makes me cautious. It mostly
reaches people who were already about to convert, so the real question isn't
"does it get credit?" but "would these people have signed up anyway?"

**What I'd do.** Hold out 10 % of the retargeting audience for four weeks and
compare signup rates. Keep the budget flat until we know. Four weeks of
patience is cheaper than six months scaling something we can't prove works.

## 3. Content-download leads: lots of volume, very little value

| Lead source | Leads | Lead to MQL | Win rate | Bookings per lead |
|---|---:|---:|---:|---:|
| Partner referral | 198 | 83 % | 40 % | **$1,906** |
| Website demo request | 852 | 78 % | 29 % | $804 |
| Trade show | 572 | 59 % | 22 % | $396 |
| Webinar | 625 | 58 % | 22 % | $296 |
| Content download | 679 | 31 % | 17 % | **$20** |

On a dashboard, a full MQL queue looks like success. But sales development
spends the same time on a content-download MQL as on a demo request, and the
two are worth wildly different amounts.

**What I'd do.**
- A content download alone shouldn't make someone an MQL. Wait for a second
  high-intent signal, like a demo-page visit or a webinar attended, and keep
  everyone else in nurture.
- Partner referrals convert best and close fastest. I'd grow the reseller
  program before adding another event to the calendar.

## 4. Sourced and influenced pipeline: show both

| Enterprise channel | Spend | Sourced pipeline per $ | Influenced pipeline per $ |
|---|---:|---:|---:|
| Paid search | $115k | $23.4 | $32.4 |
| Partnership | $50k | $13.8 | $13.8 |
| Webinar | $42k | $14.1 | **$68.6** |
| Events | $85k | $13.2 | $21.4 |
| LinkedIn ABM (paid social) | $212k | **$1.1** | $13.1 |

I always report these two together, because each one alone tells a half-truth.
Sourced pipeline undersells programs like ABM and webinars, which rarely create
a lead but show up in most deals before the opportunity exists. Influenced
pipeline gives them their due, but it adds up to more than 100 %, so it can
never be summed across channels.

**What I'd do.** Put both in the weekly review. For programs designed to
accelerate deals, set targets on influenced pipeline and deal velocity, not on
sourced pipeline.

## What this analysis can't tell us

Being clear about the limits is part of what makes the numbers trustworthy:

- **12 % of paid upgrades have no marketing touch** in the 30-day window,
  because people upgrade long after they sign up. So I attribute marketing to
  signups and treat the upgrade to paid as a product metric.
- **These are media CACs.** Spend excludes salaries and tooling.
- **No attribution model measures incrementality.** That's what holdout tests
  are for, and why I'd run one before any budget shift above 20 %.
