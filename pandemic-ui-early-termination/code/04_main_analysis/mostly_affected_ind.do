* this file intend to figure out which of the industries underwent an expansion 
* in employment immediately after policy shock (reconcile LAUS UR drop)
clear all
* Paths ($path, $out) are set in code/00_master.do

use "$path/QCEW/QCEW_business_contig.dta", clear
merge m:1 county_fips using "$path/county_population_2020.dta"
keep if _merge == 3

gen ind_clean = industry_code
replace ind_clean = "31" if ind_clean == "31-33"
replace ind_clean = "44" if ind_clean == "44-45"
replace ind_clean = "48" if ind_clean == "48-49"

gen post = (qdate == yq(2021, 3))
egen pair_period = group(countypair_id qdate)

bysort county_fips qdate: gen county_count = _N
gen weight = population / county_count

tempname memhold
tempfile results

postfile `memhold' str10 ind_clean double beta se pval using `results', replace

levelsof ind_clean, local(indlist)

eststo clear
foreach s of local indlist {
		qui reghdfe lnEmp i.treated##i.post [aweight=weight] if ind_clean == "`s'" , ///
        absorb(county_fips pair_period) ///
        vce(cluster state)
		
		local p = 2 * ttail(e(df_r), abs(_b[1.treated#1.post]/_se[1.treated#1.post]))
		
		post `memhold' ("`s'") ///
        (_b[1.treated#1.post]) ///
        (_se[1.treated#1.post]) ///
		(`p')
}

postclose `memhold'

use `results', clear
gen lb = beta - 1.96*se
gen ub = beta + 1.96*se

gen stars = ""
replace stars = "*"   if pval < 0.10
replace stars = "**"  if pval < 0.05
replace stars = "***" if pval < 0.01

gsort beta
cap gen x = _n

gen beta_fmt = string(beta, "%9.3f") + stars
gen se_fmt   = "(" + string(se, "%9.3f") + ")"
gen pval_fmt = string(pval, "%9.3f")

cap gen ind_num = real(ind_clean)

label define ind_lbl ///
	10 "All Industry" ///
    11 "Agriculture" ///
    21 "Mining" ///
    22 "Utilities" ///
    23 "Construction" ///
    31 "Manufacturing" ///
    42 "Wholesale Trade" ///
    44 "Retail Trade" ///
    48 "Transportation & Warehousing" ///
    51 "Information" ///
    52 "Finance & Insurance" ///
    53 "Real Estate" ///
    54 "Professional Services" ///
    55 "Management of Companies" ///
    56 "Admin & Waste Services" ///
    61 "Educational Services" ///
    62 "Health & Social Assistance" ///
    71 "Arts & Recreation" ///
    72 "Accommodation & Food" ///
    81 "Other Services" ///
    92 "Public Administration" ///
    99 "Unclassified", replace

label values ind_num ind_lbl

* create table output
decode ind_num, gen(Industry)

* Exporting to a .tex file
local header "\begin{table}[h]" ///
    "\centering" ///
    "\caption{Regression Results by Industry}" ///
    "\begin{tabularx}{\textwidth}{l XXX}" ///
    "\hline\hline" ///
    "Industry & $\beta$ & s.e. & p-value \\ \hline"

local footer "\hline\hline" ///
    "\multicolumn{4}{l}{\footnotesize Standard errors clustered by state. * $p<0.10$, ** $p<0.05$, *** $p<0.01$} \\" ///
    "\end{tabularx}" ///
    "\end{table}"

listtab Industry beta_fmt se_fmt pval_fmt using "$out/industry/lnemp_ind.tex", ///
    replace rstyle(tabular) head("`header'") foot("`footer'")

* create graph output	
levelsof x, local(xvals)

forvalues i = 1/`=_N' {
    local code = ind_num[`i']
    local xlabs `xlabs' `i' `"`: label ind_lbl `code''"'
}

twoway ///
    (bar beta x, barwidth(0.8) fcolor("84 126 174") lcolor(black) lwidth(vthin)) ///
    (rcap lb ub x, lcolor(black) lwidth(medium)), ///
    xlabel(`xlabs', angle(45) labsize(vsmall) nogrid) ///
    yline(0, lcolor(black) lwidth(thin)) ///
    ytitle("Estimate") ///
    xtitle("") ///
    legend(off)
	
graph export "$out/industry/lnemp_ind.png", replace
