* Figure 3: all-industry (private sector, NAICS 10) QCEW event study on the
* contiguous border county-pair sample.
* Paths are set in 00_master.do. Run after QCEW_data_setup.do.

clear all

use "$path/QCEW/QCEW_business_contig.dta", clear
keep if industry_code == "10"
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

bysort county_fips qdate: gen county_count = _N
gen weight = population / county_count
gen lnPop = ln(population)

local coeflabels ""
forval i = `window_pre'(-1)1 {
    local coeflabels `"`coeflabels' lead_`i' = "-`i'""'
}
local coeflabels `"`coeflabels' lag_1 = "1""'

eststo clear
foreach var in lnEC lnEmp lnAWW {
    qui reghdfe `var' `leads' lag_1 lnPop [aweight=weight], ///
        absorb(county_fips pair_period) ///
        vce(cluster state)

    eststo est_`var'
    qui test `leads'
    estadd scalar pretrend_F = r(F)

    coefplot est_`var', ///
        keep(`leads' lag_1) ///
        vertical ///
        base ///
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
        name(`var'_10_plot, replace)

    graph export "$out/contig_event_study/event_study_`var'_10.png", replace
}

esttab est_lnEC est_lnEmp est_lnAWW ///
    using "$out/contig_event_study/QCEW_results_table_10.tex", replace ///
    drop(lnPop) ///
    b(3) se(3) ///
    stats(pretrend_F N r2, ///
        labels("F-statistic (pre-trend)" "Observations" "R\$^2\$") ///
        fmt(%9.3f %9.0fc %9.3f)) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event Study Results: All Industries (NAICS 10)") ///
    mtitles("log(Estab. Count)" "log(Emp)" "log(Avg. Weekly Wage)") ///
    nobaselevels nonum collabels(none) ///
    booktabs label ///
    addnotes("Notes: All regressions include county and pair-period fixed effects." ///
             "Standard errors clustered by state.")
