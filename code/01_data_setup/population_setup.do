** This file prepares the county-level population metric **
** We use the 2020 census data **
import delimited "$path/PopulationEstimates.csv", clear
gen county_fips = string(fipstxt, "%05.0f") 
keep if substr(county_fips, -3, 3) != "000"
keep if attribute == "CENSUS_2020_POP"
rename value population
keep county_fips population
destring county_fips, replace force
order county_fips population  
sort county_fips
save "$path/county_population_2020.dta", replace
