* Appendix C: the main CBCP event studies re-estimated with standard errors
* clustered by county instead of by state.
*   Table C1  LAUS outcomes
*   Table C2  QCEW, all industries (NAICS 10)
*   Table C3  QCEW, labor-intensive industries (44-45, 56, 72)
*   Table C4  QCEW, high-skilled industries (51, 52, 54)
* Specifications are identical to contig_county_pair.do and
* contig_qcew_all_industry.do; only vce() changes.
* Paths are set in 00_master.do.

clear all

* ============================================================================
* Table C1: LAUS
* ============================================================================
use "$path/LAUS/LAUS_labor_contig.dta", clear
merge m:1 county_fips using "$path/county_population_2020.dta"
keep if _merge == 3
drop _merge

egen pair_period = group(countypair_id mdate)
gen lnPop = ln(population)
gen Epop = employment / population
gen LFPR = labforce / population
bysort county_fips mdate: gen county_count = _N
gen weight = population / county_count

gen rel_time = mdate - tm(2021m6)
local leads ""
forval i = 5(-1)1 {
    gen lead_`i' = (rel_time == -`i') * treated
    local leads "`leads' lead_`i'"
}
local lags ""
forval i = 1/3 {
    gen lag_`i' = (rel_time == `i') * treated
    local lags "`lags' lag_`i'"
}

eststo clear
foreach var in unemp_rate Epop LFPR {
    qui reghdfe `var' `leads' `lags' lnPop [aweight=weight], ///
        absorb(county_fips pair_period) ///
        vce(cluster county_fips)
    eststo est_`var'
    qui test `leads'
    estadd scalar pretrend_F = r(F)
}

esttab est_unemp_rate est_Epop est_LFPR ///
    using "$out/county_clustering/TableC1_LAUS_county_cluster.tex", replace ///
    drop(lnPop) b(3) se(3) ///
    stats(pretrend_F N r2, ///
        labels("F-statistic (pre-trend)" "Observations" "R\$^2\$") ///
        fmt(%9.3f %9.0fc %9.3f)) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("LAUS Event Study on CBCP, County-Clustered") ///
    mtitles("Unemp. Rate" "E-Pop" "LFPR") ///
    nobaselevels nonum collabels(none) booktabs label ///
    addnotes("Notes: All regressions include county and pair-period fixed effects." ///
             "Standard errors clustered by county.")

* ============================================================================
* Tables C2-C4: QCEW
* ============================================================================
use "$path/QCEW/QCEW_business_contig.dta", clear
merge m:1 county_fips using "$path/county_population_2020.dta"
keep if _merge == 3
drop _merge

egen pair_period = group(countypair_id qdate)
gen rel_time = qdate - tq(2021q2)
local leads ""
forval i = 3(-1)1 {
    gen lead_`i' = (rel_time == -`i') * treated
    local leads "`leads' lead_`i'"
}
gen lag_1 = (rel_time == 1) * treated

gen ind_clean = industry_code
replace ind_clean = "31" if ind_clean == "31-33"
replace ind_clean = "44" if ind_clean == "44-45"
replace ind_clean = "48" if ind_clean == "48-49"

local group10 ""10""             // all industries  -> Table C2
local group1  ""44", "56", "72"" // labor-intensive -> Table C3
local group2  ""51", "52", "54"" // high-skilled    -> Table C4
local tab10 "C2"
local tab1  "C3"
local tab2  "C4"
local name10 "All Industries"
local name1  "Labor-Intensive Industries"
local name2  "High-Skilled Industries"

foreach g in 10 1 2 {
    preserve
    keep if inlist(ind_clean, `group`g'')

    bysort county_fips qdate: gen county_count = _N
    gen weight = population / county_count
    gen lnPop = ln(population)

    eststo clear
    foreach var in lnEC lnEmp lnAWW {
        qui reghdfe `var' `leads' lag_1 lnPop [aweight=weight], ///
            absorb(county_fips pair_period) ///
            vce(cluster county_fips)
        eststo est_`var'
        qui test `leads'
        estadd scalar pretrend_F = r(F)
    }

    esttab est_lnEC est_lnEmp est_lnAWW ///
        using "$out/county_clustering/Table`tab`g''_QCEW_county_cluster.tex", replace ///
        drop(lnPop) b(3) se(3) ///
        stats(pretrend_F N r2, ///
            labels("F-statistic (pre-trend)" "Observations" "R\$^2\$") ///
            fmt(%9.3f %9.0fc %9.3f)) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("QCEW Event Study on CBCP, `name`g'', County-Clustered") ///
        mtitles("log(Estab. Count)" "log(Emp)" "log(Avg. Weekly Wage)") ///
        nobaselevels nonum collabels(none) booktabs label ///
        addnotes("Notes: All regressions include county and pair-period fixed effects." ///
                 "Standard errors clustered by county.")
    restore
}
