** Descriptive Statistics Table (table 1)
* Three columns (1)AC (2)CBCP (3)PCP, each with two subcolumns (a)Mean (b)s.d.
* Each row for a characteristic variable
** The aim is to let the reader have a better sense of the quality of each sample ///

** Table 1 provides descriptive statistics for the two samples.
** Comparing the AC sample (column 1) to the CBC sample (column 2), we find that they are quite similar in
** terms of population, density, employment levels, and average earnings.

clear all
* Paths ($path, $out) are set in code/00_master.do

* ====================================
* industry composition outcomes
* ====================================
use "$path/QCEW/qcew_cleaned.dta", clear
keep if qdate < tq(2021q2)
* keep construction, manufacturing, retail, restaurant/hospitality
keep if inlist(industry_code, "10", "31-33", "44-45", "72")
replace industry_code = subinstr(industry_code, "-", "", .)
collapse (mean) qtrly_emplvl avg_wkly_wage, by(county_fips industry_code)
reshape wide qtrly_emplvl avg_wkly_wage, i(county_fips) j(industry_code) string
rename qtrly_emplvl10 priv_avg_emp
drop avg_wkly_wage10 

foreach ind in 3133 4445 72 {
	rename qtrly_emplvl`ind' emp_`ind'
	rename avg_wkly_wage`ind' aww_`ind'
}

keep county_fips emp_* aww_* priv_avg_emp
tempfile ind_metric
save `ind_metric'


* ====================================
* population (density)
* ====================================
import delimited "$path/2020_Gaz_counties_national.txt", clear
rename (geoid aland_sqmi) (county_fips land_area)
keep county_fips land_area
merge 1:1 county_fips using "$path/county_population_2020.dta"
gen pop_density = population/land_area

tempfile pop
save `pop'

* ====================================
* Merge all balance variables
* ====================================
use "$path/all_county_list.dta", clear
merge 1:1 county_fips using `ind_metric', keep(3) nogen
merge 1:1 county_fips using `pop', keep(3) nogen
save "$out/descriptive/all_merged.dta", replace

use "$path/county_pair_list.dta", clear
keep county_fips 
duplicates drop county_fips, force
merge 1:1 county_fips using `ind_metric', keep(3) nogen
merge 1:1 county_fips using `pop', keep(3) nogen
save "$out/descriptive/contig_merged.dta", replace

use "$path/pseudo_pair_list.dta", clear
keep county_fips
duplicates drop county_fips, force
merge 1:1 county_fips using `ind_metric', keep(3) nogen
merge 1:1 county_fips using `pop', keep(3) nogen
save "$out/descriptive/pseudo_merged.dta", replace

* Sample counts for the bottom rows of Table 1
use "$path/all_county_list.dta", clear
qui levelsof county_fips
local county_num_all = r(r)
qui levelsof state_fips
local state_num_all = r(r)
local cp_num_all = .

use "$path/county_pair_list.dta", clear
qui levelsof county_fips
local county_num_contig = r(r)
qui levelsof countypair_id
local cp_num_contig = r(r)
qui levelsof state
local state_num_contig = r(r)

use "$path/pseudo_pair_list.dta", clear
qui levelsof county_fips
local county_num_pseudo = r(r)
qui levelsof pseudo_pair_id
local cp_num_pseudo = r(r)
qui levelsof state
local state_num_pseudo = r(r)

local vars "population pop_density land_area priv_avg_emp emp_3133 aww_3133 emp_4445 aww_4445 emp_72 aww_72 county_num cp_num state_num"

tempname result
postfile `result' str80 varname ///
    float(m_ac sd_ac) ///   // (1) All-County
    float(m_cbcp sd_cbcp) /// // (2) Contiguous Border
    float(m_pcp sd_pcp) ///   // (3) Pseudo-Pair
    using "$out/descriptive/descrip_results.dta", replace


foreach v of local vars {

    local stats ""
    
    foreach d in "all" "contig" "pseudo" {
        use "$out/descriptive/`d'_merged.dta", clear
        
        * Standard Numeric Variables
        if !inlist("`v'", "county_num", "cp_num", "state_num") {
            quietly sum `v'
            local m_`d'  = r(mean)
            local sd_`d' = r(sd)
        }
        
        * Sample Counts (Bottom of Table)
        else {
            local sd_`d' = . 
            
			local m_`d' = ``v'_`d''   // counts computed above

        }
    }
    
    * Post the row to the results file
    post `result' ("`v'") (`m_all') (`sd_all') (`m_contig') (`sd_contig') (`m_pseudo') (`sd_pseudo')
}

postclose `result'

* ====================================
* Clean and Export the Final Table
* ====================================
use "$out/descriptive/descrip_results.dta", clear

* Assign Labels
replace varname = "Population, 2020"              if varname == "population"
replace varname = "Population density, 2020"            if varname == "pop_density"
replace varname = "Land area (sq. miles)"         if varname == "land_area"
replace varname = "Overall private employment"    if varname == "priv_avg_emp"
replace varname = "Manufacturing employment"      if varname == "emp_3133"
replace varname = "Manufacturing weekly wage ($)" if varname == "aww_3133"
replace varname = "Retail employment"             if varname == "emp_4445"
replace varname = "Retail weekly wage ($)"        if varname == "aww_4445"
replace varname = "Restaurant employment"         if varname == "emp_72"
replace varname = "Restaurant weekly wage ($)"    if varname == "aww_72"
replace varname = "Number of counties"            if varname == "county_num"
replace varname = "Number of county-pairs"        if varname == "cp_num"
replace varname = "Number of states"              if varname == "state_num"

export delimited using "$out/descriptive/Table1_Descriptive_Stats.csv", replace
