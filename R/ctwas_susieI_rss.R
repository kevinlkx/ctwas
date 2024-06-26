#' Iteratively run susie and estimate parameters - RSS version
#'
#' @param zdf A data frame with three columns: "id", "z", "type".
#' This data frame gives the the z scores for SNPs and genes, denoted in "type".
#' The "type" column can also be use to specify multiple sets of weights
#'
#' @param regionlist a list object indexing regions, variants and genes. The output of
#' \code{index_regions}
#'
#' @param ld_exprvarfs A character vector of `.exprvar` files. One file for
#' one chromosome, in the order of 1 to 22. Therefore, the length of this vector
#' needs to be 22. `.exprvar` files are tab delimited text files, with columns:
#' \describe{
#'   \item{chrom}{chromosome number, numeric}
#'   \item{p0}{gene boundary position, the smaller value}
#'   \item{p1}{gene boundary position, the larger value}
#'   \item{id}{gene id}
#' }
#' Its rows should be in the same order as the columns for corresponding `.expr`
#' files.
#'
#' @param ld_pgenfs A character vector of .pgen or .bed files. One file for one
#' chromosome, in the order of 1 to 22. Therefore, the length of this vector
#' needs to be 22. If .pgen files are given, then .pvar and .psam are assumed
#' to present in the same directory. If .bed files are given, then .bim and
#' .fam files are assumed to present in the same directory.
#'
#' @param ld_Rfs a vector of paths to the LD matrices
#'
#' @param niter the number of iterations of the E-M algorithm to perform
#'
#' @param L the number of effects for susie
#'
#' @param z_ld_weight the z_ld_weight parameter for susie_rss
#'
#' @param group_prior a vector of two prior inclusion probabilities for SNPs and genes. This is ignored
#' if \code{estimate_group_prior = T}
#'
#' @param group_prior_var a vector of two prior variances for SNPs and gene effects. This is ignored
#' if \code{estimate_group_prior_var = T}
#'
#' @param estimate_group_prior TRUE/FALSE. If TRUE, the prior inclusion probabilities for SNPs and genes are estimated
#' using the data. If FALSE, \code{group_prior} must be specified
#'
#' @param estimate_group_prior_var TRUE/FALSE. If TRUE, the prior variances for SNPs and genes are estimated
#' using the data. If FALSE, \code{group_prior_var} must be specified
#'
#' @param use_null_weight TRUE/FALSE. If TRUE, allow for a probability of no effect in susie
#'
#' @param coverage A number between 0 and 1 specifying the \dQuote{coverage} of the estimated confidence sets
#'
#' @param ncore The number of cores used to parallelize susie over regions
#'
#' @param outputdir a string, the directory to store output
#'
#' @param outname a string, the output name
#'
#' @param report_parameters TRUE/FALSE. If TRUE, estimated parameters are reported at the end of iteration
#'
#' @importFrom logging loginfo
#' @importFrom foreach %dopar% foreach
#'
susieI_rss <- function(zdf,
                       regionlist,
                       ld_exprvarfs,
                       ld_exprfs = NULL,
                       ld_pgenfs = NULL,
                       ld_Rfs = NULL,
                       niter = 20,
                       L= 1,
                       z_ld_weight = 0,
                       group_prior = NULL,
                       group_prior_var = NULL,
                       estimate_group_prior = T,
                       estimate_group_prior_var = T,
                       use_null_weight = T,
                       coverage = 0.95,
                       ncore = 1,
                       outputdir = getwd(),
                       outname = NULL,
                       report_parameters=T
                      ) {

  outname <- file.path(outputdir, outname)

  #ld_exprvarfs <- sapply(ld_exprfs, prep_exprvar)

  if (is.null(ld_pgenfs) & is.null(ld_Rfs)){
    stop("Error: need to provide either .pgen file or ld_R file")
  }

  if (!is.null(ld_pgenfs)){
    ld_pvarfs <- sapply(ld_pgenfs, prep_pvar, outputdir = outputdir)
  }

  K <- 2

  group_prior_rec <- matrix(, nrow = K , ncol =  niter)
  group_prior_var_rec <- matrix(, nrow = K , ncol =  niter)

  prior.gene <- group_prior[1]
  prior.SNP <-  group_prior[2]

  V.gene <- group_prior_var[1]
  V.SNP <- group_prior_var[2]

  for (iter in 1:niter){

    loginfo("run iteration %s", iter)

    snp.rpiplist <- list()
    gene.rpiplist <- list()

    cl <- parallel::makeCluster(ncore, outfile = "")
    doParallel::registerDoParallel(cl)

    corelist <- region2core(regionlist, ncore)

    outdf <- foreach (core = 1:length(corelist), .combine = "rbind",
                      .packages = "ctwas") %dopar% {
      # outdf <- NULL
      # for (core in 2:10) {

          outdf.core.list <- list()

          # run susie for each region
          regs <- corelist[[core]]
          for (reg in 1: nrow(regs)) {
          # for (reg in 1:2){
            b <- regs[reg, "b"]
            rn <- regs[reg, "rn"]

            gidx <- regionlist[[b]][[rn]][["gidx"]]
            sidx <- regionlist[[b]][[rn]][["sidx"]]
            gid <- regionlist[[b]][[rn]][["gid"]]
            sid <- regionlist[[b]][[rn]][["sid"]]

            p <- length(gidx) + length(sidx)

            if (is.null(prior.gene) | is.null(prior.SNP)){
              prior <- c(rep(1/p, length(gidx)),
                         rep(1/p, length(sidx)))
            } else {
              prior <- c(rep(prior.gene, length(gidx)),
                         rep(prior.SNP, length(sidx)))
            }

            if (is.null(V.gene) | is.null(V.SNP)){
              V <- matrix(rep(50, L * p), nrow = L)
              # following the default in susieR::susie_rss
            } else{
              V <- c(rep(V.gene, length(gidx)), rep(V.SNP, length(sidx)))
              V <- matrix(rep(V, each = L), nrow=L)
            }

            if (isTRUE(use_null_weight)){
              nw <- max(0, 1 - sum(prior))
              prior <- prior/(1-nw)
            } else {
              nw <- NULL
            }

            z.g <- zdf[match(gid, zdf$id), ][["z"]]
            z.s <- zdf[match(sid, zdf$id), ][["z"]]
            z <- c(z.g, z.s)


            if (!(is.null(ld_pgenfs))){
              # prepare LD genotype data
              ld_pgen <- prep_pgen(pgenf = ld_pgenfs[b], ld_pvarfs[b])

              X.g <- read_expr(ld_exprfs[b], variantidx = gidx)
              X.s <- read_pgen(ld_pgen, variantidx = sidx)
              X <- cbind(X.g, X.s)
              R <- Rfast::cora(X)
            } else {
              # prepare R matrix
              if (!("regRDS" %in% names(regionlist[[b]][[rn]]))){
                stop("R matrix info not available for region", b, ",", rn)
              }

              regRDS <- regionlist[[b]][[rn]][["regRDS"]]

              if (is.null(regionlist[[b]][[rn]][["R_s_file"]])){
                R_snp <- lapply(regRDS, readRDS)
                R_snp <- suppressWarnings({as.matrix(Matrix::bdiag(R_snp))})
                R_snp <- R_snp[sidx, sidx, drop = F]
              } else {
                R_snp <- readRDS(regionlist[[b]][[rn]][["R_s_file"]])
              }
              R_snp_gene <- readRDS(regionlist[[b]][[rn]][["R_sg_file"]])
              R_snp_gene <- R_snp_gene[sidx, , drop = F]
              R_gene <- readRDS(regionlist[[b]][[rn]][["R_g_file"]])

              # gene first then SNPs
              R <- rbind(cbind(R_gene, t(R_snp_gene)),
                         cbind(R_snp_gene, R_snp))
            }

            # in susie, prior_variance is under standardized scale (if performed)
            susieres <- susie_rss(z, R,
                                  z_ld_weight = z_ld_weight,
                                  L = L, prior_weights = prior,
                                  null_weight = nw,
                                  prior_variance = V,
                                  estimate_prior_variance = F,
                                  coverage = coverage)

            geneinfo <- read_exprvar(ld_exprvarfs[b])

            if (!is.null(ld_pgenfs)){
              snpinfo <-  read_pvar(ld_pvarfs[b])
            } else {
              snpinfo <- do.call(rbind, lapply(regRDS, read_ld_Rvar_RDS))
            }

            outdf.reg <- anno_susie(susieres,
                                    geneinfo,
                                    snpinfo,
                                    gidx,
                                    sidx,
                                    b, rn)

            outdf.core.list[[reg]] <- outdf.reg
          }

          outdf.core <- do.call(rbind, outdf.core.list)
          outdf.core
          # outdf <- rbind(outdf, outdf.core)
    }

    if (isTRUE(estimate_group_prior)){
      prior.SNP <- mean(outdf[outdf[ , "type"] == "SNP", "susie_pip"])
      prior.gene <- mean(outdf[outdf[ , "type"] == "gene", "susie_pip"])
      group_prior_rec[, iter] <- c(prior.gene, prior.SNP)
    }

    if (report_parameters){
      loginfo("After iteration %s, gene prior %s:, SNP prior:%s",
              iter, prior.gene, prior.SNP)
    }

    if (isTRUE(estimate_group_prior_var)){
      outdf.g <- outdf[outdf[ , "type"] == "gene", ]
      outdf.s <- outdf[outdf[ , "type"] == "SNP", ]

      # in susie, mu2 is under standardized scale (if performed)
      # e.g. X = matrix(rnorm(n*p),nrow=n,ncol=p)
      # y = X %*% beta + rnorm(n)
      # res = susie(X,y,L=10)
      # X2 = 5*X
      # res2 = susie(X2,y,L=10)
      # res$mu2 is identifical to res2$mu2 but coefficients are on diff scale.
      V.gene <- sum(outdf.g$susie_pip * outdf.g$mu2)/sum(outdf.g$susie_pip)
      V.SNP <- sum(outdf.s$susie_pip * outdf.s$mu2)/sum(outdf.s$susie_pip)
      group_prior_var_rec[, iter] <- c(V.gene, V.SNP)
    }

    save(group_prior_rec, group_prior_var_rec,
         file = paste0(outname, ".susieIrssres.Rd"))
    data.table::fwrite(outdf, file= paste0(outname, ".susieIrss.txt"),
                       sep="\t", quote = F)

    parallel::stopCluster(cl)
  }


  list("group_prior"= c(prior.gene, prior.SNP),
       "group_prior_var" = c(V.gene, V.SNP))

}


