-- level minus previous level should equal the source's change_weekly row
with levels as (
    select
        effective_date,
        ron95 - lag(ron95) over w as ron95_diff,
        ron97 - lag(ron97) over w as ron97_diff,
        diesel - lag(diesel) over w as diesel_diff
    from {{ ref('int_fuel_levels') }}
    window w as (order by effective_date)
),

changes as (
    select effective_date, ron95, ron97, diesel
    from {{ ref('stg_fuelprice') }}
    where series_type = 'change_weekly'
)

-- full join so a date missing on either side also fails
select
    coalesce(l.effective_date, c.effective_date) as effective_date,
    l.ron95_diff, c.ron95 as ron95_change,
    l.ron97_diff, c.ron97 as ron97_change,
    l.diesel_diff, c.diesel as diesel_change
from levels l
full join changes c on l.effective_date = c.effective_date
where not (l.ron95_diff is null and c.effective_date is null)   -- first level row has no change
  and (
       l.effective_date is null
    or c.effective_date is null
    or coalesce(abs(l.ron95_diff - c.ron95), 1) >= 1e-6
    or coalesce(abs(l.ron97_diff - c.ron97), 1) >= 1e-6
    or coalesce(abs(l.diesel_diff - c.diesel), 1) >= 1e-6
  )
