clear all
* Paths ($path, $out) are set in code/00_master.do

use "$path/QCEW/qcew_cleaned.dta", clear
keep if qdate < tq(2021q2)
* keep construction, manufacturing, retail, restaurant/hospitality
keep if inlist(industry_code, "10", "31-33", "44-45", "72")
replace industry_code = subinstr(industry_code, "-", "", .)
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

use "$path/QCEW/qcew_cleaned.dta", clear
keep if qdate < tq(2021q2)
keep if industry_code == "10"
collapse (mean) qtrly_emplvl lnEmp lnAWW, by(county_fips)
rename (qtrly_emplvl lnEmp lnAWW) (priv_avg_emp priv_lnEmp priv_lnAww)
tempfile private_emp
save `private_emp'

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

use "$path/all_county_list.dta", clear
merge 1:1 county_fips using `raw_shares', keep(3) nogen
merge 1:1 county_fips using `private_emp', keep(3) nogen
merge 1:1 county_fips using `pop_dens', keep(3) nogen
merge 1:1 county_fips using `urban_rural', keep(3) nogen
gen weight = population
save "$out/balance_test/balance_all_merged.dta", replace

local outcomes   "share_3133 share_4445 share_72 aww_3133 aww_4445 aww_72 priv_avg_emp pop_density urban_share"

tempname results
postfile `results' str32 varname ///
    float(b_ac se_ac pval mean_ac) ///
    using "$out/temp_results.dta", replace

foreach oc of local outcomes {
    use "$out/balance_test/balance_all_merged.dta", clear
	
    quietly reg `oc' treated [aweight=weight], vce(robust)	
	local b_ac  = _b[treated]
    local se_ac = _se[treated]
	local pval  = 2 * ttail(e(df_r), abs(`b_ac' / `se_ac'))
	
    quietly sum `oc' if treated == 0
    local m_ac  = r(mean)
	
	post `results' ("`oc'") (`b_ac') (`se_ac') (`pval') (`m_ac')
}

postclose `results'

use "$out/temp_results.dta", clear

gen stars = ""
replace stars = "*"   if pval < 0.10
replace stars = "**"  if pval < 0.05
replace stars = "***" if pval < 0.01

gen coef_str = string(round(b_ac, 0.001)) + stars
gen se_str   = "(" + string(round(se_ac, 0.001)) + ")"
gen mean_str = string(round(mean_ac, 0.001))

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

rename (varname coef_str se_str mean_str) ///
       (Outcome Coeff_AC SE_AC Mean_AC)

listtex Outcome Coeff_AC SE_AC Mean_AC ///
    using "$out/balance_test/all_balance_table.tex", replace ///
    rstyle(tabular) ///
    head("\begin{table}[htbp]\centering" ///
         "\begin{tabular}{lccc}" ///
         "\hline\hline" ///
         "Outcome & Coefficient & SE & Control Mean \\" ///
         "\hline") ///
    foot("\hline\hline" ///
         "\multicolumn{4}{l}{\footnotesize * p$<$0.10, ** p$<$0.05, *** p$<$0.01} \\" ///
         "\end{tabular}" ///
         "\end{table}")
