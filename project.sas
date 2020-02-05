
data customers;
infile "C:\Users\Louis\Documents\ASP\MINI PROJECT\New_Wireless_Fixed.txt";
Label Acctno ="Account number" Actdt ="Activation date" Deactdt ="Deactivation date" DeactReason ="Reason for deactivation" GoodCredit ="Credit is good or not" RetePlan ="Rate Plan" DealerType ="Dealer Type";
input  @1 Acctno 13.
       @15 Actdt mmddyy10.
	   @26 Deactdt mmddyy10.
	   @41 DeactReason $4. 
	   @53 GoodCredit 1.
	   @62 RatePlan 1.
	   @65 DealerType $2.
	   @74 Age 2.
	   @80 Province $2.
	   @84 Sales dollar8.2 
       ;
format Acctno 13. Actdt mmddyy10. Deactdt mmddyy10. Sales dollar8.2;
run;

/* Explore the customers data */

title'Explore the customers data';
proc contents data=customers; run; 

proc print data=customers (obs=2) noobs label ; run; 

title 'Missing value in all numeric variables';
proc means data=customers NMISS N; run;


title 'Missing value in province & DealerType';
proc freq data=customers; 
tables province /missing missprint nocum nopercent;
where province is missing;
run;
proc freq data=customers; 
tables DealerType  /missing missprint nocum nopercent;
where DealerType is missing;
run;

title;
/* check if any duplicated acct#  */

proc univariate data=customers noprint;
var Acctno;
output out=acct_num n=n;
run;

data _null_;
set acct_num;
call symput('original',n);
run;

proc sort data=customers out=acct_nodup nodupkey;
by acctno;
run;


proc univariate data=acct_nodup noprint;
var acctno;
output out=acct_nodup n=n;
run;

data _null_;
set acct_nodup;
call symput('nodupacct',n);
run;

%put &original;
%put &nodupacct;

data duplication;
if &original=&nodupacct then result='There is no duplication';
else result='There is duplication';
run;


proc print data=duplication label noobs; 
label result='Acctno check';
run; 


/*Use mean of sales (181.25) to replace all missing values*/
proc means data=customers;
var sales;
run; 

data customers_update;
set customers;
if sales eq . then sales=181.25;
run; 


/*Deactivated Accounts info */
proc univariate data=customers noprint;
var Deactdt;
output out=Deact_account n=n min=min max=max;
run; 

proc print data=Deact_account noobs label;
title "Information of deactivated accounts";
format min mmddyy10. max mmddyy10.;
label n="# of deactivated accounts" min="Earlist deactivation" max="Latest deactivation";
run; 

/*Activate Accounts info */
proc univariate data=customers noprint;
var Actdt;
where Deactdt is missing;
output out=Act_account n=n min=min max=max;
run; 


proc print data=act_account noobs label;
title "Information of activate accounts";
format min mmddyy10. max mmddyy10.;
label n="# of activate accounts" min="Earlist activation" max="Latest activation";
run; 

title;

/*Format sale, age,  month and tenure group*/
proc format;
value Salegrp  low-<100 = 'Sales<100'
               100-<500 = '100-<500'
			   500-<800 = '500-<800'
			   800-high = '800 and above';
value agegrp   low-20 = 'Age <=20 '
               21-40  = '21-40'
			   41-60  = '41-60'
			   61-high= '61 and above';
value mthfmt   1='Jan'
               2='Feb'
			   3='Mar'
			   4='Apr'
			   5='May'
			   6='Jun'
			   7='Jul'
			   8='Aug'
			   9='Sep'
			   10='Oct'
			   11='Nov'
			   12='Dec';
value tenure   low-<30 ='Tenure<30 days'
               30-60  = '30-60 days'
			   61-365 = '61-one year'
			   366-high='Over one year';
run; 

/* Mark Deacivated and Active account. And set region for each province. */

data Account_type;
set customers_update;
format region $20.;
if Deactdt   then Acctype='Deactivated';
else              Acctype='Active';
     if province in ('BC','SK','AB') then region='West Provinces';
else if province in ('PE','NS','NB','NL') then region='Ocean Provinces';
else if province in ('MT','QC','ON') then region='Central Provinces';
run; 

/*1.2  What is the age and province distributions of active and deactivated customers?*/
proc tabulate data=account_type;
title 'Age and province distributions of active and deactivated customers';
class age province acctype;
format age agegrp.;
table province*(age all), acctype='Active or Deactivated'*(n='# of accounts' colpctn='% of column') all*(n pctn);
run;

