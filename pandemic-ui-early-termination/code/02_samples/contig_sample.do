clear all

* Paths ($path, $out) are set in code/00_master.do
* (no cd needed: all paths use the globals from 00_master.do)

* Construct County Pairs
* Import the Census Adjacency File
import delimited "$path/county_adjacency2023.txt", clear 

* The file has 4 columns: CountyName, CountyFIPS, NeighborName, NeighborFIPS
rename countyname county
rename countygeoid fips
rename neighborname neighbor_county
rename neighborgeoid neighbor_fips

* Fill in missing county names
replace county = county[_n-1] if missing(county) | county==""
replace fips   = fips[_n-1]   if missing(fips)

* Remove "self-adjacency" and cross-state filtering
drop if fips == neighbor_fips

* Extract state FIPS codes
gen state_fips = floor(fips/1000)
gen neighbor_state_fips = floor(neighbor_fips/1000)

* Exclude Alaska (2), Hawaii (15) and keep only cross-border pairs
drop if inlist(state_fips, 2, 15) | inlist(neighbor_state_fips, 2, 15)
drop if state_fips == neighbor_state_fips

* Create Unique Pair ID
gen min_fips = min(fips, neighbor_fips)
gen max_fips = max(fips, neighbor_fips)
egen pair_id = group(min_fips max_fips)
gen pair_id_str = string(min_fips, "%05.0f") + "-" + string(max_fips, "%05.0f")
duplicates drop pair_id, force

* Treatment states (excluding Alaska)
gen treat_state = inlist(state_fips, 1, 5, 12, 13, 16, 19, 28, 29, 30, 31) | ///
                  inlist(state_fips, 33, 38, 39, 40, 45, 46, 48, 49, 54, 56)
gen treat_neighbor = inlist(neighbor_state_fips, 1, 5, 12, 13, 16, 19, 28, 29, 30, 31) | ///
                     inlist(neighbor_state_fips, 33, 38, 39, 40, 45, 46, 48, 49, 54, 56)

* Keep ONLY border pairs (one side treated, one side control)
keep if (treat_state == 1 & treat_neighbor == 0) | (treat_state == 0 & treat_neighbor == 1)

* Prepare variables for reshape
rename fips fips1
rename neighbor_fips fips2
rename county county1
rename neighbor_county county2
rename state_fips state1
rename neighbor_state_fips state2
rename treat_state treated1
rename treat_neighbor treated2

* Reshape long: creates 2 rows per pair
reshape long fips county state treated, i(pair_id) j(side)

keep county fips state pair_id_str treated
order fips pair_id_str county state treated
rename fips county_fips
rename pair_id_str countypair_id

save "$path/county_pair_list.dta", replace
