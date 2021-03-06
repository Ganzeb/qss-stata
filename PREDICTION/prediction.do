
*************************************************************
/*** Chapter 4: Prediction ***/
*************************************************************

*************************************************************
/*** Clear memory ***/
*************************************************************
clear all

*************************************************************
*************************************************************
/*** 4.1 Predicting Election Outcomes ***/
*************************************************************
*************************************************************

*************************************************************
/** 4.1.1 Macros **/
*************************************************************
local book "Quantitative Social Science: An Introduction with Stata"
display "I am currently reading `book'."

global book2 "Quantitative Social Science: An Introduction with Stata"
display "I am currently reading $book2."


local math = 5 + 10 / 2
display `math'

*************************************************************
/** 4.1.2 Loops **/
*************************************************************
/*
foreach v of varlist variable1 variable2 variable3 {
    command1
    command2
    ...
    commandN
}
*/

local mylocal "string1 string2 string3" // must define local if not previously defined
foreach v of local mylocal {
	display  "This list contains string `v'."
}

foreach v of numlist 1 / 4 {
	display "This list contains number `v'."
}

foreach v of newlist newvar1 newvar2 newvar3 {
	display "Here we can create new variable `v'."
}

forvalues i = 1 / 4 {
	generate newvar`i' = 2 + `i'
	display newvar`i'
}

*************************************************************
/** 4.1.3 Poll Predictions **/
*************************************************************
cd prediction
use pres08, clear
merge 1:m state using polls08
generate presmargin = obama - mccain
generate pollmargin = obamapoll - mccainpoll

* create a date variable
generate polldate = date(middate, "YMD")
format polldate %td
 
* compute the number of days to Election Day
generate daystoelection = date("2008-11-04","YMD") - polldate
* save recoded data as new file
save poll_pres08, replace

* calculate and subset to most recent poll
bysort state: egen mindays = min(daystoelection)
keep if daystoelection == mindays

* calculate and store mean of poll predictions
collapse (mean) ev presmargin pollpred = pollmargin, by(state)

* prediction error of latest polls in each state
generate errors = presmargin - pollpred

* mean prediction error
summarize errors 
local err = `=round(r(mean),.1)'

* square the errors 
generate errors_sq = errors^2
* calculate root of mean squared errors
summarize errors_sq, meanonly
display sqrt(r(mean))

* histogram
summarize errors, meanonly
histogram errors, xline(`r(mean)', lpattern(dash)) ///
 	xtitle("Error in predicted margin for Obama (percentage points)") ///
	 title("Poll prediction error") text(.08 6.5 "average error", color(red)) ///
	fcolor(none) color(black) name(ch3_1, replace)

scatter presmargin pollpred, xline(0) yline(0) ///
 	xtitle("Poll results") ytitle("Actual election results") ///
	mlabel(state) mlabposition(0) msymbol(i) legend(off) || ///
 	scatteri -50 -50 100 100, connect(l) lpattern(dash)

* which state polls called wrong?
tabulate state if sign(pollpred) != sign(presmargin) 

* what was the actual margin for these states?
list state presmargin if sign(pollpred) != sign(presmargin) 

* actual results: total number of electoral votes won by Obama
summarize ev if presmargin > 0 
display r(sum)
* poll prediction
summarize ev if pollpred > 0 
display r(sum)

* load the data
use pollsUS08, clear
* create date variable
generate polldate = date(middate,"YMD")
format polldate %td

* calculate how many polls per day
bysort polldate: egen polls = count(polldate)
* create summary data set
collapse polls (sum) mccainpoll obamapoll, by(polldate)
* declare time-series data and fill gaps
tsset polldate
tsfill 

* sum total polling numbers and polls occurring in past 7 days using lags
tsegen obama_7day = rowtotal(L(0/6).obamapoll) 
tsegen mccain_7day = rowtotal(L(0/6).mccainpoll) 
tsegen polls_7day = rowtotal(L(0/6).polls) 

* divide 7-day polling sums by 7-day total number of polls
replace obama_7day = obama_7day / polls_7day
replace mccain_7day = mccain_7day / polls_7day
generate daystoelection = date("2008-11-04","YMD") - polldate
generate obama2_7day = 0
generate mccain2_7day = 0
generate polls2_7day = 0
local pres "obama mccain"
foreach cand of local pres {
	quietly forvalues i = 1 / 90 {
		summarize polls if daystoelection <= (90 - `i' + 7) & ///
			 daystoelection > 90 -`i'
		summarize `cand'poll if daystoelection <= (90 - `i'+ 7) & ///
			daystoelection > 90 - `i'
		replace `cand'2_7day = r(sum) / polls_7day if daystoelection == 91 - `i'
	}
}

