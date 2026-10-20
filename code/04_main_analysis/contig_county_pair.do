* Outline of the file
** 1) Event study on LAUS outcomes on contig sample
** 2) Event study on QCEW outcomes across all NAICS 2-digit industries

clear all
* Paths ($path, $out) are set in code/00_master.do
// capture log close 
// log using "contig main analysis.log", replace

* ============================================================================
* Event study on contiguous county pairs with LAUS outcomes
* ============================================================================
use "$path/LAUS/LAUS_labor_contig.dta", clear
merge m:1 county_fips using "$path/county_population_2020.dta"
keep if _merge == 3

egen pair_period = group(countypair_id mdate)

gen lnPop = ln(population)
gen Epop = employment / population
gen LFPR = labforce / population

bysort county_fips mdate: gen county_count = _N
gen weight = population / county_count

preserve

* Create event study leads and lags (We omit rel_time == 0 as the baseline)
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
local outcomes "unemp_rate Epop LFPR"
eststo clear
foreach var of local outcomes {
	
	reghdfe `var' `leads' `lags' lnPop [aweight=weight], ///
		absorb(county_fips pair_period) ///
		vce(cluster state)

    eststo est_`var'

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
  
    graph export "$out/contig_event_study/event_study_`var'.png", replace
}

esttab est_unemp_rate est_Epop est_LFPR ///
	using "$out/contig_event_study/LAUS_event_study_results_table.tex", replace ///
    drop(lnPop) ///
    b(3) se(3) ///
    stats(pretrend_F N r2, ///
        labels("F-statistic (pre-trend)" "Observations" "R\$^2\$") ///
        fmt(%9.3f %9.0fc %9.3f)) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event Study Results") ///
    mtitles("Unemp. Rate" "E/Pop" "LFPR") ///
    nobaselevels nonum collabels(none) ///
    booktabs label ///
    addnotes("Notes: All regressions include county and pair-period fixed effects." ///
             "Standard errors clustered by state.")

** Back-of-the-envelope calculation to reconcile results **
restore

sum labforce if mdate < tm(2021m6) & treated == 1
local mean_lf = r(mean)
sum employment if mdate < tm(2021m6) & treated == 1
local mean_emp = r(mean)

* Back-of-envelope calculation
estimates restore est_unemp_rate
local coeff_ur = _b[lag_1]        // first post-period coefficient (-0.532 in the paper)
local implied_jobs = (`coeff_ur' / 100) * `mean_lf'
local pct_change_emp = abs(`implied_jobs') / `mean_emp'

display "A `coeff_ur' pp drop in UR implies "abs(`implied_jobs') " people moved."
display "This is a "`pct_change_emp'*100 "% change in total employment."

** Pre-trend sensitivity check (Section 4.2.1) **
* Average of the five pre-period coefficients, and the first post-period
* coefficient net of that pre-existing gap (cf. Rambachan and Roth, 2023)
estimates restore est_unemp_rate
lincom (lead_5 + lead_4 + lead_3 + lead_2 + lead_1) / 5
lincom lag_1 - (lead_5 + lead_4 + lead_3 + lead_2 + lead_1) / 5
			
			
* ============================================================================
* Event study on contiguous county pairs with QCEW outcomes
* Two groups of industries
* ============================================================================
use "$path/QCEW/QCEW_business_contig.dta", clear
merge m:1 county_fips using "$path/county_population_2020.dta"
keep if _merge == 3
drop _merge

egen pair_period = group(countypair_id qdate)
gen event_date = tq(2021q2)
gen rel_time = qdate - event_date

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

* Create county weights in subsamples
bysort county_fips qdate: gen county_count = _N
gen weight = population / county_count
gen lnPop = ln(population)

foreach var in lnEC lnAWW lnEmp {
    qui reghdfe `var' `leads' lag_1 lnPop [aweight=weight], ///
		absorb(county_fips pair_period) ///
        vce(cluster state)
	
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
    
    graph export "$out/contig_event_study/event_study_`var'_`g'.png", replace
	}
	esttab est_lnEC_`g' est_lnEmp_`g' est_lnAWW_`g' ///
	using "$out/contig_event_study/QCEW_results_table_`g'.tex", replace ///
    drop(lnPop) ///
    b(3) se(3) ///
    stats(pretrend_F N r2, ///
        labels("F-statistic (pre-trend)" "Observations" "R\$^2\$") ///
        fmt(%9.3f %9.0fc %9.3f)) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event Study Results") ///
    mtitles("log(Estab. Count)" "log(Emp)" "log(Avg. Weekly Wage)") ///
    nobaselevels nonum collabels(none) ///
    booktabs label ///
    addnotes("Notes: All regressions include county and pair-period fixed effects." ///
             "Standard errors clustered by state.")
	restore
}

// log close
