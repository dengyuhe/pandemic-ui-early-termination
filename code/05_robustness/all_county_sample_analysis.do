* Outline of the file
** 1) Event study on LAUS outcomes on all_county sample
** 2) Event study on QCEW outcomes across all NAICS 2-digit industries

clear all
* Paths ($path, $out) are set in code/00_master.do

* ============================================================================
* Event study on all counties with LAUS outcomes
* ============================================================================
use "$path/LAUS/laus_cleaned.dta", clear

merge m:1 county_fips using "$path/all_county_list.dta"
keep if _merge == 3
drop _merge
merge m:1 county_fips using "$path/county_population_2020.dta"
keep if _merge == 3
drop _merge

foreach var in unemp_rate unemployment employment labforce {
    * Replace various missing codes with empty string
    replace `var' = "" if inlist(`var', "N/A", "NA", "-", "*", ".")
    replace `var' = "" if trim(`var') == "" | trim(`var') == "-"
   
    * Remove commas
    replace `var' = subinstr(`var', ",", "", .)
   
    * Destring (empty strings become missing .)
    destring `var', replace
}

gen lnPop = ln(population)
gen Epop = employment / population
gen LFPR = labforce / population
gen lnEmp = ln(employment)
gen lnUnemp = ln(unemployment)
gen lnLF = ln(labforce)

gen event_date = tm(2021m6)
gen rel_time = mdate - event_date
local window_pre  5
local window_post 3
forval i = 1/`window_pre' {
    gen lead_`i' = (rel_time == -`i') * treated
}
forval i = 1/`window_post' {
    gen lag_`i' = (rel_time == `i') * treated
}
local leads ""
forval i = `window_pre'(-1)1 {
    local leads "`leads' lead_`i'"
}
local lags ""
forval i = 1/`window_post' {
    local lags "`lags' lag_`i'"
}

** Run Event Study Regressions and Store Results **
local outcomes "unemp_rate Epop LFPR lnEmp lnUnemp lnLF"
eststo clear
foreach var of local outcomes {
	reghdfe `var' `leads' `lags', ///
		absorb(county_fips mdate) ///
		vce(cluster state_fips)

    * Store estimates for table and plotting
    eststo est_`var'
    * Calculate and store pre-trend test statistics
    qui test `leads'
    estadd scalar pretrend_F = r(F)

    local coeflabels ""
    forval i = `window_pre'(-1)1 {
        local coeflabels `"`coeflabels' lead_`i' = "-`i'""'
    }
    forval i = 1/`window_post' {
        local coeflabels `"`coeflabels' lag_`i' = "`i'""'
    }
	
coefplot est_`var', ///
    keep(`leads' `lags') ///
    vertical ///
    base                              /// explicitly mark the omitted period
    yline(0, lcolor(black) lwidth(vthin) lpattern(solid)) ///
    xline(`=`window_pre' + 0.5', lcolor(gs10) lpattern(dash) lwidth(thin)) ///
    ytitle("Coefficient (95% CI)", size(small) margin(r=2)) ///
    xtitle("Months Relative to UI Early Termination", size(small) margin(t=2)) ///
    xlabel(, labsize(vsmall) angle(0) nogrid) ///
    ylabel(, labsize(vsmall) format(%9.3f) nogrid angle(0)) ///
    coeflabels(`coeflabels', notick labsize(vsmall)) ///
    ciopts(recast(rcap) lwidth(medthin) lcolor(gs6)) ///
    msymbol(D) msize(vsmall) mcolor(black) mlwidth(thin) ///
    plotregion(style(none) margin(small)) ///
    graphregion(color(white)) ///
    bgcolor(white) ///
    scheme(s2mono) ///
    legend(off) ///
    note("Note: Omitted category is month 0. Dashed line indicates policy date." ///
         "Standard errors clustered by state.", size(vsmall)) ///
    name(`var'_plot, replace)
   
    graph export "$out/all_county/event_study_all_`var'.png", replace
}

	
* ============================================================================
* Event study on all counties with QCEW outcomes
* labor-intensive and high-skilled industry groups
* ============================================================================
	