*comparing the means between the time-series and loop approach
summarize obama_7day mccain_7day ///
	obama2_7day mccain2_7day if daystoelection <= 90

* create scatter plot using days to election variable
scatter obama2_7day mccain2_7day daystoelection if daystoelection <= 90, ///
	xline(0) xlabel(0(10)90) msymbol(Oh Oh) mcolor(blue red) || ///
	scatteri 52.93 0, mcolor(blue) || scatteri 45.65 0, mcolor(red) ///
	xlabel(0(20)80) xscale(reverse) xtitle("Days to the election") ///
	ytitle("Support for candidate (percentage points)") ///
	legend(label(1 "Obama") label(2 "McCain") order(1 2))

*************************************************************
*************************************************************	
/*** 4.2 Linear Regression ***/
*************************************************************
*************************************************************

*************************************************************
/** 4.2.1 Facial Appearance and Election Outcomes **/
*************************************************************

* load the data
use face, clear
* two-party vote share for Democrats and Republicans
generate dshare = dvotes / (dvotes + rvotes)
generate rshare = rvotes / (dvotes + rvotes)
generate diffshare = dshare - rshare

scatter diffshare dcomp if wparty=="R", mcolor(red) msymbol(T) || ///
	scatter diffshare dcomp if wparty=="D", mcolor(blue) ///
  	xtitle("Competence score for Democrats") ytitle("Democratic margin in vote share") ///
	title("Facial competence and vote share") ///
	legend(label(1 "Republicans") label(2 "Democrats"))

