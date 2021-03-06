set seed 12345
*************************************************************
/*** Chapter 6: Uncertainty ***/
*************************************************************

*************************************************************
/*** Prepare settings and specify working directory ***/
*************************************************************
clear all
set seed 123456
*************************************************************
*************************************************************
/*** 6.1 Estimation ***/
*************************************************************
*************************************************************

*************************************************************
/** 6.1.1 Unbiasedness and Consistency **/
*************************************************************
set obs 100

* generate a sample
* Y0 has mean 0 and standard deviation of 1
generate Y0 = rnormal(0, 1)
* Y1 has mean 1 and standard deviation of 1
generate Y1 = rnormal(1, 1)

*individual treatment effect
generate tau = Y1 - Y0

* true value of the sample average treatment effect
summarize tau, meanonly
scalar sate = r(mean)
display sate

program sate_sim, rclass
	* create temporary assignment numbers and sort
	    tempvar random treat 
	    generate `random' = runiform()
	    sort `random'
	* split sample and assign treatment
	    generate `treat' = cond(_n <= _N / 2, 1, 0)
	* calculate treatment means
	    summarize Y0 if `treat' == 0
	    scalar mu0 = r(mean)
	    summarize Y1 if `treat' == 1
	    scalar mu1 = r(mean)
	* differences-in-means
	    return scalar difmeans = mu1 - mu0
	* estimation error for SATE
	    return scalar esterr = mu1 - mu0 - sate
end
cd uncertainty
simulate esterror = r(esterr) difmeans=r(difmeans), saving(sate, replace) reps(5000) nodots: sate_sim      
* estimation error for SATE
summarize esterr
 local dm_max =round(r(max),.001)
 local dm_min =round(r(min),.001)
 local ee = round(r(mean),.001)

* PATE simulation
program pate_sim, rclass
	syntax, [obs(integer 100) mu0(real 0) mu1(real 1) sigma(real 1)]
	drop _all
	set obs `obs'
	scalar PATE = `mu1' - `mu0'
	tempvar Y0 Y1 treat 	
	* generate a sample for each simulation: this used to be outside the program
	    generate `Y0' = rnormal(`mu0',`sigma')
	    generate `Y1' = rnormal(`mu1',`sigma')
	* assign treatment condition
	    generate `treat' = cond(_n <= `obs' / 2, 1, 0)
	* calculate and store means for two samples
	    summarize `Y0' if `treat' == 0
	    scalar p_mu0 = r(mean)
	    summarize `Y1' if `treat' == 1
	    scalar p_mu1 = r(mean)
	* estimation error for PATE
	    return scalar esterr = p_mu1 - p_mu0 - PATE
end

simulate esterror =r(esterr), reps(5000) nodots: pate_sim, obs(100) mu0(0) mu1(1) sigma(1)
* estimation error for PATE
summarize esterror


*************************************************************
/** 6.1.2 Standard Error **/
*************************************************************
use sate, clear
local x = sate // save sate as local because xline is nonevaluative

