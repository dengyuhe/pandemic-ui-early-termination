* =============================================================================
* 00_master.do
* Early Termination of Pandemic Unemployment Insurance and Local Labor Market
* Recovery: A Comparison of Contiguous Counties Across State Borders
* Yuhe (Maggie) Deng, Brandeis University, 2026
*
* Runs the full pipeline in order. Set the repository root once below.
* =============================================================================

clear all
set more off
version 17

* ---- 1. Set this to the folder where you cloned the repository -------------
global root "/path/to/pandemic-ui-early-termination"

global path "$root/data"     // raw downloads + intermediate .dta files
global out  "$root/output"   // tables, figures, maps
global code "$root/code"

foreach d in contig_event_study robustness_test all_county maps ///
             balance_test descriptive industry county_clustering logs {
    capture mkdir "$out/`d'"
}
capture mkdir "$path/LAUS"
capture mkdir "$path/QCEW"

* ---- 2. Required packages (run once) ----------------------------------------
* ssc install ftools
* ssc install reghdfe
* ssc install estout
* ssc install coefplot
* ssc install listtab
* ssc install listtex
* ssc install maptile
* ssc install spmap
* maptile_install using "http://files.michaelstepner.com/geo_county2014.zip"

* ---- 3. Data setup ----------------------------------------------------------
do "$code/01_data_setup/population_setup.do"     // 2020 Census county population

* ---- 4. Samples (Figure 1, Figure B1) ----------------------------------------
do "$code/02_samples/all_county_sample.do"       // all counties + treated-state map
do "$code/02_samples/contig_sample.do"           // 502 contiguous border county pairs
do "$code/02_samples/pseudo_sample.do"           // 907 alternative comparison pairs
do "$code/02_samples/sample_maps.do"             // Figure 1 (a) and (b)

* ---- 5. Outcome panels --------------------------------------------------------
do "$code/01_data_setup/LAUS_data_setup.do"      // monthly LAUS panel (needs pair list)
do "$code/01_data_setup/QCEW_data_setup.do"      // quarterly QCEW panel (needs pair list)

* ---- 6. Descriptives and balance (Tables 1, 2, B1) ---------------------------
do "$code/03_descriptives/descriptive_table.do"
do "$code/03_descriptives/balance_test.do"
do "$code/03_descriptives/AC_balance_test.do"

* ---- 7. Main analysis (Figures 2-5, 10; Tables A1, A3-A5) --------------------
do "$code/04_main_analysis/contig_county_pair.do"        // Figures 2, 4, 5; Tables A1, A3, A4
do "$code/04_main_analysis/contig_qcew_all_industry.do"  // Figure 3
do "$code/04_main_analysis/mostly_affected_ind.do"       // Figure 10; Table A5

* ---- 8. Robustness and appendices (Figures 6-9, B2-B4; Tables A2, C1-C4) -----
do "$code/05_robustness/robustness_check.do"
do "$code/05_robustness/robustness_qcew_all_industry.do"
do "$code/05_robustness/all_county_sample_analysis.do"   // Appendix B
do "$code/05_robustness/county_clustering.do"            // Appendix C