*************************************************************
/** 4.2.2 Correlation and Scatter Plots **/
*************************************************************
correlate dcomp diffshare
local rho = `=round(r(rho),.1)'

preserve
	clear
	set obs 100
	set seed 123456
	generate x1 = rnormal()
	generate y1 = x1/15+rnormal()
	generate y2 = x1 + (rnormal()/2)
	generate y3 = -x1 + rnormal()
	generate y4 = -2.5 + x1^2+ rnormal()/10

	correlate x1 y1
	scatter y1 x1 if y1<3 & x1<3, xlabel(-3(1)3) ylabel(-3(1)3) msymbol(Oh) subtitle("(a) Correlation = `: di %3.2f `=r(rho)''") ///
		name(c1, replace) xtitle("") ytitle("")

	correlate x1 y2
	scatter y2 x1 if y2<3 & x1<3, xlabel(-3(1)3) ylabel(-3(1)3) msymbol(Oh) subtitle("(b) Correlation = `: di %3.2f `=r(rho)''") ///
		name(c2, replace) xtitle("") ytitle("")

	correlate x1 y3
	scatter y3 x1 if y3<3 & x1<3, xlabel(-3(1)3) ylabel(-3(1)3) msymbol(Oh) subtitle("(c) Correlation = `: di %3.2f `=r(rho)''") ///
		name(c3, replace) xtitle("") ytitle("")

	correlate x1 y4
	scatter y4 x1 if y4<3 & x1<3, xlabel(-3(1)3) ylabel(-3(1)3) msymbol(Oh) subtitle("(d) Correlation = `: di %3.2f `=r(rho)''") ///
		name(c4, replace) xtitle("") ytitle("")

	graph combine c1 c2 c3 c4, rows(2)
restore

*************************************************************
/** 4.2.3 Least Squares **/
*************************************************************
* get estimated coefficient
regress diffshare dcomp
local cons = `=round(_b[_cons],.0001)'
local dcomp = `=round(_b[dcomp],.0001)'
local cons1 = `=round((_b[_cons]),.001)*100'
local dcomp1 : di %3.1f  `=round(_b[dcomp],.01)*10'

* display estimated coefficients and intercept
regress diffshare dcomp, coeflegend
display _b[_cons] 
display _b[dcomp]

* get fitted or predicted values
predict fitted, xb
list fitted in 1 / 6
scatter diffshare dcomp, msymbol(Oh) || lfit diffshare dcomp, range(0 1) ///
	xtitle("Competence scores for Democrats") ///
	ytitle("Democratic margin in vote share") ///
	title("Facial competence and vote share") legend(off)

sum dcomp
scalar comp=r(mean)
sum diffshare
scalar share = r(mean)
scatter diffshare dcomp , msymbol(Oh) mcolor(gs11)|| lfit diffshare dcomp , range(0 1) xline(0 `=scalar(comp)' , lpattern(dash))  ///
 title("Facial competence and vote share") xtitle("Competence scores for Democrats") ytitle("Democratic margin in vote share") ///
  yline(`=scalar(share)' ,lpattern(dash)) text(-.75 .1 "Intercept") ///
  text(-.86 .1 "^", size(medlarge)) text(-.89 .1 "α") ///
  text(-.85 `=scalar(comp)+.08' "Mean of X") text(-.88 .57 "{bf:__}") text(-.97 .57 "X") ///
  text(`=scalar(share)+.18' .07  "Mean of Y") text(.157 .07 "{bf:__}") text(.068 .07 "Y") ///
  text(-.225 .8 "Outcome""Y") text(.75 .88 "Predicted value") text(.65 .9 "^", size(medlarge)) ///
  text(.6 .9 "Y") legend(off) ///
  text(.12 .97 "Residual""`=ustrunescape("\u03B5\u0302")'") ///
  play(reg.grec)

display e(rmse)

predict resid, residuals
generate resid2 = resid^2 
summarize resid2, meanonly
display sqrt(r(mean))
local rmse = `=round(sqrt(`=r(mean)')*100,.1)'

correlate dcomp diffshare
local cor = `=round(`=r(rho)',.01)'
local cor = `=round(`=r(rho)',.01)'
summarize dcomp
local sddcomp = `=round(`=r(sd)',.01)'
summarize diffshare
local sdd = `=round(`=r(sd)',.01)'
local sddiffshare = `=round(`=r(sd)',.01)'
local dif = `=round(`cor'*`sdd',.01)*100'

*************************************************************
/** 4.2.4 Regression towards the Mean **/
*************************************************************
* add suffix and merge two data sets
use pres12, clear
rename (obama romney ev) =12
tempfile p12 
save `p12'

use pres08, clear
rename (obama mccain ev) =08
merge 1:1 state using `p12'

egen obama08z = std(obama08)
egen obama12z = std(obama12)

* intercept is estimated as essentially zero
regress obama12z obama08z

* regression without an intercept; estimated slope is identical
regress obama12z obama08z, noconstant

scatter obama12z obama08z, || lfit obama08z obama12z, /// 
	 xlabel(-4(2)4) ylabel(-4(2)4) range(-4 4) ///
  	 xtitle("Obama's standardized vote share in 2008") ///
  	 ytitle("Obama's standardized vote share in 2012") legend(off) 

* create dichotomous variable
generate obama12w = cond(obama12z > obama08z, 1, 0)

* save quartile values
summarize obama08z, detail
scalar p25 = r(p25)
scalar p75 = r(p75)

* bottom quartile
summarize obama12w if obama08z <= p25
local bottom = `=round(r(mean)*100,1)'

* top quartile
summarize obama12w if obama08z >= p75
local top = `=round(r(mean)*100,1)'

save pres0812.dta, replace

*************************************************************
/** 4.2.5 Model Fit **/
*************************************************************
* load data and regress Buchanan's 2000 votes on Perot's 1996 votes
use florida, clear
regress buchanan00 perot96

* obtain predicted values and residuals
predict fitted, xb
predict resid1, residuals

* obtain mean votes for Buchanan
summarize buchanan00

* compute TSS (total sum of squares) 
generate tss1 = (buchanan00 - r(mean))^2
summarize tss1
scalar tss_sum = r(sum)

* computer SSR (sum of squared residuals)
generate ssr1 = resid1^2
summarize ssr1
scalar ssr_sum = r(sum)

* coefficient of determination
display (tss_sum - ssr_sum) / tss_sum
local r2 = round((scalar(tss_sum) - scalar(ssr_sum)) / scalar(tss_sum),.01)*100 

display e(r2)

preserve
	use pres0812, clear
	regress obama12z obama08z
	display e(r2)
restore

regress buchanan00 perot96

* built-in graph command
rvfplot, yline(0)  

* using created variables
scatter resid1 fitted, yline(0)

local r2= round(`=e(r2)',.01) // save for later comparison without Palm Beach

summarize resid1
list county if resid1 == r(max)

* regression without Palm Beach
regress buchanan00 perot96 if county != "PalmBeach"

* R-squared or coefficient of determination
display e(r2)
local r2w= round(`=e(r2)',.01)

* predicted values and residual, excluding Palm Beach
predict xb_nopb, xb
predict resid_nopb, residuals

* residual plot
scatter resid_nopb xb_nopb if county!="PalmBeach", yline(0) ///
	xlabel(0(500)1500) ylabel(-500(500)2500) ///
   	xtitle("Fitted values") ytitle("Residuals") ///
	title("Residual plot without Palm Beach", size(medsmall)) ///
	msymbol(Oh)  name(resid, replace) 
* regression lines with and without Palm Beach
scatter buchanan00 perot96, msymbol(Oh) || ///
	lfit buchanan00 perot96, lpattern(dash) || ///
   	lfit buchanan00 perot96 if county!="PalmBeach", /// 
	xtitle("Perot's votes in 1996") ytitle("Buchanan's votes in 2000") ///
	title("Regressions with and without Palm Beach", size(medsmall)) ///
   	text(3250 30000 "Palm Beach") ///
	text(1500 30000 "Regression with" "Palm Beach") ///
   	text(300 30000 "Regression without" "Palm Beach") ///
	legend(off) name(fit, replace) 
graph combine resid fit

*************************************************************
*************************************************************
/*** 4.3 Regression and Causation ***/
*************************************************************
*************************************************************

*************************************************************
/** 4.3.1 Randomized Experiments **/
*************************************************************
use women, clear
* proportion of female politicians in unreserved GP vs. reserved GP
tabulate reserved, summarize(female)

* drinking water facilities
summarize water if reserved == 1, meanonly
scalar reserve1 = r(mean)
summarize water if reserved == 0, meanonly
scalar reserve0 = r(mean)
display reserve1 - reserve0

* irrigation facilities
summarize irrigation if reserved == 1, meanonly
scalar irrig1 = r(mean)
summarize irrigation if reserved == 0, meanonly
scalar irrig0 = r(mean)
display irrig1 - irrig0

regress water reserved
regress irrigation reserved

*************************************************************
/** 4.3.2 Regression with Multiple Predictors **/
*************************************************************
use social, clear
regress primary2008 i.messages

* create indicator variables
tabulate messages, generate(message)
regress primary2008 message2 message3 message4

local control = round(_b[message2],.001)
local neigh = round(_b[message4],.001)
local cons = round(_b[_cons],.001)
local control = round(_b[message2],.001)
local neigh = round(_b[message4],.001)

local pred1 = `cons'+`control'
local pred1r = round(`pred1'*100,.1)
local pred2 = `cons'+`neigh'

preserve
	* create a data set with unique values of messages
	duplicates drop messages, force
	tabulate messages

	* make prediction for each observation from this new data set
	predict newfit, xb
	tabulate messages, summarize(newfit)
restore

* sample average
tabulate messages, summarize(primary2008)

* linear regression without intercept
regress primary2008 ibn.messages, noconstant

* estimated average effect of "Neighbors" condition
display _b[4.messages] - _b[2.messages]

* difference-in-means
summarize primary2008 if messages == 4, meanonly
scalar neigh = r(mean)
summarize primary2008 if messages == 2, meanonly
scalar control = r(mean)
display neigh - control

display e(r2)
display e(r2_a)

*************************************************************
/** 4.3.3 Heterogeneous Treatment Effects **/
*************************************************************
* average treatment effect (ate) among those who voted in 2004 primary
summarize primary2008 if messages == 4 & primary2004 == 1, meanonly
scalar voteneigh = r(mean)
summarize primary2008 if messages == 2 & primary2004 == 1, meanonly
scalar votecontrol = r(mean)
scalar atevoter =  voteneigh - votecontrol
display atevoter
local atevoter = `=round(scalar(atevoter)*100,.1)'

* average effect among those who did not vote
summarize primary2008 if messages == 4 & primary2004 == 0, meanonly
scalar nonneigh = r(mean)
summarize primary2008 if messages == 2 & primary2004 == 0, meanonly
scalar noncontrol = r(mean)
scalar atenonvoter =  nonneigh - noncontrol
display atenonvoter

* difference
display atevoter - atenonvoter
local atedif = `=round(scalar(atevoter) - scalar(atenonvoter)*100 ,.1)'

regress primary2008 i.primary2004##i.messages if messages == 2 | messages == 4

regress primary2008 i.primary2004 i.messages i.primary2004#i.messages if messages == 2 | messages == 4

generate age = 2008 - yearofbirth
summarize age 
local min = `=r(min)'
local max = `=r(max)'

regress primary2008 c.age##i.messages if messages == 2 | messages == 4
local coef = round(_b[4.messages#c.age]*100,.02)

* age = 25, 45, 65, 85 in Neighbors group
margins, at(age=(25(20)85)) dydx(messages)

regress primary2008 (c.age##c.age)##i.messages if messages == 2 | messages == 4

quietly regress primary2008 (c.age##c.age)##i.messages if messages == 2 | messages == 4
* plotting the predicted turnout rate under each condition
margins, at(age=(25/85) messages=(2 4))
marginsplot, recast(line) noci xtitle("Age") ytitle("Predicted turnout rate") ///
	title("") text(.3 65 "Control condition") text(.42 35 "Neighbors condition") ///
	legend(off) name(margins1, replace) 
* average treatment effect as a function of age
margins, at(age=(25/85)) dydx(messages) 
marginsplot, recast(line) noci ylabel(0(.02).1) ///
  title("") xtitle("Age") ytitle("Estimated average treatment effect") ///
  name(margins2, replace)
 graph combine margins1 margins2

*************************************************************
/** 4.3.4 Regression Discontinuity Design **/
*************************************************************
* load the data
use MPs, clear
scatter lnnet margin if party=="labour", xline(0, lpattern(dash) lcolor(black)) ///
	xlabel(-.5(.2).5) ylabel(6(2)18) msymbol(oh) || ///
 	lfit lnnet margin if party == "labour" & margin < 0, lcolor(red) ||  ///
	lfit lnnet margin if party == "labour" & margin > 0, lcolor(red) title("Labour")  ///
	xtitle("Margin of victory") ytitle("Log net wealth at death") ///
	legend(off) name(labour, replace)
scatter lnnet margin if party == "tory", xline(0, lpattern(dash) lcolor(black)) ///
	xlabel(-.5(.2).5) ylabel(6(2)18) msymbol(oh)  || ///
	lfit lnnet margin if party == "tory" & margin < 0, lcolor(red) || ///
	lfit lnnet margin if party == "tory" & margin > 0 ,lcolor(red) title("Tory") ///
	xtitle("Margin of victory") ytitle("Log net wealth at death") ///
	legend(off) name(tory, replace)

* average net wealth for Tory MP
quietly regress lnnet margin if party=="tory" & margin > 0
margins, at((max) margin)
generate torymp = exp(_b[_cons])
	
* average net wealth for Tory non-MP
quietly regress lnnet margin if party=="tory" & margin < 0
margins, at((min) margin)
generate torynonmp = exp(_b[_cons])

* causal effect in pounds
summarize torymp torynonmp
display torymp - torynonmp

* two regressions for Tory: negative and positive margin
quietly regress marginpre margin if party=="tory" & margin < 0
scalar toryneg = _b[_cons]
quietly regress marginpre margin if party=="tory" & margin > 0
scalar torypos= _b[_cons]
* the difference between two intercepts is the estimated effect
display torypos - toryneg

***********************************************************	
/*** Return to main qss directory ***/
***********************************************************
cd ..
graph close _all
