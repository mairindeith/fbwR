#' Calculate distribution of fish through outlets
#' @description First distributes fish bearing flow through available outlets in
#' a dam, including fish passage structure calculations. Then, using the 
#' proportion of fish-bearing flow, calculates the distribution of fish passing
#' the dam according to route effectiveness and fish-bearing flows.
#' @param fish_postDPE Dataframe containing daily estimates of various 
#' hydrological data (e.g., ResSim estimates of flow) in addition to the prop.
#' of annually approaching fish who are actually in the dam.
#' This dataframe must include a column, `approaching_daily_postDPE`, the daily
#' proportion of fish that pass the dam (after accounting for dam passage 
#' efficiency)
#' @param param_list A list including at least the following named objects: 
#'   `alt_desc`, with named entry "collector", the fish passage structure name
#'   `route_dpe`, a dataframe including columns `elev`, `baseline_dpe`, and any 
#' number of other columns to the right of these that can be used to look up DPE
#' at various pool elevations)
#'   `fps_max_elev`: a single numeric value, the maximum pool elevation at 
#'   which the fish passage structure can operate)
#'   `fps_bottom_elev`: a single numeric value, the minimum pool elevation (in
#'   feet) at which the fish passage structure can operate
#'   `dpe_x_position`: a single numeric value referencing which column of the 
#'   DPE lookup table (provided in `param_list`). Used to determine how many
#' which column of `route_dpe` AFTER the baseline should be selected?
#' @param verbose (Optional) Logical argument indicating whether 
#' intermediate columns (proportion of spill in each outlet: `pB.spill`, 
#' `pB.turb`, `pB.RO`, and `pB.FPS`; fish-bearing flow through each 
#' outlet: `B.spill`, `B.turb`, `B.RO`, and `B.FPS`; and route
#' effectiveness for each outlet: `RE.spill`, `RE.turb`, `RE.RO`, and
#' `RE.FPS`). Defaults to FALSE, in which case only the proportion of fish 
#' through each outlet is returned in the output dataframe.
#' 
#' @return A dataframe with all of the columns of the input table, 
#' `fish_postDPE`, with the addition of some number of columns (depending on the
#' `verbose` argument). At least the flow rate through the fish passage
#' structure, `FPS_flow`, and the proportion of fish passing through each 
#' outlet in the dam is returned. Optionally, if `verbose = TRUE`, 
#' intermediate variables like the proportion of flow through each outlet, route
#' effectiveness, and fish-bearing flow are output.
#' 
#' @importFrom dplyr %>%
#' @importFrom dplyr mutate
#' @importFrom dplyr select
#' @importFrom rlang .data
#' @importFrom lubridate day
#' @importFrom lubridate month
#' @importFrom lubridate year
#' 
#' @export

