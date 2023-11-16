// Modules
include { SKYLINE_IMPORT_MZML } from "../modules/skyline"
include { SKYLINE_MERGE_RESULTS } from "../modules/skyline"

workflow skyline_import {

    take:
        skyline_template_zipfile
        mzml_file_ch

    emit:
        skyline_results

    main:

        // import spectra into skyline file
        SKYLINE_IMPORT_MZML(skyline_template_zipfile, mzml_file_ch)

        // merge sky files
        SKYLINE_MERGE_RESULTS(
            skyline_zipfile,
            SKYLINE_IMPORT_MZML.out.skyd_file.collect(),
            wide_mzml_file_ch.collect()
        )

        skyline_results = SKYLINE_MERGE_RESULTS.out.final_skyline_zipfile
}
