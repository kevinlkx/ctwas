% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ctwas_impute_expr_z.R
\name{impute_expr_z}
\alias{impute_expr_z}
\title{Impute expression z scores}
\usage{
impute_expr_z(
  z_snp,
  weight,
  ld_pgenfs = NULL,
  ld_R_dir = NULL,
  method = "lasso",
  outputdir = getwd(),
  outname = NULL,
  logfile = NULL,
  compress = T,
  harmonize_z = T,
  harmonize_wgt = T,
  strand_ambig_action_z = c("drop", "none", "recover"),
  recover_strand_ambig_wgt = T
)
}
\arguments{
\item{z_snp}{A data frame with two columns: "id", "A1", "A2", "z". giving the z scores for
snps. "A1" is effect allele. "A2" is the other allele. If `harmonize= False`, A1 and A2 are not required.}

\item{weight}{a string, pointing to a directory with the fusion/twas format of weights, or a .db file in predictdb format.}

\item{ld_pgenfs}{a character vector of .pgen or .bed files. One file for one
chromosome, in the order of 1 to 22. Therefore, the length of this vector
needs to be 22. If .pgen files are given, then .pvar and .psam are assumed
to present in the same directory. If .bed files are given, then .bim and
.fam files are assumed to present in the same directory.}

\item{method}{a string, blup/bslmm/lasso/top1/enet/best. This option is only used for fusion weights. 
"best" means the method giving the best cross #' validation R^2. Note that top1 uses only the weight 
with largest effect.}

\item{outputdir}{a string, the directory to store output}

\item{outname}{a string, the output name}

\item{logfile}{the log file, if NULL will print log info on screen}

\item{compress}{TRUE/FALSE. If TRUE, the imputed expression files are compressed}

\item{harmonize_z}{TRUE/FALSE. If TRUE, GWAS and eQTL genotype alleles are harmonized}

\item{harmonize_wgt}{TRUE/FALSE. If TRUE, GWAS and eQTL genotype alleles are harmonized}

\item{strand_ambig_action_z}{the action to take to harmonize strand ambiguous variants (A/T, G/C) between 
the z scores and LD reference. "drop" removes the ambiguous variant from the z scores. "none" treats the variant 
as unambiguous, flipping the z score to match the LD reference and then taking no additional action. "recover" 
imputes the sign of ambiguous z scores using unambiguous z scores and the LD reference and flips the z scores 
if there is a mismatch between the imputed sign and the observed sign of the z score. This option is computationally intensive}

\item{recover_strand_ambig_wgt}{TRUE/FALSE. If TRUE, a procedure is used to recover strand ambiguous variants. If FALSE, 
these variants are dropped from the prediction model. This procedure compares correlations between variants in the the 
LD reference and prediction models, and it can only be used with PredictDB format prediction models, which include this
information.}

\item{LD_R_dir}{a string, pointing to a directory containing all LD matrix files and variant information. Expects .RDS files which contain LD correlation matrices for a region/block.
For each RDS file, a file with same base name but ended with .Rvar needs to be present in the same folder. the .Rvar file has 5 required columns: "chrom", "id", "pos", "alt", "ref". 
If using PredictDB format weights and \code{scale_by_ld_variance=T}, a 6th column is also required: "variance", which is the variance of the each SNP.
The order of rows needs to match the order of rows in .RDS file.}
}
\description{
Impute expression z scores
}
