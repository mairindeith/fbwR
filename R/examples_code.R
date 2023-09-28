# Overall goal:

# 1:  Use a list of dataframes in runFBW() instead of a single dataframe
# 2:  For each step of FBW, (e.g., distributeFishDaily()), use an apply() function
#     on the list from step 1

ressim <- data.frame(
  x = c(12,14),
  y = c(1,2))

# runFBW() uses ressim, template dataframe that we add on to 

x <- list(ressim)
example_list <- rep(list(x), 10)
example_list

# Repeating a data frame inside a list
example_list <- rep(list(ressim), 10)


# Applying a function to each element of the list 
lapply(example_list, function(X) {
  X$y + 2})







nsim <- 5
for (i in 1:nsim) {
  example_list <- append(example_list, ressim)
}

# Try it out, to add uncertainty
lapply(example_list, function(X) {
  X$y * rnorm(n=1)})

lapply(example_list, function(X) {
  distributeFishDaily(X, param_list = param_list)}) 


# From runFBW():
fish_daily <- fbwR::distributeFishDaily(ressim,
                                        param_list = param_list, verbose = verbose)

# Instead do:
fish_daily <- lapply(example_list, function(X){
  fbwR::distributeFishDaily(X, param_list = param_list, verbose = verbose)})