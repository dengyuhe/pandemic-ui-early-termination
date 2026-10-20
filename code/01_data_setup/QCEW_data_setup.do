*** Prepare QCEW outcomes ***

clear all
* Paths ($path, $out) are set in code/00_master.do

local years "2020 2021"
* Create a list of all NAICS codes to process
local 2_digit_ind "10 11 21 22 23 31-33 42 44-45 48-49 51 52 53 54 55 56 61 62 71 72 81"

tempfile master_qcew
local first_file = 1

foreach yr in `years' {
foreach ind in `2_digit_ind' {
    
    * Resolve the wildcard filename using the 'dir' command
    * This finds the actual name of the file starting with that industry number
    local pattern "`yr'.q1-q4 * `ind' *.csv"
    local actual_file : dir "$path/`yr'.q1-q4.by_industry" files "`pattern'"
    * Clean the local (remove quotes)
    local actual_file : display `actual_file'
    
    if "`actual_file'" == "" {
        display as error "Warning: No file found for industry `ind'"
        continue
    }
	
    
    import delimited "$path/`yr'.q1-q4.by_industry/`actual_file'", clear
    
    * 1. Filter for Private Ownership only (own_code == 5) and 
	* county-level observations only (last 3 digits != 000)
    keep if own_code == 5
	keep if substr(area_fips, -3, 3) != "000"
	drop if substr(area_fips, 1, 1) == "C"
    
    * 2. Generate Average Quarterly Employment (actual and LQ)
	* Only calculate if all 3 months are present
	gen qtrly_emplvl = (month1_emplvl + month2_emplvl + month3_emplvl) / 3 ///
		if !missing(month1_emplvl) & !missing(month2_emplvl) & !missing(month3_emplvl)
	gen lq_qtrly_emplvl = (lq_month1_emplvl + lq_month2_emplvl + lq_month3_emplvl) / 3 ///
		if !missing(lq_month1_emplvl) & !missing(lq_month2_emplvl) & !missing(lq_month3_emplvl)
	
	gen qdate = yq(year, qtr)
	format qdate %tq

	* 3. Only keep variables of interest
    keep area_fips area_title qdate industry_code ///
         qtrly_estabs_count qtrly_emplvl total_qtrly_wages avg_wkly_wage ///
         lq_qtrly_estabs_count lq_qtrly_emplvl lq_total_qtrly_wages lq_avg_wkly_wage
		 
	* 4. Create log transformations for key QCEW outcomes
	gen lnAWW = ln(avg_wkly_wage) if avg_wkly_wage > 0 & !missing(avg_wkly_wage)
	gen lnEmp = ln(qtrly_emplvl) if qtrly_emplvl > 0 & !missing(qtrly_emplvl)
	gen lnEC = ln(qtrly_estabs_count) if qtrly_estabs_count > 0 & !missing(qtrly_estabs_count)
    
    * 5. Prepare for Append
	tostring industry_code, replace
    if `first_file' == 1 {
        save `master_qcew', replace
        local first_file = 0
    }
    else {
        append using `master_qcew'
        save `master_qcew', replace
    }
    
    display "`yr' Industry `ind' processed"
}
}

* Load the combined file
use `master_qcew', clear

rename area_fips county_fips
destring county_fips, replace force

* Final variable order for clarity
order county_fips qdate industry_code  
sort county_fips qdate

* Save cleaned dataset
save "$path/QCEW/qcew_cleaned.dta", replace

* Merge QCEW outcomes with the skeleton
use "$path/county_pair_list.dta", clear

* Join with the panel data
* joinby handles the "many-to-many" logic (County A in multiple pairs over multiple months)
joinby county_fips using "$path/QCEW/qcew_cleaned.dta"
keep county_fips countypair_id state treated qdate industry_code ///
     qtrly_estabs_count qtrly_emplvl total_qtrly_wages avg_wkly_wage ///
	 lnAWW lnEmp lnEC ///
     lq_qtrly_estabs_count lq_qtrly_emplvl lq_total_qtrly_wages lq_avg_wkly_wage

sort county_fips countypair_id qdate
save "$path/QCEW/QCEW_business_contig.dta", replace
