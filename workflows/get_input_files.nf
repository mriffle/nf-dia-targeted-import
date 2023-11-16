// modules
include { PANORAMA_GET_FASTA } from "../modules/panorama"
include { PANORAMA_GET_SPECTRAL_LIBRARY } from "../modules/panorama"
include { PANORAMA_GET_SKYLINE_TEMPLATE } from "../modules/panorama"
include { PANORAMA_GET_SKYR_FILE } from "../modules/panorama"

workflow get_input_files {

   emit:
        skyline_template_zipfile
        skyr_files

    main:

        assert params.skyline_template_file != null, "Parameter `skyline_template_file` is required."

        if(params.skyline_template_file.startsWith("https://")) {
            PANORAMA_GET_SKYLINE_TEMPLATE(params.skyline_template_file)
            skyline_template_zipfile = PANORAMA_GET_SKYLINE_TEMPLATE.out.panorama_file
        } else {
            skyline_template_zipfile = file(params.skyline_template_file, checkIfExists: true)
        }
            
        if(params.skyline_skyr_file != null) {
            if(params.skyline_skyr_file.trim().startsWith("https://")) {
                
                // get file(s) from Panorama
                skyr_location_ch = Channel.from(params.skyline_skyr_file)
                                        .splitText()               // split multiline input
                                        .map{ it.trim() }          // removing surrounding whitespace
                                        .filter{ it.length() > 0 } // skip empty lines

                // get raw files from panorama
                PANORAMA_GET_SKYR_FILE(skyr_location_ch)
                skyr_files = PANORAMA_GET_SKYR_FILE.out.panorama_file

            } else {
                // files are local
                skyr_files = Channel.from(params.skyline_skyr_file)
                                        .splitText()               // split multiline input
                                        .map{ it.trim() }          // removing surrounding whitespace
                                        .filter{ it.length() > 0 } // skip empty lines
                                        .map { path ->             // convert to files, check all exist
                                            def fileObj = file(path)
                                            if (!fileObj.exists()) {
                                                error "File does not exist: $path"
                                            }
                                            return fileObj
                                        }

            }
        } else {
            skyr_files = Channel.empty()
        }

}
