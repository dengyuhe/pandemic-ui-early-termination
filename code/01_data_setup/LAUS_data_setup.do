* Prepare LAUS Outcomes
clear all
* Paths ($path, $out) are set in code/00_master.do

* Import LAUS flat file
import delimited "$path/LAUS/la.data.64.County.txt", clear

* Parse Series ID: LAUCN + 5-digit FIPS + 0000000 + 2-digit measure
* Measure 03 = Unemp Rate, 04 = Unemployment, 05 = Employment, 06 = Labor Force
* Note: Measure 07 = E-Pop Ratio, 08 = Labor Force Participation Rate, 09 = Civilian Pop not available
gen county_fips = real(substr(series_id, 6, 5))
gen measure = substr(series_id, 19, 2)

* Convert Period (M01-M12) to a numeric month
* Remove M13 (Annual average)
drop if period == "M13"
gen month = real(substr(period, 2, 2))

* Create a date variable (Monthly)
gen mdate = ym(year, month)
format mdate %tm

* Keep only necessary variables
keep county_fips mdate measure value

* Reshape to wide format - one row per fips-year-month
reshape wide value, i(county_fips mdate) j(measure) string

* Rename variables with meaningful names
rename value03 unemp_rate
rename value04 unemployment
rename value05 employment
rename value06 labforce

order county_fips mdate unemp_rate unemployment employment labforce
sort county_fips mdate
* Convert FIPS to long in both datasets before merging
recast long county_fips, force

save "$path/LAUS/laus_cleaned.dta", replace

* Merge LAUS outcomes with the skeleton
use "$path/county_pair_list.dta", clear

* Join with the panel data
* joinby handles the "many-to-many" logic (County A in multiple pairs over multiple months)
joinby county_fips using "$path/LAUS/laus_cleaned.dta"
keep county_fips countypair_id state treated mdate unemp_rate unemployment employment labforce
* Replace missing value codes with empty string
foreach var in unemp_rate unemployment employment labforce {
    * Replace various missing codes with empty string
    replace `var' = "" if inlist(`var', "N/A", "NA", "-", "*", ".")
    replace `var' = "" if trim(`var') == "" | trim(`var') == "-"
    
    * Remove commas
    replace `var' = subinstr(`var', ",", "", .)
    
    * Destring (empty strings become missing .)
    destring `var', replace
}
misstable summarize unemp_rate unemployment employment labforce
* Create log transformation except for unemp_rate
gen lnEmp = ln(employment) if employment > 0
gen lnUnemp = ln(unemployment) if unemployment > 0
gen lnLF = ln(labforce) if labforce > 0

sort county_fips countypair_id mdate
save "$path/LAUS/LAUS_labor_contig.dta", replace
