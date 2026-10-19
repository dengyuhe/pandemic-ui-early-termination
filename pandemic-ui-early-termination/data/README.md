# Data

All inputs are public. They are **not** stored in this repository because of their size; download them into this `data/` folder using the layout below.

| File / folder (inside `data/`) | Source | Used for |
|---|---|---|
| `LAUS/la.data.64.County.txt` | BLS Local Area Unemployment Statistics, flat file `la.data.64.County` from <https://download.bls.gov/pub/time.series/la/> | Monthly county unemployment, employment, labor force |
| `2020.q1-q4.by_industry/`, `2021.q1-q4.by_industry/` | BLS Quarterly Census of Employment and Wages, "CSVs By Industry" for 2020 and 2021, from <https://www.bls.gov/cew/downloadable-data-files.htm> (unzip as-is) | Quarterly establishments, employment, wages by NAICS sector |
| `PopulationEstimates.csv` | County population file with 2020 Census counts (`CENSUS_2020_POP`), USDA ERS County-level Data Sets, <https://www.ers.usda.gov/data-products/county-level-data-sets/> | Regression weights, population density |
| `county_adjacency2023.txt` | U.S. Census Bureau County Adjacency File, <https://www.census.gov/geographies/reference-files/time-series/geo/county-adjacency.html> | County list and border-pair construction |
| `2020_Gaz_counties_national.txt` | U.S. Census Bureau 2020 Gazetteer Files (counties), <https://www.census.gov/geographies/reference-files/time-series/geo/gazetteer-files.html> | Land area for population density |
| `urban_rural/nhgis0001_ds258_2020_county.csv` | IPUMS NHGIS, 2020 Census urban/rural population by county, <https://www.nhgis.org> (free account required) | Urban share in balance tests |

Intermediate files (`county_population_2020.dta`, `county_pair_list.dta`, `pseudo_pair_list.dta`, `LAUS/laus_cleaned.dta`, `QCEW/qcew_cleaned.dta`, etc.) are created by the scripts in `code/01_data_setup/` and `code/02_samples/`.

**Treatment definition.** A county is treated if its state terminated federal pandemic UI early in mid-2021. The list of state FIPS codes is in `code/02_samples/all_county_sample.do`.
