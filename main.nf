#!/usr/bin/env nextflow

def summary = [:]
summary['Pipeline Name']  = 'tetyper'
summary['Input']          = params.input
summary['Reference']      = params.ref
summary['SNP Profiles']   = params.snp_profiles
summary['Structural Variant Profiles']      = params.struct_profiles
summary['Flank Length']   = params.flank_len
summary['Output dir']     = params.outdir
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile


summary.each{ k, v -> println "${k}: ${v}" }

Channel
    .fromPath(params.input)
    .splitCsv(header:true, sep:'\t', quote:'"')
    .map{ row-> tuple(row.sample_id, file(row.read_1), file(row.read_2)) }
    .set { samples_tetyper_ch; }

Channel
    .fromPath(params.ref)
    .first()
    .set { ref_ch }

Channel
    .fromPath(params.snp_profiles)
    .first()
    .set { snp_profiles_ch }

Channel
    .fromPath(params.struct_profiles)
    .first()
    .set { struct_profiles_ch }

/*
 * TETyper
 */
process tetyper {
    tag "$sample_id"
    cpus 8
    conda 'tetyper'
    publishDir "${params.outdir}/per_sample_summaries", mode: 'copy', pattern: "*_summary.txt"
    errorStrategy 'ignore'
    
    input:
    set sample_id, file(read_1), file(read_2) from samples_tetyper_ch
    file(ref) from ref_ch
    file(snp_profiles) from snp_profiles_ch
    file(struct_profiles) from struct_profiles_ch
    val flank_len from params.flank_len

    output:
    file("*_summary.txt") into tetyper_summary_ch
    
    script:
    """
    TETyper.py \
      --threads 8 \
      --ref $ref \
      --snp_profiles $snp_profiles \
      --struct_profiles $struct_profiles \
      --flank_len $flank_len \
      --fq1 $read_1 \
      --fq2 $read_2 \
      --outprefix $sample_id
    echo -e "Sample_ID\n"${sample_id} | paste - ${sample_id}_summary.txt > ${sample_id}_summary_with_id.txt
    mv ${sample_id}_summary_with_id.txt ${sample_id}_summary.txt
    """
}

tetyper_summary_ch.collectFile(name: "summary.txt", storeDir: "${params.outdir}", keepHeader: true, sort: true)
