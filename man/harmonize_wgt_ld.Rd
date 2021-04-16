% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ctwas_harmonize_data.R
\name{harmonize_wgt_ld}
\alias{harmonize_wgt_ld}
\title{Harmonize z scores from GWAS to match ld reference genotypes.
Flip signs when reverse complement matches.}
\usage{
harmonize_wgt_ld(wgt.matrix, snps, ld_snpinfo)
}
\arguments{
\item{wgt.matrix}{from FUSION weight .Rdat file}

\item{snps}{from FUSION weight .Rdat file
with columns "chrom", "id", "pos", "alt", "ref". The effect allele
for FUSION is alt.}
}
\value{
wgt.matrix and snps with alleles flipped to match
}
\description{
Harmonize z scores from GWAS to match ld reference genotypes.
Flip signs when reverse complement matches.
}