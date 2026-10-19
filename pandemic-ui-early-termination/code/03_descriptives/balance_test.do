* Outline for this file: Sanity Check *
** 1) Balance test for contig county pair sample (control vs treated)
** 2) Balance test for pseudo county pair sample 
** Outcomes: population(density), share of urban, share of retail/manufacturing, private sector employment

clear all
* Paths ($path, $out) are set in code/00_master.do

// capture log close 
// log using "$path/log files/balance test.log", replace

* ====================================
* industry composition outcomes
* ====================================
use "$path/QCEW/qcew_cleaned.dta", clear
keep if qdate < tq(2021q2)
* keep construction, manufacturing, retail, restaurant/hospitality
keep if inlist(industry_code, "10", "31-33", "44-45", "72")
replace industry_code = subinstr(industry_code, "-", "", .)

* -------------------------------------------------------
* 1) raw shares of industry
* -------------------------------------------------------
* keep construction, manufacturing, retail, finance, healthcare, restaurant/hospitality
collapse (mean) qtrly_emplvl avg_wkly_wage, by(county_fips industry_code)
reshape wide qtrly_emplvl avg_wkly_wage, i(county_fips) j(industry_code) string
rename qtrly_emplvl10 emp_total
drop avg_wkly_wage10 

foreach ind in 3133 4445 72 {
	rename qtrly_emplvl`ind' emp_`ind'
	rename avg_wkly_wage`ind' aww_`ind'
    gen share_`ind' = emp_`ind' / emp_total
}

keep county_fips share_* aww_*
tempfile raw_shares
save `raw_shares'

* -------------------------------------------------------
* 2) private sector employment level
* -------------------------------------------------------
use "$path/QCEW/qcew_cleaned.dta", clear
keep if qdate < tq(2021q2)
keep if industry_code == "10"
collapse (mean) qtrly_emplvl lnEmp lnAWW, by(county_fips)
rename (qtrly_emplvl lnEmp lnAWW) (priv_avg_emp priv_lnEmp priv_lnAww)

tempfile private_emp
save `private_emp'

* -------------------------------------------------------
* 3) Population density and urban share
* -------------------------------------------------------
import delimited "$path/2020_Gaz_counties_national.txt", clear
rename geoid county_fips
keep county_fips aland_sqmi
merge 1:1 county_fips using "$path/county_population_2020.dta"
gen pop_density = population/aland_sqmi
keep county_fips pop_density population

tempfile pop_dens
save `pop_dens'

import delimited "$path/urban_rural/nhgis0001_ds258_2020_county.csv", clear 
rename (geocode u7i001 u7i002 u7i003 u7i004) (county_fips Total urban rural undefined)
gen urban_share = urban/Total
gen rural_share = rural/Total
keep county_fips urban_share rural_share

tempfile urban_rural
save `urban_rural'


* ====================================
* Merge all balance variables
* ====================================
use "$path/county_pair_list.dta", clear
merge m:1 county_fips using `raw_shares', keep(3) nogen
merge m:1 county_fips using `private_emp', keep(3) nogen
merge m:1 county_fips using `pop_dens', keep(3) nogen
merge m:1 county_fips using `urban_rural', keep(3) nogen
bysort county_fips: gen county_count = _N
gen weight = population / county_count
save "$out/balance_test/balance_contig_merged.dta", replace

use "$path/pseudo_pair_list.dta", clear
merge m:1 county_fips using `raw_shares', keep(3) nogen
merge m:1 county_fips using `private_emp', keep(3) nogen
merge m:1 county_fips using `pop_dens', keep(3) nogen
merge m:1 county_fips using `urban_rural', keep(3) nogen
bysort county_fips: gen county_count = _N
gen weight = population / county_count
save "$out/balance_test/balance_pseudo_merged.dta", replace

* ====================================
* Balance regressions
* ====================================
local outcomes   "share_3133 share_4445 share_72 aww_3133 aww_4445 aww_72 priv_avg_emp pop_density urban_share"

tempname results
postfile `results' str32 varname ///
    float(b_contig se_contig mean_contig) ///
    float(b_pseudo se_pseudo mean_pseudo) ///
    using "$out/temp_results.dta", replace

foreach oc of local outcomes {

    * --- Contiguous Pairs ---
    use "$out/balance_test/balance_contig_merged.dta", clear
    quietly reghdfe `oc' treated [aweight=weight], absorb(countypair_id) vce(cluster state)
    local b_c  = _b[treated]
    local se_c = _se[treated]
    quietly sum `oc' if treated == 0
    local m_c  = r(mean)

    * --- Pseudo Pairs ---
    use "$out/balance_test/balance_pseudo_merged.dta", clear
    quietly reghdfe `oc' treated [aweight=weight], absorb(pseudo_pair_id) vce(cluster parent_pair_id state)
    local b_p  = _b[treated]
    local se_p = _se[treated]
    quietly sum `oc' if treated == 0
    local m_p  = r(mean)

    post `results' ("`oc'") (`b_c') (`se_c') (`m_c') (`b_p') (`se_p') (`m_p')
}

postclose `results'

use "$out/temp_results.dta", clear

* Clean variable names
replace varname = "Manufacturing share"      if varname == "share_3133"
replace varname = "Retail share"             if varname == "share_4445"
replace varname = "Accommodation share"      if varname == "share_72"
replace varname = "Manufacturing wage"       if varname == "aww_3133"
replace varname = "Retail wage"              if varname == "aww_4445"
replace varname = "Accommodation wage"       if varname == "aww_72"
replace varname = "Private sector employment" if varname == "priv_avg_emp"
replace varname = "Population density"       if varname == "pop_density"
replace varname = "Urban share"              if varname == "urban_share"

rename (varname b_contig se_contig mean_contig b_pseudo se_pseudo mean_pseudo) ///
       (Outcome Coeff_C SE_C Mean_C Coeff_P SE_P Mean_P)

export delimited Outcome Coeff_C SE_C Mean_C Coeff_P SE_P Mean_P ///
    using "$out/balance_test/balance_table.csv", replace

// log close
