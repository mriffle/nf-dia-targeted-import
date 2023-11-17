// modules
include { PANORAMA_GET_RAW_FILE } from "../modules/panorama"
include { PANORAMA_GET_RAW_FILE_LIST } from "../modules/panorama"
include { MSCONVERT } from "../modules/msconvert"

workflow get_spectra_files {

    take:
        import_raw_directly

   emit:
        spectra_file_ch

    main:

        if(params.quant_spectra_dir.contains("https://")) {

            spectra_dirs_ch = Channel.from(params.quant_spectra_dir)
                                    .splitText()               // split multiline input
                                    .map{ it.trim() }          // removing surrounding whitespace
                                    .filter{ it.length() > 0 } // skip empty lines

            // get raw files from panorama
            PANORAMA_GET_RAW_FILE_LIST(spectra_dirs_ch, params.quant_spectra_glob)

            placeholder_ch = PANORAMA_GET_RAW_FILE_LIST.out.raw_file_placeholders.transpose()
            PANORAMA_GET_RAW_FILE(placeholder_ch)
            
            if(import_raw_directly) {
                spectra_file_ch = PANORAMA_GET_RAW_FILE.out.panorama_file
            } else {
                spectra_file_ch = MSCONVERT(
                    PANORAMA_GET_RAW_FILE.out.panorama_file,
                    params.msconvert.do_demultiplex,
                    params.msconvert.do_simasspectra
                )
            }

        } else {

            file_glob = params.quant_spectra_glob
            spectra_dir = file(params.quant_spectra_dir, checkIfExists: true)
            data_files = file("$spectra_dir/${file_glob}")

            if(data_files.size() < 1) {
                error "No files found for: $spectra_dir/${file_glob}"
            }

            mzml_files = data_files.findAll { it.name.endsWith('.mzML') }
            raw_files = data_files.findAll { it.name.endsWith('.raw') }

            if(mzml_files.size() < 1 && raw_files.size() < 1) {
                error "No raw or mzML files found in: $spectra_dir"
            }

            if(mzml_files.size() > 0 && raw_files.size() > 0) {
                error "Matched raw files and mzML files for: $spectra_dir/${file_glob}. Please choose a file matching string that will only match one or the other."
            }

            if(import_raw_directly && raw_files.size() < 1) {
                error "`import_raw_directly` is set to `true`, but no raw files found for: $spectra_dir/${file_glob}"
            }

            if(import_raw_directly) {
                spectra_file_ch = Channel.fromList(raw_files)
            } else {
                if(mzml_files.size() > 0) {
                        spectra_file_ch = Channel.fromList(mzml_files)
                } else {
                    spectra_file_ch = MSCONVERT(
                        Channel.fromList(raw_files),
                        params.msconvert.do_demultiplex,
                        params.msconvert.do_simasspectra
                    )
                }
            }
        }
}
