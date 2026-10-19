* Donut county pairs - Tier 2 (spillover test) *
** use the county adjacency file released by the Census Bureau
** https://www.census.gov/geographies/reference-files/time-series/geo/county-adjacency.2023.html#list-tab-1451423646
clear all
* Paths ($path, $out) are set in code/00_master.do

capture log close 
log using "$out/logs/pseudo county pair construction.log", replace

use "$path/county_pair_list.dta", clear

* Reshape it back to wide so one row is one pair (A and B side-by-side)
* Assuming 'treated' defines the sides (1=A, 0=B)
gen side = cond(treated == 1, "A", "B")
drop treated
reshape wide county_fips county state, i(countypair_id) j(side) string

* Rename for clarity: fipsA and fipsB are our 'bridge' counties
rename countypair_id parent_pair_id
rename county_fipsA fipsA
rename county_fipsB fipsB
tempfile bridge_pairs
save `bridge_pairs'

* Prepare a clean adjacency Master File
import delimited "$path/county_adjacency2023.txt", clear
rename countygeoid fips
rename neighborgeoid neighbor_fips
rename neighborname neighbor_county
drop if fips == neighbor_fips
keep fips neighbor_fips neighbor_county
tempfile adj_map
save `adj_map'

* Construct the Pseudo-Pairs
use `bridge_pairs', clear

* Create a county list sits on the state boreder
preserve
keep fipsA stateA
rename (fipsA stateA) (border_fips border_state)
tempfile borderA
save `borderA'
restore
keep fipsB stateB
rename (fipsB stateB) (border_fips border_state)
append using `borderA'
duplicates drop border_fips, force
tempfile border_counties       // all counties that are ON the real state border line
save `border_counties'

* Build a lookup of all directly adjacent C-F pairs 
*    (used to enforce "C and F must NOT border each other")
use `adj_map', clear
rename (fips neighbor_fips) (fipsC fipsF)
keep fipsC fipsF
gen adj_CF = 1
tempfile cf_adjacent
save `cf_adjacent'

* Get all neighbors of County A (call them Side C)
use `bridge_pairs', clear
rename fipsA fips
joinby fips using `adj_map'
rename (fips neighbor_fips neighbor_county) (fipsA fipsC nameC)

* Get all neighbors of County B (call them Side F)
rename fipsB fips
joinby fips using `adj_map'
rename (fips neighbor_fips neighbor_county) (fipsB fipsF nameF)

* Filtering Unwanted Pairs

* 1) Remove cases where the pseudo-pair is actually just the original pair
drop if fipsC == fipsB | fipsF == fipsA
* 2) Remove cases where Side C and Side F are the same county
drop if fipsC == fipsF
* 3) Remove immediately adjacent county pairs (C and F share a border)
joinby fipsC fipsF using `cf_adjacent', unmatched(master)
drop if adj_CF == 1
drop adj_CF _merge
* 4) Remove cases where pseudo-pair are both within same state
gen stateC = floor(fipsC/1000)
gen stateF = floor(fipsF/1000)
drop if stateC == stateF
* 5) Drop if C is not in the same state as A
drop if stateC != stateA
drop if stateF != stateB
* 6) Drop if C itself sits ON the real state border line
*    (C should be one step INSIDE state A, not a border county itself)
rename fipsC border_fips
joinby border_fips using `border_counties', unmatched(master)
rename (border_fips border_state) (fipsC stateC_check)
drop if stateC_check != .        // matched = C is a real border county, drop
drop stateC_check _merge
* 7) Drop if F itself sits ON the real state border line
*    (F should be one step INSIDE state B, not a border county itself)
rename fipsF border_fips
joinby border_fips using `border_counties', unmatched(master)
rename (border_fips border_state) (fipsF stateF_check)
drop if stateF_check != .        // matched = F is a real border county, drop
drop stateF_check

 * Create a pseudo-pair-id for the C-F pair, and drop duplicates
gen min_fips = min(fipsC, fipsF)
gen max_fips = max(fipsC, fipsF)
gen pseudo_pair_id = string(min_fips, "%05.0f") + "-" + string(max_fips, "%05.0f")
duplicates drop pseudo_pair_id, force

* Reshape to Long (2 rows per pseudo-pair, so that we could reuse the regression code)
* We use '1' for the C side (treated neighbor) and '2' for the F side (control neighbor)
rename (fipsC nameC) (county_fips1 county1)
rename (fipsF nameF) (county_fips2 county2)
keep county_fips1 county1 county_fips2 county2 pseudo_pair_id parent_pair_id
reshape long county_fips county, i(pseudo_pair_id) j(side)

gen state = floor(county_fips / 1000)
gen treated = (side == 1) // Side 1 corresponds to neighbors of the treated county

order county_fips pseudo_pair_id county state treated parent_pair_id

save "$path/pseudo_pair_list.dta", replace

log close
