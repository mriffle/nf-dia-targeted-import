process SKYLINE_IMPORT_SPECTRA {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'process_high_memory'
    label 'process_short'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.23187-2243781'

    input:
        path skyline_zipfile
        path spectra_file

    output:
        path("*.skyd"), emit: skyd_file
        path("${spectra_file.baseName}.log"), emit: log_file

    script:
    """
    unzip ${skyline_zipfile}

    cp ${spectra_file} /tmp/${spectra_file}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --log-file="${spectra_file.baseName}.log" \
        --import-file="/tmp/${spectra_file}" \
    """
}

process SKYLINE_MERGE_RESULTS {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy'
    label 'process_high'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.23187-2243781'

    input:
        path skyline_zipfile
        path skyd_files
        val mzml_files

    output:
        path("${params.skyline_document_name}.sky.zip"), emit: final_skyline_zipfile
        path("skyline-merge.log"), emit: log

    script:
    import_files_params = "--import-file=${(mzml_files as List).collect{ "/tmp/" + file(it).name }.join(' --import-file=')}"
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --log-file="skyline-merge.log" \
        ${import_files_params} \
        --out="${params.skyline_document_name}.sky" \
        --save \
        --share-zip="${params.skyline_document_name}.sky.zip" \
        --share-type="complete"
    """
}

process SKYLINE_RUN_REPORTS {
    publishDir "${params.result_dir}/skyline/reports", failOnError: true, mode: 'copy'
    label 'process_high'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.23187-2243781'

    input:
        path skyline_zipfile
        path skyr_files

    output:
        path("*.report.tsv"), emit: skyline_report_files
        path("*.log"), emit: log

    script:
    """
    unzip ${skyline_zipfile}

    # add reports to skyline file
    for skyrfile in *.skyr; do
        wine SkylineCmd \
            --in="${skyline_zipfile.baseName}" \
            --log-file="skyline-import-\$skyrfile.log" \
            --report-add="\$skyrfile" \
            --save
    done

    # run the reports
    for xmlfile in ./*.skyr; do
        awk -F'"' '/<view name=/ { print \$2 }' "\$xmlfile" | while read reportname; do
            wine SkylineCmd \
                --in="${skyline_zipfile.baseName}" \
                --log-file="\$reportname.report-generation.log" \
                --report-name="\$reportname" \
                --report-file="./\$reportname.report.tsv" \
                --report-format="TSV"
        done
    done
    """
}
