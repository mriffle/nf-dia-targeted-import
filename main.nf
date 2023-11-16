#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Sub workflows
include { get_input_files } from "./workflows/get_input_files"
include { get_mzmls } from "./workflows/get_mzmls"
include { skyline_import } from "./workflows/skyline_import"
include { skyline_reports } from "./workflows/skyline_run_reports"
include { panorama_upload_results } from "./workflows/panorama_upload"
include { panorama_upload_mzmls } from "./workflows/panorama_upload"

// modules
include { SAVE_RUN_DETAILS } from "./modules/save_run_details"

//
// The main workflow
//
workflow {

    config_file = file(workflow.configFiles[1]) // the config file used

    // save details about this run
    SAVE_RUN_DETAILS()
    run_details_file = SAVE_RUN_DETAILS.out.run_details

    get_input_files()   // get input files
    get_mzmls()  // get wide windows mzmls

    // set up some convenience variables
    skyline_template_zipfile = get_input_files.out.skyline_template_zipfile
    mzml_ch = get_mzmls.out.mzml_ch
    skyr_file_ch = get_input_files.out.skyr_files

    // create Skyline document
    if(skyline_template_zipfile != null) {
        skyline_import(
            skyline_template_zipfile,
            mzml_ch
        )
    }

    final_skyline_file = skyline_import.out.skyline_results

    // run reports if requested
    skyline_reports_ch = null;
    if(params.skyline_skyr_file) {
        skyline_reports(
            final_skyline_file,
            skyr_file_ch
        )
        skyline_reports_ch = skyline_reports.out.skyline_report_files.flatten()
    } else {
        skyline_reports_ch = Channel.empty()
    }

    // upload results to Panorama
    if(params.panorama.upload) {
        panorama_upload_results(
            params.panorama.upload_url,
            final_skyline_file,
            mzml_ch,
            run_details_file,
            config_file,
            skyr_file_ch,
            skyline_reports_ch
        )
    }

}

//
// Used for email notifications
//
def email() {
    // Create the email text:
    def (subject, msg) = EmailTemplate.email(workflow, params)
    // Send the email:
    if (params.email) {
        sendMail(
            to: "$params.email",
            subject: subject,
            body: msg
        )
    }
}

//
// This is a dummy workflow for testing
//
workflow dummy {
    println "This is a workflow that doesn't do anything."
}

// Email notifications:
workflow.onComplete {
    try {
        email()
    } catch (Exception e) {
        println "Warning: Could not send completion email."
    }
}