use "$path/QCEW/qcew_cleaned.dta", clear

merge m:1 county_fips using "$path/all_county_list.dta"
keep if _merge == 3
drop _merge

gen event_date = tq(2021q2)
gen rel_time = qdate - event_date
* Create event study leads and lags (omit the treatment period as the baseline)
local window_pre 3
forval i = 1/`window_pre' {
    gen lead_`i' = (rel_time == -`i') * treated
}
local leads ""
forval i = `window_pre'(-1)1 {
    local leads "`leads' lead_`i'"
}
gen lag_1 = (rel_time == 1) * treated

gen ind_clean = industry_code
replace ind_clean = "31" if ind_clean == "31-33"
replace ind_clean = "44" if ind_clean == "44-45"
replace ind_clean = "48" if ind_clean == "48-49"

local group1 ""44", "56", "72"" // labor-intensive
local group2 ""51", "52", "54"" // high-skilled

eststo clear
** Run Event Study Regressions and Store Results
foreach g in 1 2 {
preserve
keep if inlist(ind_clean, `group`g'')

foreach var in lnEC lnAWW lnEmp {
    qui reghdfe `var' `leads' lag_1, ///
		absorb(county_fips qdate) ///
		vce(cluster state_fips)
	
    eststo est_`var'_`g'

	qui test `leads'
    estadd scalar pretrend_F = r(F)

    * Create coefficient plot
	local coeflabels ""
    forval i = `window_pre'(-1)1 {
        local coeflabels `"`coeflabels' lead_`i' = "-`i'""'
    }
    local coeflabels `"`coeflabels' lag_1 = "1""'
    
	coefplot est_`var'_`g', ///
        keep(`leads' lag_1) ///
        vertical ///
		base /// explicitly mark the omitted period
		yline(0, lcolor(black) lwidth(vthin) lpattern(solid)) ///
		xline(`=`window_pre' + 0.5', lcolor(gs10) lpattern(dash) lwidth(thin)) ///
		ytitle("Coefficient (95% CI)", size(small) margin(r=2)) ///
		xtitle("Quarters Relative to UI Early Termination", size(small) margin(t=2)) ///
		xlabel(, labsize(vsmall) angle(0) nogrid) ///
		ylabel(, labsize(vsmall) format(%9.3f) nogrid angle(0)) ///
        coeflabels(`coeflabels', notick labsize(vsmall)) ///
        ciopts(recast(rcap) lwidth(medthin) lcolor(gs6)) ///
		msymbol(D) msize(vsmall) mcolor(black) mlwidth(thin) ///
		plotregion(style(none) margin(small)) ///
		graphregion(color(white)) ///
		bgcolor(white) ///
		scheme(s2mono) ///
		legend(off) ///
		note("Note: Omitted category is quarter 0. Dashed line indicates policy date." ///
         "Standard errors clustered by state.", size(vsmall)) ///
		name(`var'_`g'_plot, replace)
    
    graph export "$out/all_county/event_study_all_`var'_`g'.png", replace
	}
// 	esttab est_lnEC_`g' est_lnAWW_`g' est_lnEmp_`g' ///
// 	using "$out/contig_event_study/QCEW_results_table_`g'.tex", replace ///
//     drop(lnPop) ///
//     b(3) se(3) ///
//     stats(pretrend_F N r2, ///
//         labels("F-statistic (pre-trend)" "Observations" "R\$^2\$") ///
//         fmt(%9.3f %9.0fc %9.3f)) ///
//     star(* 0.10 ** 0.05 *** 0.01) ///
//     title("Event Study Results") ///
//     mtitles("log(EC)" "log(AWW)" "log(Emplvl)") ///
//     nobaselevels nonum collabels(none) ///
//     booktabs label ///
//     addnotes("Notes: All regressions include county and pair-period fixed effects." ///
//              "Standard errors clustered by state and county pair.")
	restore
}
