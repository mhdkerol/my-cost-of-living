-- every pump price should be above zero
select *
from {{ ref('int_fuel_levels') }}
where ron95 <= 0
   or ron97 <= 0
   or diesel <= 0
   or diesel_eastmsia <= 0
