* Figure 1: maps of the contiguous border county-pair sample (a) and the
* alternative comparison county-pair sample (b).
* Paths are set in 00_master.do. Requires maptile + the county2014 geography.

clear all

foreach s in contig pseudo {

    if "`s'" == "contig" {
        use "$path/county_pair_list.dta", clear
        local legend_label "Contiguous Border County Pairs"
        local file "contig_sample"
    }
    else {
        use "$path/pseudo_pair_list.dta", clear
        local legend_label "Alternative Comparison County Pairs"
        local file "pseudo_sample"
    }

    keep county_fips
    duplicates drop county_fips, force
    rename county_fips county
    replace county = 46113 if county == 46102   // Oglala Lakota (SD) uses its pre-2015 code in county2014
    gen shade_me = 1

    tempfile to_shade
    save `to_shade'

    use "`c(sysdir_personal)'maptile_geographies/county2014_database.dta", clear
    merge 1:1 county using `to_shade', keep(1 3)
    replace shade_me = 0 if _merge == 1

    maptile shade_me, geo(county2014) ///
        cutvalues(0.5) ///
        fcolor(white gray) ///
        twopt( ///
            legend( ///
                order(3 "`legend_label'" 2 "Other Counties") ///
                position(7) ring(0) size(small) ///
                symxsize(small) symysize(small) ///
                region(fcolor(white) lcolor(black)) ///
            ) ///
            graphregion(fcolor(white)) ///
        )
    graph export "$out/maps/`file'.png", replace
}
