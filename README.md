# bulletr
Analyze bullet striations using nonparametric methods

[![CRAN Status](http://www.r-pkg.org/badges/version/bulletr)](https://cran.r-project.org/package=bulletr) [![CRAN RStudio mirror downloads](http://cranlogs.r-pkg.org/badges/bulletr)](http://www.r-pkg.org/pkg/bulletr) 

<!--[![Travis-CI Build Status](https://travis-ci.org/haleyjeppson/ggmosaic.svg?branch=master)](https://travis-ci.org/haleyjeppson/ggmosaic)-->


## HOW-TO

1. Load Libraries
    
    ```
    library(dplyr)
    library(readr)
    library(bulletr)
    library(randomForest)
    ```
  
2. Read in the bullet file data, and convert to the appropriate x3p format (if necessary):

    ```
    h44_g1 <- read_dat("~/Downloads/H44-G-1.dat")
    h44_gx1 <- read_dat("~/Downloads/H44-GX-1.dat")
    ```

3. Get the ideal cross sections


    ```
    cc_g1 <- bulletCheckCrossCut(path = "~/Downloads/H44-G-1.dat", bullet = h44_g1)
    cc_gx1 <- bulletCheckCrossCut(path = "~/Downloads/H44-GX-1.dat", bullet = h44_gx1)

    ccdata_g1 <- get_crosscut(bullet = h44_g1, x = cc_g1) 
    ccdata_gx1 <- get_crosscut(bullet = h44_gx1, x = cc_gx1)
    ```
    
4. Get the groove locations

    ```
    grooves_g1 <- get_grooves(bullet = ccdata_g1)
    grooves_gx1 <- get_grooves(bullet = ccdata_gx1)
    ```
    
6. Process the bullets to extract LOESS residuals

    ```
    g1_processed <- processBullets(bullet = ccdata_g1,
                               name = "g1",
                               x = ccdata_g1$x[1],
                               span = 0.75,
                               grooves = grooves_g1$groove)

    gx1_processed <- processBullets(bullet = ccdata_gx1,
                                   name = "gx1",
                                   x = ccdata_gx1$x[1],
                                   span = 0.75,
                                   grooves = grooves_gx1$groove)
    ```
    
7. Smooth the processed bullet profiles

    ```
    all_smoothed <- g1_processed %>% 
        rbind(gx1_processed) %>%
        bulletSmooth(span = 0.03) %>%
        filter(!is.na(l30))
    ```
   
8. Detect peaks and valleys in the aligned signatures

    ```
    res <- bulletGetMaxCMS(filter(all_smoothed, bullet == "g1"), 
                           filter(all_smoothed, bullet == "gx1"), 
                           column = "l30", 
                           span = 25)
    ```
    
9. Extract Features

    ```
    lofX <- res$bullets
    b12 <- unique(lofX$bullet)

    subLOFx1 <- subset(lofX, bullet==b12[1])
    subLOFx2 <- subset(lofX, bullet==b12[2]) 

    ys <- dplyr::intersect(round(subLOFx1$y, digits = 3), round(subLOFx2$y, digits = 3))

    idx1 <- which(round(subLOFx1$y, digits = 3) %in% ys)
    idx2 <- which(round(subLOFx2$y, digits = 3) %in% ys)

    g1_inc_x <- h44_g1$header.info$profile_inc
    
    distr.dist <- sqrt(mean(((subLOFx1$val[idx1] - subLOFx2$val[idx2]) * g1_inc_x / 1000)^2, na.rm=TRUE))
    distr.sd <- sd(subLOFx1$val * g1_inc_x / 1000, na.rm=TRUE) + sd(subLOFx2$val * g1_inc_x / 1000, na.rm=TRUE)

    km <- which(res$lines$match)
    knm <- which(!res$lines$match)
    if (length(km) == 0) km <- c(length(knm)+1,0)
    if (length(knm) == 0) knm <- c(length(km)+1,0)

    signature.length <- min(nrow(subLOFx1), nrow(subLOFx2))

    doublesmoothed <- lofX %>%
      group_by(y) %>%
      mutate(avgl30 = mean(l30, na.rm = TRUE)) %>%
      ungroup() %>%
      mutate(smoothavgl30 = smoothloess(x = y, y = avgl30, span = 0.3),
             l50 = l30 - smoothavgl30)

    final_doublesmoothed <- doublesmoothed %>%
      filter(round(y, digits = 3) %in% ys)

    rough_cor <- cor(na.omit(final_doublesmoothed$l50[final_doublesmoothed$bullet == b12[1]]), 
                     na.omit(final_doublesmoothed$l50[final_doublesmoothed$bullet == b12[2]]),
                     use = "pairwise.complete.obs")

    ccf_temp <- c(ccf=res$ccf, rough_cor = rough_cor, lag=res$lag / 1000, 
      D=distr.dist, 
      sd_D = distr.sd,
      b1=b12[1], b2=b12[2],
      signature_length = signature.length * g1_inc_x / 1000,
      overlap = length(ys) / signature.length,
      matches = sum(res$lines$match) * (1000 / g1_inc_x) / length(ys),
      mismatches = sum(!res$lines$match) * 1000 / abs(diff(range(c(subLOFx1$y, subLOFx2$y)))),
      cms = res$maxCMS * (1000 / g1_inc_x) / length(ys),
      cms2 = bulletr::maxCMS(subset(res$lines, type==1 | is.na(type))$match) * (1000 / g1_inc_x) / length(ys),
      non_cms = bulletr::maxCMS(!res$lines$match) * 1000 / abs(diff(range(c(subLOFx1$y, subLOFx2$y)))),
      left_cms = max(knm[1] - km[1], 0) * (1000 / g1_inc_x) / length(ys),
      right_cms = max(km[length(km)] - knm[length(knm)],0) * (1000 / g1_inc_x) / length(ys),
      left_noncms = max(km[1] - knm[1], 0) * 1000 / abs(diff(range(c(subLOFx1$y, subLOFx2$y)))),
      right_noncms = max(knm[length(knm)]-km[length(km)],0) * 1000 / abs(diff(range(c(subLOFx1$y, subLOFx2$y)))),
      sum_peaks = sum(abs(res$lines$heights[res$lines$match])) * (1000 / g1_inc_x) / length(ys)
    )

    ccf <- t(as.data.frame(ccf_temp)) %>%
      as.data.frame() %>%
      dplyr::select(profile1_id = b1, profile2_id = b2, ccf, rough_cor, lag, D, sd_D, signature_length, overlap,
                    matches, mismatches, cms, non_cms, sum_peaks)
    ccf[,-2] <- lapply(ccf[,-(1:2)], function(x) { as.numeric(as.character(x)) })
    ```
    
10. Get Predicted Probability of Match

    ```
    ccf$forest <- predict(rtrees, newdata = CCFs_withlands, type = "prob")[,2]
    ```
    
