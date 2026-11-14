-- pump prices (RM per litre) as published, one row per effective_date
-- full history kept so int_fuel_daily can carry the pre-2022 price forward
select
    effective_date,
    ron95,
    ron97,
    diesel,
    diesel_eastmsia,   -- differs from diesel since 2024-06-10
    _loaded_at,
    _source_url
from {{ ref('stg_fuelprice') }}
where series_type = 'level'   -- change_weekly rows hold RM change vs previous level
