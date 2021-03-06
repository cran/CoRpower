# used for obtaining 'incRate' as a solution to the equation fIncRate(incRate, ...) = 0
# the rationale is that since 'risk0' = P(T <= taumax | T > tau, Z = 0) and T ~ Exp(incRate), we can back-calculate 'incRate'
# for a known 'risk0' (and a known 'tau' and 'taumax')
fIncRate <- function(incRate, risk0, tau, taumax){
  return((pexp(taumax, rate=incRate) - pexp(tau, rate=incRate)) / (1 - pexp(tau, rate=incRate)) - risk0)
}

#' Estimation of Size and Numbers of Cases and Controls in the Target Population of Active Treatment Recipients At Risk at the Biomarker Sampling Timepoint
#'
#' If the power calculation is done at the study design stage, the function estimates the size and numbers of cases and controls in the target population of active treatment recipients observed to be
#' at risk at the biomarker sampling timepoint.
#'
#' @param Nrand the number of participants randomized to the active treatment group
#' @param tau the biomarker sampling timepoint after randomization
#' @param taumax the time after randomization marking the end of the follow-up period for the clinical endpoint
#' @param VEtauToTaumax the treatment (vaccine) efficacy level between \eqn{\tau} and \eqn{\tau_{max}}
#' @param VE0toTau the treatment (vaccine) efficacy between 0 and \eqn{\tau}
#' @param risk0 the overall placebo-group endpoint risk between \eqn{\tau} and \eqn{\tau_{max}}
#' @param dropoutRisk the risk of participant dropout between 0 and \eqn{\tau_{max}}
#' @param propCasesWithS the proportion of observed cases with a measured biomarker response
#'
#' @details
#' The function estimates design parameters that are required as input to \code{\link{computePower}}. If the power calculation is done after the follow-up was completed, the estimates are replaced by the observed
#' counterparts for use as input parameters in \code{\link{computePower}}.
#'
#' The calculations include options to account for participant dropout by specifying \code{dropoutRisk} as well as for incomplete sample storage by specifying \code{propCasesWithS}.
#'
#' The estimation procedure considers the standard survival analysis framework with failure and censoring times denoted by \eqn{T} and \eqn{C}, respectively, and makes the following assumptions:
#' \enumerate{
#'   \item \eqn{T} and \eqn{C} are independent.
#'   \item \eqn{T|Z=0} follows an exponential distribution with rate \eqn{\theta_t} and \eqn{C|Z=0} follows an
#'      exponential distribution with rate \eqn{\theta_c}
#'   \item \eqn{RR_{\tau-\tau_{max}} := P(T <= \tau_{max}|T> \tau, Z=1)/P(T <= \tau_{max}|T> \tau, Z=0)} is assumed to be equal to \eqn{ P(T <= t|T> \tau, Z=1)/P(T <= t|T> \tau, Z=0)} for all \eqn{t \in (\tau,\tau_{max}]}.
#' }
#'
#' @return A list with the following components:
#' \itemize{
#'   \item \code{N}: the total estimated number of active treatment recipients observed to be at risk at \eqn{\tau}
#'   \item \code{nCases}: the estimated number of clinical endpoint cases observed between \eqn{\tau} and \eqn{\tau_{max}} in the active treatment group
#'    \item \code{nControls}: the estimated number of controls observed to complete follow-up through \eqn{\tau_{max}} endpoint-free in the active treatment group
#'    \item \code{nCasesWithS}: the estimated number of clinical endpoint cases observed between \eqn{\tau} and \eqn{\tau_{max}} in the active treatment group with an available biomarker response
#' }
#'
#' @examples
#' Nrand = 4100
#' tau = 3.5
#' taumax = 24
#' VEtauToTaumax = 0.75
#' VE0toTau = 0.75/2
#' risk0 = 0.034
#' dropoutRisk = 0.1
#' propCasesWithS = 1
#' computeN(Nrand, tau, taumax, VEtauToTaumax, VE0toTau, risk0, dropoutRisk, propCasesWithS)
#'
#' @seealso \code{\link{computePower}}
#'
#' @importFrom stats pexp
#'
#' @export
computeN <- function(Nrand, tau, taumax, VEtauToTaumax, VE0toTau, risk0, dropoutRisk, propCasesWithS) {

  # With T the failure time, C the censoring time, X = min(T,C), and
  # Z vaccination status (vaccine or hypothetical placebo), we have
  # RRoverall = RRtauToTaumax = P(T <= taumax|T > tau, Z=1)/P(T <= taumax|T > tau, Z=0)
  RRoverall <- 1 - VEtauToTaumax

  # Specify relative risk in the early period between enrollment and time tau,
  # defined as RR0toTau = P(T <= tau|Z=1) / P(T <= tau|Z=0)
  RR0toTau <- 1 - VE0toTau

  # Use the following assumptions:
  # 1. The failure time T and the censoring time C are independent.
  # 2. T and C have exponential distributions in the hypothetical placebo arm
  #    such that P(T <= t) = 1 - exp(-thetat t) and P(C <= t) = 1 - exp(-thetac) t).
  # 3. RRoverall = P(T <= t|T>tau, Z=1)/P(T <= t|T>tau, Z=0) for all t
  #    between tau and taumax (this will only approximately hold)

  # Calculate thetat and thetac on the same time-scale as that of tau and taumax:
  thetat <- uniroot(fIncRate, interval=0:1, risk0=risk0, tau=tau, taumax=taumax)$root
  thetac <- -log(1-dropoutRisk)/taumax

  # Calculate the number of subjects in the vaccine group at risk at tau
  # Logic: = Number enrolled * P(X > tau|Z=1)
  #        =    Nrand   * [1-RR0toTau*P(T <= tau|Z=0)]*P(C > tau)
  #        =    Nrand   * [1-RR0toTau*(1-exp(-thetat*tau))]*exp(-thetac*tau)
  N <- Nrand*(1-RR0toTau*pexp(tau,thetat))*(1-pexp(tau,thetac))
  # where pexp(t,theta) is the cumulative distribution function of an exponential random
  # variable with rate parameter thetat.


  # Number of observed rotavirus endpoints between tau and taumax in vaccinees:
  # Logic: = Number vaccinees at-risk at tau * P(T<=taumax,T<=C|X>tau,Z=1)
  #        = N*\int_0^infty P(T<=min(c,taumax),C=c|X>tau,Z=1)dc
  #        = N*\int_tau^infty P(tau<T<=min(c,taumax),C=c|Z=1)dc / P(X>tau|Z=1)
  #        = N*{\int_tau^infty P(tau<T<=min(c,taumax)|Z=1)P(C=c)dc}/P(X>tau|Z=1).

  # Now, the above integral in { } can be written as
  #   \int_tau^infty P(tau<T<=min(c,taumax)|Z=1)P(C=c)dc
  # = \int_tau^taumax P(tau<T<=c|Z=1)P(C=c)dc + P(tau<T<=taumax|Z=1)\int_taumax^infty P(C=c)dc
  # = \int_tau^taumax {P(T<=c|T>tau,Z=1)P(T>tau|Z=1)P(C=c)} + P(T<=taumax|T>tau,Z=1)\int_taumax^infty P(C=c)dc
  # = RRoverall*(1-RR0toTau*pexp(tau, thetat))*\int_tau^taumax{P(tau<T<=c|Z=0)/P(T>tau|Z=0)*thetac*exp(-thetac*c)dc} (term1)
  # + RRoverall*(1-RR0toTau*pexp(tau, thetat))*P(tau<T<=c|Z=0)/P(T>tau|Z=0)*[1 - pexp(taumax, thetac)] (term2)

  # Term (1) is calculated to be:
  #   RRoverall*(1-RR0toTau*pexp(tau, thetat))/P(T>tau|Z=0)*[exp(-thetat*tau)*(pexp(taumax,thetac)-pexp(tau,thetac))
  # - thetac*\int_tau^taumax exp(-(thetat+thetac)c)dc]
  # = RRoverall*(1-RR0toTau*pexp(tau, thetat))*[(pexp(taumax,thetac)-pexp(tau,thetac))
  # - thetac/((thetac+thetat)*exp(-thetat*tau))*(pexp(taumax,thetac+thetat)-pexp(tau,thetac+thetat)))]

  # Term (2) is calculated to be:
  #  RRoverall*(1-RR0toTau*pexp(tau, thetat))*[(pexp(taumax, thetat)-pexp(tau, thetat))/exp(-thetat*tau)]*[1 - pexp(taumax, thetac)]

  # Lastly, the denominator (call it term3) equals:
  # P(X>tau|Z=1) = [1-RR0toTau*P(T<=tau|Z=0)]P(C>tau)
  #              = [1-RR0toTau*pexp(tau,thetat)][1-pexp(tau,thetac)].

  # Putting it together
  term1 <- RRoverall*(1-RR0toTau*pexp(tau, thetat))*((pexp(taumax,thetac)-pexp(tau,thetac))
                      - (thetac/((thetac+thetat)*exp(-thetat*tau)))*(pexp(taumax,thetac+thetat)-pexp(tau,thetac+thetat)))

  term2 <- RRoverall*(1-RR0toTau*pexp(tau, thetat))*((pexp(taumax,thetat)-pexp(tau,thetat))/exp(-thetat*tau))*(1-pexp(taumax,thetac))
  term3 <- (1-RR0toTau*pexp(tau,thetat))*(1-pexp(tau,thetac))

  # Number of subjects in the vaccine group at-risk at tau with the clinical event (cases) by taumax.
  # nCases is notation used in the paper and in the R program computepower
  nCases <- round(N*(term1+term2)/term3)

  # Number of subjects in the vaccine group at-risk at tau without the clinical event (controls) by taumax.
  # Calculated the same as for term3 except using taumax instead of tau.
  # nControls is notation used in the paper and in the R program computepower
  nControls <- round(Nrand*(1-RRoverall*pexp(taumax,thetat))*(1-pexp(taumax,thetac)))

  # Number of subjects in the vaccine group at-risk at tau with the clinical event (cases) by taumax and with the biomarker measured.
  # nCasesWithS is notation used in R program computepower
  nCasesWithS <- round(propCasesWithS*nCases)

  return(list(N = round(N), nCases = nCases, nControls = nControls, nCasesWithS = nCasesWithS))
}