histogram difmeans, xline(`x')  ///
	ylabel(0(.5)3) xtitle("Difference-in-means estimator") ///
	title("Sampling distribution") text(2.8 .95 "True SATE") ///
	fcolor(none) color(black) width(.1) 

summarize difmeans
summarize difmeans
local sd = round(`=r(sd)', .001)

generate rmse1 = (difmeans - sate)^2
summarize rmse1, meanonly
display sqrt(r(mean))
summarize rmse1
local rmse = round(sqrt(`=r(mean)'), .001)

local o_se_r = round(sqrt(0.6 * (1 - 0.6) / 1000),.001)
local o_se_rp = round(sqrt(0.6 * (1 - 0.6) / 1000)*100,.1)

clear
* PATE with standard errors	
program patese, rclass
	syntax, [obs(integer 100) mu0(real 0) mu1(real 1) sigma(real 1)]
	set obs `obs'
	scalar PATE = `mu1' - `mu0'
	* generate randomly assigned treatment groups, as before
	    tempvar Y0 Y1 treat
	    generate `Y0' = rnormal(`mu0',`sigma')
	    generate `Y1' = rnormal(`mu1',`sigma')
	    generate `treat' = cond(_n <= `obs' / 2, 1, 0)
	* store means and variances for two samples
	    summarize `Y0' if `treat' == 0, detail
	    scalar p_mu0 = r(mean)
	    scalar var0 = r(Var)
	    summarize `Y1' if `treat' == 1, detail
	    scalar p_mu1 = r(mean)
	    scalar var1 = r(Var)
	* differences-in-means and standard error
	    return scalar difmeans = p_mu1 - p_mu0
	    return scalar se = sqrt( (var1 / (`obs' / 2)) + (var0 / (`obs' / 2)) )
end	
simulate difmeans =r(difmeans) se = r(se), reps(5000) saving(patese, replace) nodots: patese, obs(100) mu0(0) mu1(1) sigma(1)
summarize difmeans se

*************************************************************
/** 6.1.3 Confidence Intervals **/
*************************************************************
twoway function normalden(x) ,  xline(0, lstyle(foreground)) range(`=invnormal(.025)' `=invnormal(.975)') recast(area) ///
   ytitle("Density") ylabel(0(.1).5) color(red%50) fint(inten50) || ///
   function normalden(x) , color(black) range(-4 4) xlabel(none) legend(off) ///
   xtick(`=invnormal(.025)' 0 `=invnormal(.975)', tpos(crossing) tl(*3)) xlabel(`=invnormal(.025)' "-z{subscript: {&alpha}/2}" 0 "0" `=invnormal(.975)' "z{subscript: {&alpha}/2}") xtitle("") xscale(noline) || ///
   scatteri  -.01 `=invnormal(.025)'  -.01 `=invnormal(.975)' , connect(l) msymbol(i) lcolor(black)
   

local p995r = round(invnormal(.995),.01) 
local p975r = round(invnormal(.975),.01) 
local p95r = round(invnormal(.95),.01) 

local ose = round(sqrt(0.6 * (1 - 0.6) / 1000), .01)

scalar xbar = .6
scalar se_bar  = sqrt(.6 * (1 - .6) / 1000)
* 99% confidence intervals
display xbar - invnormal(.995) * se_bar, xbar + invnormal(.995) * se_bar
* 95% confidence intervals
display xbar - invnormal(.975) * se_bar, xbar + invnormal(.975) * se_bar
* 90% confidence intervals
display xbar - invnormal(.95) * se_bar, xbar + invnormal(.95) * se_bar

* PATE 95% confidence intervals
generate ci95lo = difmeans - invnormal(.975) * se
generate ci95hi = difmeans + invnormal(.975) * se

* PATE 90% confidence intervals
generate ci90lo = difmeans - invnormal(.95) * se
generate ci90hi = difmeans + invnormal(.95) * se

* coverage rate for 95% confidence intervals
generate coverage95 = ci95lo <= 1 & ci95hi >= 1
* coverage rate for 90% confidence intervals
generate coverage90 = ci90lo <= 1 & ci90hi >= 1

summarize coverage95 coverage90

clear 
program confint, rclass
	syntax, obs(integer) pr(real) alpha(real) 
	clear
	set obs `obs'
	generate d = rbinomial(1, `pr') 
	summarize d, meanonly
	scalar xbar = r(mean)
	scalar se = sqrt(xbar * (1 - xbar) / `obs')
	return scalar ciresults = ///
		(`pr'  > (xbar - invnormal(1 - `alpha' / 2) * se)) & ///
		 (`pr' < (xbar + invnormal(1 - `alpha' / 2) * se)) 
end

* 50 observations
simulate cires50 = r(ciresults), reps(5000) nodots: confint, obs(50) pr(.6) alpha(.05) 
summarize cires
* 100 observations
simulate cires100 = r(ciresults) , reps(5000) nodots: confint, obs(100) pr(.6) alpha(.05) 
summarize cires
* 1000 observations
simulate cires = r(ciresults) , reps(5000) nodots: confint, obs(1000) pr(.6) alpha(.05) 
summarize cires

local o =round(1 / .03^2,1)

*************************************************************
/** 6.1.4 Margin of Error and Sample Size Calculation in Polls **/
*************************************************************
clear
set obs 99
generate p = _n / 100
generate n1 = 1.96^2 * p * (1 - p) / (.01^2)
generate n2 = 1.96^2 * p * (1 - p) / (.03^2)
generate n3 = 1.96^2 * p * (1 - p) / (.05^2)

line n1 n2 n3 p, xtitle("Population proportion")  /// 
	ytitle("Sample size") yscale(titlegap(*3)) xscale(titlegap(*2)) ///
	graphregion(margin(2 2 2 8)) lpattern(solid longdash dash) ///
	text(8400 .5 "Margin of error = 0.01") ///
	text(1700 .5 "Margin of error = 0.03") ///
	text(-200 .5 "Margin of error = 0.05") ///
	legend(off)  yscale(r(-700(2000)10000))

use pres08, clear
merge 1:m state using polls08
* create a date variable
 generate polldate = date(middate,"YMD")
 format polldate %td 
* compute the number of days to Election Day
 generate daystoelection = date("2008-11-04","YMD") - polldate
* calculate and subset to most recent poll
bysort state: egen mindays = min(daystoelection)
keep if daystoelection == mindays
* calculate and store mean of poll predictions
collapse (mean) ev obama pollpred = obamapoll, by(state)
	// convert percent to decimal
	replace pollpred = pollpred / 100 
	replace obama = obama / 100
* standard error and confidence intervals
generate pollpred_se = sqrt(pollpred * (1 - pollpred) / 1000)
generate pollpred_lo = pollpred - (invnormal(1 - .05 / 2) * pollpred_se)
generate pollpred_hi = pollpred + (invnormal(1 -.05 / 2) * pollpred_se)

twoway rspike pollpred_lo pollpred_hi obama || ///
	scatter pollpred obama, msymbol(Oh) mcolor(black) || ///
	scatteri 0 0 1 1 , msymbol(none) c(line) ///
	xtitle("Obama's vote share") ytitle("Poll prediction") ///
	legend(off)  
	
* proportion of confidence intervals that contain the Election Day outcome	
generate pollcorrect = cond(obama >= pollpred_lo & obama <= pollpred_hi, 1, 0)	
summarize pollcorrect
local cov1 = round(`=r(mean)',.001) * 100

* bias
generate bias = pollpred - obama 	
summarize bias
* bias corrected estimate
generate pollbias = pollpred - r(mean)

* bias-corrected standard error
generate bias_se = sqrt(pollbias * (1 - pollbias) / 1000)
* bias-corrected 95% confidence interval
generate bias_lo = pollbias - (invnormal(1 - .05 / 2) * bias_se)
generate bias_hi = pollbias + (invnormal(1 - .05 / 2) * bias_se)
* proportion of bias-corrected CIs that contain the Election Day outcome
generate biascorrect = cond(obama >= bias_lo & obama <= bias_hi, 1, 0)	
summarize biascorrect

*************************************************************
/** 6.1.5 Analysis of Randomized Controlled Trials **/
*************************************************************
use STAR, clear
summarize g4reading if classtype == 1, meanonly
histogram g4reading if classtype == 1, xline(`r(mean)', lcolor(red)) ///
	xtitle("Fourth-grade reading test score") title("Small class") ///
	width(20) fcolor(none) color(black) name(read1, replace)
summarize g4reading if classtype == 2, meanonly
histogram g4reading if classtype == 2, xline(`r(mean)', lcolor(red)) ///
	xtitle("Fourth-grade reading test score") title("Regular class") ///
	width(20) fcolor(none) color(black) name(read2, replace)
graph combine read1 read2

* estimate and standard error by class
tabstat g4reading, by(classtype) statistics(mean semean)
* small class size
ci means g4reading if classtype == 1
return list
scalar est_small = r(mean)
scalar se_small = r(se)
scalar cilo_small = r(lb)
scalar cihi_small = r(ub)

* regular class size
ci means g4reading if classtype == 2
scalar est_reg= r(mean)
scalar se_reg = r(se)
scalar cilo_reg = r(lb)
scalar cihi_reg = r(ub)

* difference-in-means estimator
scalar ate_est = est_small - est_reg
display ate_est
* standard error and 95% confidence interval
scalar ate_se = sqrt(se_small^2 + se_reg^2)
display ate_se
scalar ate_lo = ate_est - invnormal(1 - .05 / 2) * ate_se
scalar ate_hi = ate_est + invnormal(1 - .05 / 2) * ate_se
display ate_lo, ate_hi
local ateest : di %3.2f round(scalar(ate_est),.001)
local atese : di %3.2f round(scalar(ate_se),.001)
local ate_lo : di %3.2f round(scalar(ate_lo),.001)
local ate_hi : di %3.2f round(scalar(ate_hi),.001)

*************************************************************
/** 6.1.6 Analysis based on Student’s t-Distribution **/
*************************************************************
twoway function normalden(x), range(-6 6)  || ///
 	function tden(2, x), range(-6 6) || ///
 	function tden(10, x), lpattern(dash) lcolor(blue)  range(-6 6)  || ///
  	function tden(50, x), range(-6 6)  ///
  	legend(label(1 "normal") label(2 "df = 2") label(3 "df = 10") label(4 "df = 50")) ///
  	ytitle("Density") xtitle("") xlabel(-6(2)6) name(den, replace)
preserve
	clear 
 	set obs 99
 	gen y = _n/100
	gen q = invnormal(y)
 	gen t2 = invt(2, y)
 	gen t10 = invt(10,y)
 	gen t50 = invt(50,y)
 	twoway line q q ,  || ///
   		line t2 q if q>=-2.1 & q<=2.1, yscale(range(-4 4)) ylabel(-4(2)4)  ///
   		|| line t10 q , lpattern(dash) lcolor(blue) || line t50 q ,  ///
  		 xtitle("Quantile of the standard normal distribution") ///
   		ytitle("Quantile of the t-distribution") ///
   		legend(label(1 "normal") label(2 "df = 2") label(3 "df = 10") label(4 "df = 50")) name(quant, replace)
 restore
 graph combine den quant
  
local crit_t = round(invt(49,.975),.01)
local crit_n = round(invnorm(.975),.01)

* 95% confidence intervals, by classtype
ttest g4reading if classtype == 1 | classtype == 2 , by(classtype) unequal

* 95% CI based on the central limit theorem
display cilo_small, cihi_small  // small class size
display cilo_reg, cihi_reg // regular class size
local df = round(r(df_t),.1)

local mf = comb(8,4)
local imf = round(1 / comb(8,4),.01)

*************************************************************
*************************************************************
/*** 6.2 Hypothesis Testing ***/
*************************************************************
*************************************************************

*************************************************************
/** 6.2.1 Tea-Tasting Experiment **/
*************************************************************
clear
set obs 5
input guess pr1
	0	1
	2	16
	4	36
	6	16
	8	1
*end
generate pr = pr1 / 70
twoway bar pr guess , ytitle("Probability") xtitle("Number of correct guesses") ///
  ylabel(0(.1).6)  
local c3 = comb(4,1) * comb(4,3)
local c4 = comb(4,2) * comb(4,2)

clear
set obs 5
* use number of correctly classified cups as identifier
egen guess = fill(0 2 4 6 8)

* truth: enumerate the number of assignment combinations
generate true = comb(4,0) * comb(4,4) if guess == 0
replace true = comb(4,1) * comb(4,3) if guess == 2
replace true = comb(4,2) * comb(4,2) if guess == 4
replace true = comb(4,3) * comb(4,1) if guess == 6
replace true = comb(4,4) * comb(4,0) if guess == 8
list true

* compute probability: divide it by the total number of events
summarize true
generate trueprob = true / r(sum)
list guess trueprob

set seed 12345
program ladytea, rclass
	syntax 
	clear
	set obs 8
	* create temporary variables that will be regenerated in simulation
	  tempvar unif correct ladyguess sampleguess
	* assign first half of observations "milk first," second half "tea first"
	  generate `sampleguess' = cond(_n <=  _N / 2, "M", "T")
	* generate random number and re-sort order/rows
	  generate `unif' = runiform()
	  sort `unif'
	* if re-sorted row equals 1, 4, 5, 8, assign ladyguess M, assign T otherwise
	  generate `ladyguess' = cond(inlist(_n, 1, 4, 5, 8), "M", "T")
	* mark as correct if sample guess equals lady guess, save result 
	  generate `correct' = cond(`sampleguess' == `ladyguess', 1, 0)
	  summarize `correct'
	  return scalar correct = r(sum)
end

preserve
	simulate guess = r(correct), reps(1000) nodots: ladytea
	tabulate guess
	generate correct = 1
	collapse (sum) correct, by(guess)
	tempfile sim
	save sim, replace
restore

* estimated probability for each number of correct guesses
merge 1:1 guess using sim, keep(3)
generate correctpct = correct / 1000
* comparison with analytical answers; the differences are small
generate dif = correct / 1000 - trueprob
list guess correctpct dif
erase sim.dta

local prg = round(1/70,.001)
local pval = round((1+16)/70 , .001)
local prg2 = round(2/70,.001)
local pval2 = round(2*(1+16)/70 , .001)

*************************************************************
/** 6.2.2 The General Framework **/
*************************************************************
clear
set obs 8
generate treat = cond(inlist(_n, 1, 4, 5, 8), 1, 0)
generate guess8 = treat
generate guess6 = cond(inlist(_n, 1, 3, 5, 8), 1, 0)
tabulate treat guess8, exact
tabulate treat guess6, exact

*************************************************************
/** 6.2.3 One-Sample Tests **/
*************************************************************
twoway function normalden(x, .5 , .01567098), range(.46 .54) xline(.54, lcolor(black)) ///
   xline(.5, lcolor(black) lpattern(dot)) xline(.46, lcolor(black) lpattern(dash)) ///
   text(17 .57 "Observed value") ytitle("Density") xtitle("Sample proportion") || ///
   function normalden(x, .5 , .01567098), range(.4 .46) color(red) recast(area) || ///
   function normalden(x, .5 , .01567098), range(.54 .6) color(red) recast(area) legend(off) 
scalar xbar = 550 / 1018
* standard deviation of sampling distribution
scalar se = sqrt(.5 * .5 / 1018)
* upper blue area in the figure 
scalar upper = 1 - normal((xbar - .5) / se)
* lower blue area in the figure; identical to the upper area
scalar lower = normal((.5 - (xbar - .5) - .5) / se)
* two-sided p-value
display upper + lower

display 2 * upper

* one-sided p-value
display upper

scalar zscore = (xbar - .5) / se
display zscore

* one-sided p-value
display  1 - normal(zscore)   

* two-sided p-value
display (1 - normal(zscore)) * 2   


* 99% confidence interval contains 0.5
display (xbar - invnormal(.995) * se), (xbar + invnormal(.995) * se)

* 95% confidence interval does not contain 0.5
display (xbar - invnormal(.975) * se), (xbar + invnormal(.975) * se)

* one-sample proportions test with 95% confidence interval
prtesti 1018 550 .5, count

* one-sample proportions test with 99% confidence interval
prtesti 1018 550 .5, count level(99)

* two-sided one-sample t-test
use STAR, clear
ttest g4reading = 710

*************************************************************
/** 6.2.4 Two-Sample Tests **/
*************************************************************

* one-sided p-value
display normal(-abs(ate_est) / ate_se)

* two-sided p-value
display 2 * normal(-abs(ate_est) / ate_se)

* testing the null of zero average treatment effect
ttest g4reading if classtype==1 | classtype==2, by(classtype) unequal

use resume, clear
prtest call, by(race)

summarize call 
scalar p = r(mean)

* sample size and proportions
summarize call if race == "black"
scalar n0 = r(N)
scalar p0 = r(mean)
summarize call if race == "white"
scalar n1 = r(N)
scalar p1 = r(mean)

* point estimate
scalar est = p1 - p0
display est

* standard error
scalar std_err = sqrt(p *(1 - p) * (1 / n0 + 1 / n1))
display std_err

* z-statistic
scalar zstat = est / std_err
display zstat

* one-sided p-value
display normal(-abs(zstat))

*************************************************************
/** 6.2.5 Pitfalls of Hypothesis Testing **/
*************************************************************
use onetailed, clear
generate tail = 1
generate pval = 1-normal(z)
tempfile one
save `one'
use twotailed, clear
generate tail = 2
generate pval = 2 * (1 - normal(abs(z)))

append using `one'

histogram pval, bin(20) fcolor(none) color(black) addplot(, xline(.05)) ///
ylabel(0(2)12) xtitle("p-value") name(hyp, replace)

*************************************************************
/** 6.2.6 Power Analysis **/
*************************************************************
clear
scalar n = 250
scalar p = .48
scalar se = sqrt(p* (1 - p) / n)
scalar p0 = .5
scalar se0 = sqrt(p0* (1 - p0) / n)
 
twoway function normalden(x, p, se) , range(.35 .65) lcolor(blue) || ///
 	function normalden(x, p0, se0), range(.35 .65) lcolor(black) ///
  	ytitle("Density") xtitle("Proportion, p*") ylabel(0(2)12) legend(off) || ///
  	function normalden(x, p, se), color(blue%50)  range(.35 `=p0-invnormal(.975)*se0') ///
  	recast(area, ) fint(inten50) xlabel(.35(.05).65) || ///
  	function normalden(x, p, se), color(blue%50)  range(`=p0+invnormal(.975)*se0' .65) ///
  	recast(area, ) fint(inten50) xline(`=p0-invnormal(.975)*se0' `=p0+invnormal(.975)*se0', ///
  	lpattern(dash) lcolor(black)) xline(`=scalar(p0)' , lcolor(black) lpattern(dot) lwidth(medthick)) ///
  	name(power1, replace)
twoway function normal((.5 -invnormal(.975)*sqrt(.5*(1-.5)/250)-x)/sqrt(x*(1-x)/250)) ///
 	+1-normal((.5 +invnormal(.975)*sqrt(.5*(1-.5)/250)-x)/sqrt(x*(1-x)/250)) , range(.35 .65) lcolor(black) || ///
	 function normal((.5 -invnormal(.975)*sqrt(.5*(1-.5)/500)-x)/sqrt(x*(1-x)/500)) ///
	 +1-normal((.5 +invnormal(.975)*sqrt(.5*(1-.5)/500)-x)/sqrt(x*(1-x)/500)) , range(.35 .65) lcolor(blue) || ///
 	function normal((.5 -invnormal(.975)*sqrt(.5*(1-.5)/1000)-x)/sqrt(x*(1-x)/1000)) ///
 	+1-normal((.5 +invnormal(.975)*sqrt(.5*(1-.5)/1000)-x)/sqrt(x*(1-x)/1000)) , range(.35 .65) lcolor(red) lpattern(dash) ///
 	legend(pos(5) ring(0) cols(1) symxsize(6) keygap(1) label(1 "n=250") label(2 "n=500") label(3 "n=1000")) ////
 	xtitle("Proportion, p*") ytitle("Power") ///
 	yline(.05, lpattern(dash) lcolor(black)) xline(.5, lpattern(dot) lwidth(medthick) lcolor(black)) ///
 	xlabel(.35(.05).65) name(power2, replace) 
graph combine power1 power2

* set the parameters
scalar n = 250
scalar pstar = .48 // data-generating process
scalar pnull = .5 // null value

* standard errors under the hypothetical data-generating process
scalar sestar = sqrt(pstar * (1 - pstar) / n)
* standard error under the null
scalar se = sqrt(pnull *(1 - pnull) / n)
* power
display normal(((pnull - invnormal(.975) * se) - pstar) / sestar) + ///
	    (1 - normal(((pnull + invnormal(.975) * se) - pstar) / sestar))
local pow = round(normal(((pnull - invnormal(.975) * se) - pstar) / sestar) + (1 - normal(((pnull + invnormal(.975) * se) - pstar) / sestar)),.01) * 100

* specify the parameters
scalar n1 = 500
scalar n0 = 500
scalar p1star = .05
scalar p0star = .1

* overall call back rate as a weighted average
scalar p = (n1 * p1star + n0 * p0star) / (n1 + n0)
* standard error under the null
scalar std_err = sqrt(p * (1 - p) * (1 / n1 + 1 / n0))
* standard error under the hypothetical data-generating process
scalar sestar = sqrt(p1star * (1 - p1star) / n1 + p0star * (1 - p0star) / n0)
  
display normal((-invnormal(.975) * std_err - (p1star - p0star)) / sestar) + ///
	   1 - normal((invnormal(.975) * std_err - (p1star - p0star)) / sestar)

power twoprop 0.05 .1, n(1000)

power twoprop 0.05 .1, p(.9)

power onemean 0 .25, n(100) sd(1)
local pow1 = round(`=r(power)',.01) * 100

power onemean 0 .25, power(.9) sd(1)
local pow2 = `=r(N)'

power twomeans 0 .25, power(.9) onesided
local pow3 = `=r(N1)'

*************************************************************
*************************************************************
/*** 6.3 Linear Regression Model with Uncertainty ***/
*************************************************************
*************************************************************

*************************************************************
/** 6.3.1 Linear Regression as a Generative Model **/
*************************************************************
use minwage, clear
* compute proportion of full-time employment before minimum wage increase
generate fullpropbefore = fullbefore / (fullbefore + partbefore)
* same thing after minimum wage increase
generate fullpropafter = fullafter / (fullafter + partafter)
* an indicator for NJ; 1 if it's located in NJ and 0 if in PA
generate nj = cond(location != "PA", 1, 0)

encode chain, generate(chainnum)
regress fullpropafter nj fullpropbefore wagebefore ibn.chainnum, nocons
estimates store minwage_noint
matrix list e(b)
matrix list e(V)
local nj = round(_b[nj] * 100,.1)

regress fullpropafter nj fullpropbefore wagebefore i.chainnum
estimates store minwage_int  

quietly regress fullpropafter nj fullpropbefore wagebefore ibn.chainnum, nocons
predict xb_noint, xb
display xb_noint

quietly regress fullpropafter nj fullpropbefore wagebefore i.chainnum 
predict xb_int, xb
display xb_int

*************************************************************
/** 6.3.2 Unbiasedness of Estimated Coefficients **/
*************************************************************

*************************************************************
/** 6.3.3 Standard Errors of Estimated Coefficients **/
*************************************************************

*************************************************************
/** 6.3.4 Inference about Coefficients **/
*************************************************************
use women, clear
regress water reserved
local bres : di %4.3f round(_b[reserved],.001)
local seres = round(_se[reserved],.001)
local tres = round(_b[reserved] / _se[reserved],.001)
local df = e(df_r)
local n = e(N)
local p = round(2 * ttail(`df',_b[reserved] / _se[reserved]),.001)
local bres2 = round(_b[reserved],.01)
local lowci = round(_b[reserved] - _se[reserved]*invt(e(df_r),.975),.01)
local upci = round(_b[reserved] + _se[reserved]*invt(e(df_r),.975),.01)

estimates restore minwage_noint
* retrieve coefficient and standard error for nj variable
display _b[nj]
display _se[nj]
local bnj = round(_b[nj],.001) * 100
local senj = round(_se[nj],.001) * 100
local df = e(df_r)
local n = e(N)
local par = e(df_m)

*************************************************************
/** 6.3.5 Inference about Predictions **/
*************************************************************
use MPs, clear
* Tory Party at negative margin
quietly regress lnnet margin if party == "tory" & margin < 0
margins, at(margin = 0)
* Tory Party at positive margin
quietly regress lnnet margin if party == "tory" & margin > 0
margins, at(margin = 0)

quietly regress lnnet margin if party == "tory" & margin < 0
margins, at(margin = 0)

quietly regress lnnet margin if party == "tory" & margin > 0
margins, at(margin = 0)

quietly regress lnnet margin if party == "tory" & margin < 0
quietly summarize margin if party == "tory" & margin < 0
quietly margins, at(margin = (`r(min)'(.01)0)) saving(torylow, replace)

quietly regress lnnet margin if party == "tory" & margin > 0
quietly summarize margin if party == "tory" & margin > 0
quietly margins, at(margin = (0(.01)`r(max)')) saving(toryhi, replace)

combomarginsplot torylow toryhi, xline(0, lpattern(dash)) ///
  	legend(off) xlabel(-.5(.2).3) ylabel(10/15) ///
 	xtitle("Margin of victory") ytitle("Log net wealth") ///
 	lplot1(msize(tiny)) lci1opts(color(gs12))

quietly regress lnnet margin if party=="tory" & margin < 0
quietly estadd margins, at(margin = 0)
matrix list e(margins_se)
matrix list e(margins_b)

* save standard error and point estimates (negative margin)
scalar se0 = e(margins_se)[1,1]
scalar fit0 =  e(margins_b)[1,1]

quietly regress lnnet margin if party=="tory" & margin > 0
quietly estadd margins , at(margin = 0)

* save standard error and point estimates (positive margin)
scalar se1 =  e(margins_se)[1,1]
scalar fit1 = e(margins_b)[1,1]

* standard error prediction
display se1

* s.e. of the intercept is the same as s.e. of the predicted value
display _se[_cons]

* standard error
scalar sediff = sqrt(se0^2 + se1^2)
display sediff
* point estimate
scalar diffest = fit1 - fit0
display diffest 
* confidence interval
display diffest - sediff * invnormal(.975)  // lower
display diffest + sediff * invnormal(.975)  // upper
* hypothesis test
scalar zscore = diffest / sediff
scalar pvalue = 2 * (1 - normal(abs(zscore)))
display pvalue

***********************************************************	
/*** Return to main qss directory ***/
***********************************************************
cd ..
graph close _all

