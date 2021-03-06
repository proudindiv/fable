# Create evaluation environment for specials
new_specials_env <- function(..., parent_env = caller_env(), required_specials = NULL){
  child_env(parent_env, !!!dots_list(...)) %>%
    enclass(NULL, required_specials = required_specials)
}

tbl_xreg <- function(x){
  list(xreg = expr(tibble(!!!x)))
}

exprs_xreg <- function(x){
  x
}

no_xreg <- function(...){
  abort("Exogenous regressors are not supported for this model type.")
}