distributeFish_outlets <- function(fish_postDPE, param_list, 
  verbose = FALSE) {
  fps <- as.character(param_list$alt_desc[["collector"]]) # what kind of FPS?
  # Pull out the FPS route specs
  fps_specs <- param_list$route_specs[
    which(rownames(param_list$route_specs) == "FPS"), ]
  if (fps != "NONE") { # calculate FPS_flow
    # Set min and max elevation for FPS
    # Max. elevation applies only for the FPS, so it is defined in the alt desc.
    if (is.na(param_list$alt_desc[["fps_max_elev"]])){ # if no max:
      param_list$alt_desc[["fps_max_elev"]] <- Inf
    }
    # All other FPS related parameters are defined in route_specs
    if (is.na(fps_specs$bottom_elev)) {
      # if no min set parameter value to - inf
      fps_specs$bottom_elev <- -Inf
    }
    if (is.na(fps_specs$max_flow)) {
      # if no max. set to inf
      fps_specs$max_flow <- Inf
    }
    # Overwrite param_list values
    # Determine which elevations are within the upper and lower boundaries 
    fish_to_passFPS <- fish_postDPE %>%
      dplyr::mutate(
        # Binary indicator of whether elevation is sufficient
        adequate_elev = case_when(
          # Only accessible if above bottom_elev and above max - NON inclusive
          .data$elev > fps_specs$bottom_elev &
            .data$elev < param_list$alt_desc[["fps_max_elev"]] ~ 1,
          TRUE ~ 0
        )
      )
    if (fps == "FSS") {
      # It is assumed that FSS will screen water from upper part of forebay
      #   FSS may not be able to reach full capacity b/x of water being
      #   withdrawn for temperature control
      # FSO is assumed to operate regardless of temperature split.
      # If temperature controls are active, account for this:
      if (tolower(param_list$alt_desc[["use_temp_dist"]]) == "y") {
        # if(is.null(param_list$water_year_types) | is.null(temp_splits)){
        #   stop('If using an FSS fish passage with temperature control, you must also supply "year_water_types", a data frame of water type by year in the ResSim data; and "temp_splits", a dataframe containing columns date, proportion of water taken from the FSS during cool/wet water years, the proportion taken during normal years, and the proportion taken during hot/dry years. ')
        # }
        # If there is an FSS and temperature distribution is active, calc.
        #   the proportion of flow to be used for temperature control
        cat('...using temperature split, calculating...\n')
        temp_split <- calcTempSplit(fish_postDPE,
          water_year_types = param_list$water_year_types,
          temp_dist_df = param_list$temp_dist)
        fish_to_passFPS <- fish_to_passFPS %>%
        # To calculate the flow through the FPS:
        # First, 0 if elevation is inadequate (i.e., adequate_elev==0)
        # Take the minimum of qmax and FLOW-OUT for that day * (1-TEMP-SPLIT)
          dplyr::mutate(
            temp_split = as.numeric(temp_split$split),
            FPS_flow = .data$adequate_elev * pmin(fps_specs$max_flow,
            (.data$outflow_flow * (1 - temp_split))))
        if (!verbose) {
          fish_to_passFPS <- fish_to_passFPS %>%
            dplyr::select(-c(.data$adequate_elev, .data$temp_split))
        }
      } else {
        # otherwise: minimum of max flow and PH+RO flows (if elevation is adequate)
        fish_to_passFPS <- fish_to_passFPS %>%
          dplyr::mutate(
            temp_split = NA,
            FPS_flow = .data$adequate_elev *
            # Multiply the binary adequate_elev by the combined turb + RO flow
            pmin(fps_specs$max_flow, (.data$turb_flow + .data$RO_flow)))
        if (!verbose) {
          fish_to_passFPS <- fish_to_passFPS %>%
            dplyr::select(-c(.data$adequate_elev, .data$temp_split))
        }
      }
    } else if(fps == "FSC") {
      fish_to_passFPS <- fish_to_passFPS %>% 
        dplyr::mutate(
          temp_split = NA,
          # Maximum flow so long as elevation is enough
          FPS_flow = fps_specs$max_flow * .data$adequate_elev)
        if (!verbose) {
          fish_to_passFPS <- fish_to_passFPS %>%
            dplyr::select(-c(.data$adequate_elev, .data$temp_split))
        }
    } else if (fps == "FISH WEIR") {
      # First check that the weir date is appropriate - issue warning if dates missing
      if (all(dim(param_list$alt_desc[["weir_start_date"]]) == c(0, 0)) |
        all(dim(param_list$alt_desc[["weir_end_date"]]) == c(0, 0))) {
        warning("Weir start date and/or end date are missing, assuming weir active all year.")
        fish_to_passFPS <- fish_to_passFPS %>%
          dplyr::mutate(
            # weir_boolean indicates if the weir is active
            #   In this case, because no dates given, assume active
            temp_split = NA,
            weir_boolean = 1,
            # Perform a parallel minimum
            FPS_flow = pmin(fps_specs$max_flow, .data$spill) *
              .data$weir_boolean * .data$adequate_elev
          )
        if (!verbose) {
          fish_to_passFPS <- fish_to_passFPS %>%
            dplyr::select(-c(.data$adequate_elev, .data$weir_boolean,
              .data$temp_split))
        }
      } else {
        startdate <- tryCatch({
          # Enforce 2020 to ensure that leap year is included
          as.Date(paste0(param_list$alt_desc[["weir_start_date"]], "-2020"),
            "%d-%m-%Y")}, error = function(e) {
            stop("Weir start date must be a date in %d-%m format (e.g., 25-05 for the 25th of May)\n")
        })
        enddate <- tryCatch({
          as.Date(paste0(param_list$alt_desc[["weir_end_date"]], "-2020"),
            "%d-%m-%Y")}, error = function(e) {
          stop("Weir end date must be a date in %d-%m format (e.g., 25-05 for the 25th of May)\n")
        })
        # If the start date falls "after" the end date, push the start date backwards an extra year 
        if (lubridate::month(startdate) >= lubridate::month(enddate) ||
          (lubridate::day(startdate) > lubridate::day(enddate) &&
            lubridate::month(startdate) == lubridate::month(enddate))
          ) {
          lubridate::year(startdate) <- lubridate::year(startdate) - 1
        }
        # daily_weir is a sequence of dates during which the weir is active
        daily_weir <- seq(from = startdate, to = enddate, by = "day")
        # Convert to month-date format
        daily_weir_md <- paste0(lubridate::month(daily_weir), "-", 
          lubridate::day(daily_weir))
        # Add binary weir column
        fish_to_passFPS <- fish_to_passFPS %>%
          dplyr::mutate(
            MoDay = paste0(lubridate::month(.data$Date), "-", day(.data$Date)),
            # Here, weir_boolean = 1 if in the active date range, 0 if not
            weir_boolean = ifelse(.data$MoDay %in% daily_weir_md, 1, 0),
            # Take the minimum of qMax or spillway flow,
            # multiplied by weir date (0/1) and adequate elevation (0/1)
            FPS_flow = pmin(fps_specs$max_flow, .data$spill) *
              .data$weir_boolean * .data$adequate_elev
          )
        if (!verbose) {
          fish_to_passFPS <- fish_to_passFPS %>%
            dplyr::select(-c(.data$adequate_elev, .data$weir_boolean))
        }
      }
    } else if (fps == "FSO") {
      fish_to_passFPS <- fish_to_passFPS %>% 
        dplyr::mutate(
          FPS_flow = pmin(fps_specs$max_flow, .data$outflow_flow) *
            .data$adequate_elev)
        if (!verbose) {
          fish_to_passFPS <- fish_to_passFPS %>%
            dplyr::select(-c(.data$adequate_elev))
        }
    } else {
      stop('FPS must be one of: "NONE", "FSC", "FSS", "FSO", or "FISH WEIR"')
    }
  } else { # Finally, if it is "NONE", 0 flow
    fish_to_passFPS <- fish_postDPE %>%
      dplyr::mutate(FPS_flow = 0)
  }
  # Perform calculations based on which FPS was indicated in the function call,
  # Save outputs into intermediate dataframe fishBearingFlow with new columns 
  # for fish bearing flow (B.___) created using dplyr::mutate()
  fish_to_passFPS <- fish_to_passFPS %>%
    dplyr::mutate(Q.Tot = .data$turb_flow + .data$spill_flow + .data$RO_flow)
  # "switch" provides different outcomes depending on the value of `fps`
  fishBearingFlow <- switch(as.character(fps),
    # If no collector, simple distribution
    "NONE" = data.frame(fish_to_passFPS) %>%
      dplyr::mutate(
        B.spill = .data$spill_flow,
        B.turb = .data$turb_flow,
        B.RO = .data$RO_flow,
        B.FPS = 0
      ),
    "FSC" = fish_to_passFPS %>% # If FSC, simply sum together B.total above and FPS_flow
    #   Here, if there is an FSC, the total attraction water is more than the
    #   outflow. It's dam + recirculating FSC water
      dplyr::mutate(
        # This will preserve the total flow, which needs to be maintained
        #   in later fish survival calculations
        # These new steps from FBW Basic commands
        multiplier = (.data$Q.Tot / (.data$Q.Tot + .data$FPS_flow)),
        B.spill = .data$spill_flow * .data$multiplier,
        B.turb = .data$turb_flow * .data$multiplier,
        B.RO = .data$RO_flow * .data$multiplier,
        B.FPS = .data$FPS_flow * .data$multiplier
        # B.Total=B.turb+B.RO+B.spill+B.FPS
      ),
    # If FSS:
    # Floating surface structure influences Turbine(PH) and reg. outlet (RO) flows
    #   Subract off the FSS flows from the total flows
    #   RO/PH will be proportioned based on the split between them
    "FSS" = fish_to_passFPS %>%
      dplyr::mutate(
        fishPctRO = .data$RO_flow / (.data$turb_flow + .data$RO_flow),
        B.spill = .data$spill_flow,
        B.turb = pmax(0, .data$turb_flow - (.data$FPS_flow * (1 - .data$fishPctRO))),
        B.RO = pmax(0, .data$RO_flow - (.data$FPS_flow * .data$fishPctRO)),
        B.FPS = .data$FPS_flow
      ) %>% 
      dplyr::select(-.data$fishPctRO),
    # The FSO collects flow needed for FPS_flow first from the spill, then the RO, then the PH
    "FSO" = fish_to_passFPS %>% #
      ### NOTE: These are coded "out of order", but the spill - RO - PH order is preserved
      dplyr::mutate(
        # First take from the spillway...
        B.spill = pmax(.data$spill_flow - .data$FPS_flow, 0),
        # any remaining flow from RO_flow and spill, otherwise the orig. value
        B.turb = pmax(.data$turb_flow +
          pmin(.data$RO_flow + pmin(.data$spill_flow - .data$FPS_flow, 0), 0),
            0), 
        B.RO = pmax(.data$RO_flow + pmin(.data$spill_flow - .data$FPS_flow, 0),
          0), # any remaining flow from spill, otherwise the original value
        B.FPS = .data$FPS_flow
      ) %>%
      # Remove flow from spill, RO, and powerhouse/turbine
      dplyr::mutate(
        spill_flow = .data$B.spill,
        turb_flow = .data$B.turb,
        RO_flow = .data$B.RO
      ),
    # If FISH WEIR, the FPS collects from the spillway, otherwise flows are the same
    "FISH WEIR" = fish_to_passFPS %>% 
      dplyr::mutate(
        B.spill = .data$spill_flow - .data$FPS_flow,
        B.turb = .data$turb_flow,
        B.RO = .data$RO_flow,
        B.FPS = .data$FPS_flow
      ) %>% 
      # Take away flow from the spillway with a FISH WEIR
      dplyr::mutate(spill_flow = .data$B.spill)
  )
  # A final check, return a warning if FPS flow is higher than spillway flow. 
  if (fps == "FISH WEIR" & length(which(fishBearingFlow$B.spill < 0)) > 0) {
    warning("Some B.spill values are <0 (this can happen when you specify a 'FISH WEIR' FPS and the spill flow is less than FPS_flow.")
  }
  percentDist <- fishBearingFlow %>%
  # First, calculate proportional flow
    dplyr::mutate(
      pB.spill = .data$B.spill / .data$Q.Tot,
      pB.turb = .data$B.turb / .data$Q.Tot,
      pB.RO = .data$B.RO / .data$Q.Tot,
      pB.FPS = .data$B.FPS / .data$Q.Tot
    )
  # Now that fish-bearing flow is calculated, apply route effectiveness. 
  # It requires linear interpolation, so first create linear 
  # interpolation functions using the supplied Qratio columns
  #   (these are called later)
  ret <- data.frame(param_list$route_eff)
  if (all(is.na(ret$FPS)) | length(ret$FPS) == 0) {
    fps_RElookup <- function(x) return(0)
  } else {
    # If there are any values:
    fps_RElookup <- approxfun(
      x = ret$q_ratio,
      y = ret$FPS,
      rule = 2
    )
  }
  spill_RElookup <- approxfun(
    x = ret$q_ratio,
    y = ret$Spill,
    rule = 2
  )
  RO_RElookup <- approxfun(
    x = ret$q_ratio,
    y = ret$RO,
    rule = 2
  )
  PH_RElookup <- approxfun(
    x = ret$q_ratio,
    y = ret$Turb,
    rule = 2
  )
  # Use these functions to lookup RE's and calculate adjusted total
  #   Note: This is termed Denom_Array in FBW VB code
  RETable <- percentDist %>%
    # Apply RE using the interpolation functions
    dplyr::mutate(
      RE.spill = spill_RElookup(.data$pB.spill),
      RE.turb = PH_RElookup(.data$pB.turb),
      RE.RO = RO_RElookup(.data$pB.RO),
      RE.FPS = fps_RElookup(.data$pB.FPS),
      adj.Total = ((.data$RE.spill * .data$pB.spill) + 
        (.data$RE.FPS * .data$pB.FPS) +
        (.data$RE.RO * .data$pB.RO) + 
        (.data$RE.turb * .data$pB.turb))
    )
  # Now, adjust for proportion of fish through each outlet
  #   PercentToPass calculations
  fishDist <- RETable %>%
    # Then, adjust for proportion of fish through each outlet
    dplyr::mutate(
      F.spill = (.data$approaching_daily_postDPE * .data$RE.spill *
        .data$pB.spill) / .data$adj.Total,
      F.turb = (.data$approaching_daily_postDPE * .data$RE.turb *
        .data$pB.turb) / .data$adj.Total,
      F.RO = (.data$approaching_daily_postDPE * .data$RE.RO * .data$pB.RO) /
        .data$adj.Total,
      F.FPS = (.data$approaching_daily_postDPE * .data$RE.FPS *
        .data$pB.FPS) / .data$adj.Total
    )
    if (!verbose) {
      fishDist <- fishDist %>%
        dplyr::select(-c(.data$adj.Total))
    }
  # Incorporate nets if they are being used
  if(tolower(param_list$alt_desc[["nets"]]) == "y") {
    fishDist <- fishDist %>%
      dplyr::mutate(
        F.turb = 0,
        F.RO = 0)
    if (tolower(param_list$route_specs$normally_used[
      which(rownames(param_list$route_specs) == "Spill")]) == "n") {
      # If the spillway is not normally used, fish are distributed
      #   through it first then the FPS
      fishDist <- fishDist %>%
        dplyr::mutate(
          F.spill = .data$approaching_daily_postDPE *
            (.data$RE.spill * .data$pB.spill) / .data$adj.Total,
          F.FPS = .data$approaching_daily_postDPE - .data$F.spill
        )
    } else {
      fishDist <- fishDist %>%
        dplyr::mutate(
          F.spill = 0,
          F.FPS = .data$approaching_daily_postDPE
        )
    }
  }
  fishDist_out <- fishDist %>%
    dplyr::mutate(
      F.NoPass = .data$approaching_daily - .data$approaching_daily_postDPE)
  # Return the "fishDist" data frame depending on verbose output
  if (!verbose) {
    return(fishDist_out %>%
      dplyr::select(-c( # Remove the following
        .data$B.spill, .data$B.turb, .data$B.RO, .data$B.FPS,
        .data$pB.spill, .data$pB.turb, .data$pB.RO, .data$pB.FPS,
        .data$RE.spill, .data$RE.turb, .data$RE.RO, .data$RE.FPS
      )))
  } else {
    return(fishDist_out)
  }
}
