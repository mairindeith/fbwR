# Usin Example script for working with text information to create a list for siimulations
# Created by Alejandro Yanez on Sept 7 2023

### Step 1: Apply all steps developed by Mairin to add text information and use that data frame

fbw_df <- data.frame(
  # All 1's to show as an example
  fish_in_dam = rep(1, 12))

text_input <- "random[rnorm(mean = 0, sd = 1)]"

text_input <- gsub(x = text_input, pattern = "random[", replace = "", fixed = T)
text_input <- gsub(x = text_input, pattern = "]", replace = "", fixed = T)


text_final <- gsub(text_input, pattern = ")",
                   # the replacement text can created using `paste0()` and `nrow()` 
                   replace = paste0(", n = ", nrow(fbw_df), ")"), 
                   fixed = TRUE)

text_final # "rnorm(mean = 0, sd = 1, n = 12)"


survival_rates <- eval(parse(text = text_final)) 

library(dplyr)
fbw_df <- fbw_df %>%
  mutate(
    ### add the survival rate as a column
    survival_rate = survival_rates,
    ### multiply by the fish abundance in the dam
    surviving = fish_in_dam * survival_rate)




#!# return_list <- list(rep(ressim, nsim))
library(stringr)
library(dplyr)
library(reshape)

data.1  <- fbw_df
sims  <- c(0:4)
nsim       <- length(sims)

for(i in 1:length(sims)){
  data.1$fish_in_dam       <- fbw_df$fish_in_dam*2
  data.1$survival_rate     <- fbw_df$fish_in_dam*0.5
}

writeData(paste('fbw_df','s',i,'.csv',sep=''), data.1, append=F)}
return_list <- list((fbw_df, nsim))

