clear all

* Paths ($path, $out) are set in code/00_master.do
* (no cd needed: all paths use the globals from 00_master.do)

import delimited "$path/county_adjacency2023.txt", clear 
keep countygeoid
rename countygeoid county

duplicates drop county, force
gen state_fips = floor(county/1000)
gen treated = inlist(state_fips, 1, 5, 12, 13, 16, 19, 28, 29, 30, 31) | ///
                  inlist(state_fips, 33, 38, 39, 40, 45, 46, 48, 49, 54, 56)
				  
rename county county_fips
save "$path/all_county_list.dta", replace
rename county_fips county   // maptile expects the id to be called `county`

drop if treated == 0 
gen shade_me = 1

replace county = 46113 if county == 46102

tempfile to_shade
save `to_shade'

use "`c(sysdir_personal)'maptile_geographies/county2014_database.dta", clear

merge 1:1 county using `to_shade'
replace shade_me = 0 if _merge == 1  // County exists in US but not in your pairs

maptile shade_me, geo(county2014) ///
    cutvalues(0.5) ///              // Splits data at 0.5 (0 goes to bin 1, 1 goes to bin 2)
    fcolor(white gray) ///         // Bin 1 (zeros) = white; Bin 2 (ones) = black
    twopt( ///
        legend( ///
            order(3 "All County treated ") ///
            position(7) ///
            ring(0) ///
            size(small) ///
            symxsize(small) ///
            symysize(small) ///
            region(fcolor(white) lcolor(black)) ///
        ) ///
        graphregion(fcolor(white)) ///
    )
graph export "$out/maps/all_county_sample.png", replace