/*1.3 Segment the customers based on age, province and sales amount
Create analysis report by using the attached Excel template.*/
proc tabulate data=account_type;
class acctype region province age sales;
table acctype='Account Type=' ,region=' ' * province=' '  all,age=' '*(n="Number of Accounts") *(sales=' ' ALL='Total');
format age agegrp. sales salegrp.;
run;

/*1.4.Statistical Analysis:
1) Calculate the tenure in days for each account and give its simple statistics.
Since 1/20/2001 is the date for latest activation, I used 2/8/2001 to caculate tenure day to allow some tenure fall into <30 days category. */

data tenure;
set account_type;
if acctype='Active' then tenure= ('08feb2001'd- Actdt);
else                     tenure= (Deactdt -Actdt);
run; 

/*Tenure statistical analysis*/
proc means data=tenure;
title 'Tenure statistical analysis ';
var tenure;
run; 


proc sgplot data=tenure;
hbox tenure/category=acctype;
run; 



/*2) Calculate the number of accounts deactivated for each month.*/
data dea_by_mth;
set tenure;
deamth=month(deactdt);
run; 

proc tabulate data=dea_by_mth;
title 'Number of accounts deactivated for each month ';
class deamth;
table deamth='',N='Number of deactivation'/box='Month';
format deamth mthfmt.;
run; 


/* Calculate the number of accounts activated for each month.*/
data act_by_mth;
set tenure;
actmth=month(Actdt);
where deactdt is missing;
run;

proc tabulate data=act_by_mth;
title 'Number of accounts active for each month ';
class actmth;
table actmth='',N='Number of activations'/box='Month';
format actmth mthfmt.;
run; 


/*3) Segment the account, first by account status “Active” and “Deactivated”, then by
Tenure: < 30 days, 31---60 days, 61 days--- one year, over one year. Report the
number of accounts of percent of all for each segment.*/

proc tabulate data=tenure;
title 'Account segment report by tenure days';
class acctype tenure;
table acctype=' ', tenure=' '*(n='# of accounts' ROWPCTN='% of accounts')/box='Account status';
format tenure tenure.;
run; 

/*4) Test the general association between the tenure segments and “Good Credit”
“RatePlan ” and “DealerType.”*/
proc tabulate data=tenure;
title "Association between the tenure segments and 'Good Credit''RatePlan ' and 'DealerType.'";
class tenure goodcredit rateplan dealertype;
table goodcredit='Credit status (1 Good 0 Bad)=', rateplan='Rate Plan'*dealertype all, tenure=' '*(n='# of accounts' pctn='% of total accounts') all;
format tenure tenure.;
run; 


proc tabulate data=tenure;
title 'Active & deactivated account distribution by dealertype';
class dealertype acctype ;
table acctype=' ', dealertype*(n='# of accounts')/box='Account Status';
run; 


/*5) Is there any association between the account status and the tenure segments?
Could you find out a better tenure segmentation strategy that is more associated
with the account status?*/
proc tabulate data=tenure;
title 'Account Status & Tenure';
class acctype tenure;
table acctype=' ', tenure=' '*(n='# of accounts')/box='Account Status';
format tenure tenure.;
run; 

proc format;
value tenurenew   low-<60 ='Tenure<60 days'
                  60-120  = '60-120 days'
                  121-180 = '121-180 days'
                  181-240 = '181-240 days'
			      241-300 = '241-300 days'
			      300-365 =  '300 days-1 year'
				  365-730= '1-2 yrs'
				  730-high='more than 2 yrs';
run;

proc tabulate data=tenure;
title 'Account Status & Tenure';
class acctype tenure;
table acctype=' ', tenure=' '*(n='# of accounts')/box='Account Status';
format tenure tenurenew.;
run; 

/*6) Does Sales amount differ among different account status, GoodCredit, and
customer age segments?*/
proc tabulate data=tenure;
title 'Profit segment by Account status, Credit status and Age';
class acctype Goodcredit age;
var sales;
format age agegrp.;
table Goodcredit,acctype='Account Status=' * (age all) all,sales*(N='# of accounts' colpctn='%' sum='profit') ;
run; 

/*study correlation coefficients see if we can build any model for predication*/

data testcoff;
set tenure;
     if acctype='Active' then num_acctype=1;
else                     num_acctype=0;
     if dealertype = 'A2'   then num_dealertype=1;
else if dealertype = 'C1'   then num_dealertype=2;
else if dealertype = 'B1'   then num_dealertype=3;
else if dealertype = 'A1'   then num_dealertype=4;
run; 


proc corr data=testcoff;
var num_acctype num_dealertype goodcredit age sales;
with num_acctype num_dealertype goodcredit age sales;
run;


