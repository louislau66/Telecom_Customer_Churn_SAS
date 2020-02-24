
PROC IMPORT OUT= RAWDATA DATAFILE= "C:\Users\Louis\Documents\Metro college\DSP SAS Project 17 Jun 2019\Project Data Files\Project Data Files\2. Teleco Churn Data Analysis\datasets-for-churn-telecom\Telco Churn Data.csv" 
     DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
     GUESSINGROWS=50; 
RUN;

/*+++++++++++++++++++++++++++++++++++++++++++++*/
/* 1. +++++++++++Exploring Data+++++++++++++++*/
/*+++++++++++++++++++++++++++++++++++++++++++++*/
/*++ Variable list++*/
PROC CONTENTS DATA=RAWDATA;
RUN; 
/*++Missing Data++*/
PROC MEANS DATA=RAWDATA N NMISS;
RUN;
PROC FREQ DATA=RAWDATA;
TABLE _CHARACTER_/MISSING;
RUN; 
/*++Drop numeric columns with high percentage of missing values++*/
PROC SQL;
CREATE TABLE CHURN AS
SELECT *
FROM RAWDATA(DROP=MaritalStatus HandsetPrice)
WHERE PercChangeMinutes NE . AND Handsets NE .;
;
QUIT;

/*+++++++++++++++++++++++++++++++++++++++++++++*/
/*    break down dataset into Train & Test     */
/*+++++++++++++++++++++++++++++++++++++++++++++*/
PROC SURVEYSELECT DATA=CHURN OUT=CHURN_TRAIN_TEST OUTALL METHOD=SRS SAMPRATE=.7;
RUN;
DATA CHURN_TRAIN CHURN_TEST;
SET CHURN_TRAIN_TEST;
IF Selected=1 THEN  OUTPUT CHURN_TRAIN; ELSE  OUTPUT CHURN_TEST;
RUN;
DATA CHURN_TRAIN;
SET CHURN_TRAIN;
DROP Selected;
RUN;
DATA CHURN_TEST;
SET CHURN_TEST;
DROP Selected;
RUN; 

/*+++++++++++++++++++++++++++++++++++++++++++*/
/*++  2 Monthly Revenue Linear Regression  ++*/
/*+++++++++++++++++++++++++++++++++++++++++++*/
/*Monthly Revenue CORR study*/
PROC CORR DATA=CHURN_TRAIN; 
  VAR MonthlyRevenue OverageMinutes DirectorAssistedCalls PercChangeMinutes PercChangeRevenues DroppedCalls RoamingCalls TotalRecurringCharge MonthlyMinutes;
RUN;
PROC SGSCATTER DATA=CHURN_TRAIN;
  MATRIX MonthlyRevenue OverageMinutes DirectorAssistedCalls PercChangeMinutes PercChangeRevenues DroppedCalls RoamingCalls TotalRecurringCharge MonthlyMinutes /diagonal= (histogram normal);
RUN;

PROC SGSCATTER DATA=CHURN_TRAIN;
  MATRIX MonthlyRevenue OverageMinutes RoamingCalls TotalRecurringCharge MonthlyMinutes /diagonal= (histogram normal);
RUN;
PROC REG DATA=CHURN_TRAIN PLOTS(ONLY)=ALL;
	Linear_Regression_Model: MODEL MonthlyRevenue = OverageMinutes DirectorAssistedCalls PercChangeMinutes 
    PercChangeRevenues DroppedCalls RoamingCalls TotalRecurringCharge MonthlyMinutes/SELECTION=STEPWISE
	SLE=0.3  SLS=0.3 INCLUDE=0 COLLIN VIF SPEC DW;
RUN;
DATA CHURN_PREDICT;
   SET CHURN_TEST;
   PREDICT=4.23977+0.82524*TotalRecurringCharge+0.29291*OverageMinutes+1.01446*RoamingCalls;
   KEEP MonthlyRevenue PREDICT;
RUN; 
PROC SGPLOT DATA=CHURN_PREDICT;
  SCATTER X=MonthlyRevenue Y=PREDICT;
RUN; 
PROC CORR DATA=CHURN_PREDICT;
VAR MonthlyRevenue PREDICT;
RUN; 


/*+++++++++++++++++++++++++++++++++++++++*/
/*++  2 Churn   Logistic Regression    ++*/
/*+++++++++++++++++++++++++++++++++++++++*/
/*Drop missing values*/
PROC SQL;
CREATE TABLE LOGISTIC_TRAIN AS
SELECT *
FROM CHURN_TRAIN
WHERE AgeHH1 NE . AND CHURN NE "NA"
;
QUIT;
PROC SQL;
CREATE TABLE LOGISTIC_TEST AS
SELECT *
FROM CHURN_TEST
WHERE AgeHH2 NE .  AND CHURN NE "NA"
;
QUIT;

/*Standardize numeric columns*/
PROC STANDARD DATA=LOGISTIC_TRAIN OUT=LOGISTIC_TRAIN_STND MEAN=0 STD=1 ;
  VAR _NUMERIC_;
RUN;
PROC STANDARD DATA=LOGISTIC_TEST OUT=LOGISTIC_TEST_STND MEAN=0 STD=1 ;
  VAR _NUMERIC_;
RUN;
/*Logistic Regression - Model*/
PROC LOGISTIC DATA=LOGISTIC_TRAIN_STND (DROP = customerid) ;
	CLASS  ChildrenInHH 	(PARAM=EFFECT) HandsetRefurbished 	(PARAM=EFFECT) NewCellphoneUser 	(PARAM=EFFECT)  MadeCallToRetentionTeam 	(PARAM=EFFECT) CreditRating 	(PARAM=EFFECT) PrizmCode 	(PARAM=EFFECT) Occupation 	(PARAM=EFFECT)
	  NotNewCellphoneUser 	(PARAM=EFFECT) HandsetWebCapable 	(PARAM=EFFECT) TruckOwner 	(PARAM=EFFECT) OwnsMotorcycle 	(PARAM=EFFECT) RVOwner 	(PARAM=EFFECT)
	  BuysViaMailOrder 	(PARAM=EFFECT) RespondsToMailOffers 	(PARAM=EFFECT) OptOutMailings 	(PARAM=EFFECT) NonUSTravel 	(PARAM=EFFECT) OwnsComputer 	(PARAM=EFFECT) HasCreditCard 	(PARAM=EFFECT);
	MODEL Churn (EVENT="Yes") = _NUMERIC_  ChildrenInHH HandsetRefurbished  NewCellphoneUser  MadeCallToRetentionTeam  CreditRating PrizmCode 	Occupation 	
      NotNewCellphoneUser HandsetWebCapable 	TruckOwner OwnsMotorcycle 	 RVOwner 	 	
	  BuysViaMailOrder 	 RespondsToMailOffers 	 OptOutMailings 	 NonUSTravel 	 OwnsComputer 	HasCreditCard /
	SELECTION=stepwise MAXSTEP=30 SLE=1E-05 SLS=1E-05 EXPB STB LACKFIT;
	STORE churn_logistic;
RUN;


/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*++++    Univariate & Bivariate analysis     +++++++++++++++*/
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*Churn distribution*/
DATA CHURN;
SET CHURN;
IF CHURN="Yes" then CHURN_=1;
ELSE IF CHURN="No" then CHURN_=2;
ELSE CHURN_=0;
RUN; 

PROC FORMAT;
VALUE order 1="Yes"
            2="No"
			0="NA"
			;
RUN; 
PROC GCHART DATA=CHURN;
PIE3D CHURN/DISCRETE VALUE=INSIDE PERCENT=OUTSIDE SLICE=OUTSIDE;
WHERE CHURN NE "NA";
RUN; 
/*Churn by MadeCallToRetentionTeam & # of RetentionCalls*/
PROC FREQ DATA=CHURN;
TABLE MadeCallToRetentionTeam*CHURN/MISSING NOCOL;
WHERE CHURN NE "NA";
RUN; 
PROC GCHART DATA=CHURN;
    WHERE CHURN NE "NA";
	BLOCK Churn/GROUP=MadeCallToRetentionTeam SHAPE=BLOCK TYPE=PCT G100 COUTLINE=BLACK PATTERNID=GROUP;
RUN; 
DATA TEMP;
SET CHURN; 
IF RetentionCalls=1 		THEN RetentionCalls_="1";
ELSE IF RetentionCalls=2	THEN RetentionCalls_="2";
ELSE IF RetentionCalls=3 	THEN RetentionCalls_="3";
ELSE IF RetentionCalls=4 	THEN RetentionCalls_="4";
ELSE RetentionCalls_="0";
IF RetentionOffersAccepted=1		THEN RetentionOffersAccepted_="1";
ELSE IF RetentionOffersAccepted=2 	THEN RetentionOffersAccepted_="2";
ELSE IF RetentionOffersAccepted=3 	THEN RetentionOffersAccepted_="3";
ELSE IF RetentionOffersAccepted=4 	THEN RetentionOffersAccepted_="4";
ELSE RetentionOffersAccepted_="0";
RUN;
PROC GCHART DATA=TEMP;
    WHERE CHURN NE "NA";
	BLOCK RetentionOffersAccepted_/GROUP=RetentionCalls_ SHAPE=BLOCK TYPE=PCT G100 COUTLINE=BLACK PATTERNID=GROUP;
RUN; 

PROC FREQ DATA=CHURN;
   TABLE RetentionCalls*RetentionOffersAccepted/MISSING NOPERCENT NOCOL;
RUN; 

/*+++When to make retention call?+++*/
/*Churn by MonthInService*/
PROC SGPLOT DATA=CHURN;
HISTOGRAM  MonthsInService;
XAXIS VALUES=(4 TO 40 BY 2);
WHERE Churn='Yes';
RUN; 

/*Churn by CurrentEquipmentDays*/
PROC SGPLOT DATA=CHURN;
HISTOGRAM  CurrentEquipmentDays;
XAXIS VALUES=(0 TO 1000 BY 20);
WHERE Churn='No';
RUN; 

/*MonthsInService vs. CurrentEquipmentDays*/
PROC CORR DATA=Churn;
  VAR MonthsInService CurrentEquipmentDays;
RUN; 
PROC SGPLOT DATA=churn;
SCATTER X=MonthsInService Y=CurrentEquipmentDays;
RUN;  

/*Equipment day by Age*/
PROC UNIVARIATE DATA=CHURN;
VAR CurrentEquipmentDays;
run;
PROC HPBIN DATA=CHURN OUTPUT=TEST NUMBIN=52 BUCKET;
  INPUT CurrentEquipmentDays;
  CODE FILE="C:\Users\Louis\Documents\Metro college\DSP SAS Project 17 Jun 2019\EquipBincode.sas";
RUN;
DATA EQUIPBIN;
SET CHURN;
%INCLUDE "C:\Users\Louis\Documents\Metro college\DSP SAS Project 17 Jun 2019\EquipBincode.sas";
RUN; 
PROC SORT DATA=EQUIPBIN OUT=TEMP;
by bin_currentequipmentdays;
run;
PROC SGPLOT DATA=TEMP;
VBOX AgeHH1/GROUP=bin_currentequipmentdays;
RUN; 

/*Churn by Age*/
PROC HPBIN DATA=Churn OUTPUT=TEST NUMBIN=10 BUCKET;
  INPUT AGEHH1;
  WHERE AGEHH1 NE 0;
  CODE FILE="C:\Users\Louis\Documents\Metro college\DSP SAS Project 17 Jun 2019\AgeBincode.sas";
RUN;
DATA TEMP;
SET CHURN;
WHERE CHURN NE "NA";
%INCLUDE "C:\Users\Louis\Documents\Metro college\DSP SAS Project 17 Jun 2019\AgeBincode.sas";
WHERE AGEHH1 NE 0;
RUN; 

PROC FORMAT;
  VALUE AgeGrp 	LOW - < 26.1   		= "AgeHH1 < 26.1"
    			26.1 - < 34.2 = "26.1 <= AgeHH1 < 34.2"
    			34.2 - < 42.3 = "34.2 <= AgeHH1 < 42.3"
   				42.3 - < 50.4 = "42.3 <= AgeHH1 < 50.4"
    			50.4 - < 58.5 = "50.4 <= AgeHH1 < 58.5"
    			58.5 - < 66.6 = "58.5 <= AgeHH1 < 66.6"
    			66.6 - < 74.7 = "66.6 <= AgeHH1 < 74.7"
    			74.7 - < 82.8 = "74.7 <= AgeHH1 < 82.8"
    			82.8 - < 90.9 = "82.8 <= AgeHH1 < 90.9"
    			90.9 - HIGH  	= "90.9 <= AgeHH1" 
                ;
RUN;  

PROC SGPLOT DATA=CHURN;
VBAR  AgeHH1;
WHERE Churn="Yes" AND AgeHH1 ne 0;
FORMAT AgeHH1 AgeGrp.;
RUN;
PROC SORT DATA=Churn OUT=SORT;
BY AgeHH1; 
WHERE Churn NE "NA" and AgeHH1 NE 0;
FORMAT AgeHH1 AgeGrp.;
RUN;
PROC FREQ DATA=SORT noprint;
BY AgeHH1;                  
TABLE Churn_  / OUT=FreqOut;    
FORMAT Churn_ order.;
RUN;
PROC SGPLOT DATA=FreqOut;
VBAR AgeHH1 / RESPONSE=Percent  GROUP=Churn_ GROUPDISPLAY=stack;
YAXIS GRID VALUES=(0 TO 100 BY 5) LABEL="Percentage of Total with Group";
RUN;
PROC SQL;
CREATE TABLE AgeDiffTbl as
SELECT AgeHH1-AgeHH2 as AgeDiff
FROM CHURN
WHERE AgeHH1 NE . AND AgeHh2 NE .
;
QUIT;
PROC SGPLOT DATA=AgeDiffTbl;
HISTOGRAM AgeDiff;
XAXIS VALUES=(-40 to 80 by 5);
RUN; 

/*People with professional job and good credit score will contribute higher MonthlyRevenue???*/
/*Monthly Revenue by CreditRating*/
PROC FREQ DATA=CHURN;
 TABLE CreditRating;
RUN; 
PROC SGPLOT DATA=Churn;
 VBOX MonthlyRevenue / GROUP=CreditRating;
 YAXIS VALUES=(0 to 120 by 5);
RUN; 

/*CHURN BY CreditRating*/
PROC FREQ DATA=CHURN;
TABLE CHURN*CreditRating/MISSING NOROW;
WHERE CHURN NE "NA";
RUN; 
PROC SORT DATA=CHURN OUT=SORT;
BY CreditRating; 
WHERE Churn NE "NA";
RUN;
PROC FREQ DATA=sort noprint;
BY CreditRating;                  
TABLE Churn_  / OUT=FreqOut;    
FORMAT Churn_ order.; 
RUN;
PROC SGPLOT DATA=FreqOut;
VBAR CreditRating / RESPONSE=Percent  GROUP=Churn_ GROUPDISPLAY=stack;
YAXIS GRID VALUES=(0 TO 100 BY 5) LABEL="Percentage of Total with Group";
RUN;

/*Monthly Revenue by Occupation*/
PROC FREQ DATA=CHURN;
 TABLE Occupation;
RUN; 
PROC SGPLOT DATA=Churn;
 VBOX MonthlyRevenue / GROUP=Occupation;
 YAXIS VALUES=(0 to 120 by 5);
RUN; 
/*Churn by Occupation*/
PROC FREQ DATA=CHURN;
TABLE CHURN*CreditRating/MISSING NOROW;
WHERE CHURN NE "NA";
RUN; 
PROC SORT DATA=CHURN OUT=SORT;
BY Occupation; 
WHERE Churn NE "NA";
RUN;
 
PROC FREQ DATA=sort noprint;
BY Occupation;                  
TABLE Churn_  / OUT=FreqOut;    
FORMAT Churn_ order.; 
RUN;
PROC SGPLOT DATA=FreqOut;
VBAR Occupation / RESPONSE=Percent  GROUP=Churn_ GROUPDISPLAY=stack;
YAXIS GRID VALUES=(0 TO 100 BY 5) LABEL="Percentage of Total with Group";
RUN;

/*Customer distribution by region*/
DATA TEST;
 SET CHURN;
 REGION=SUBSTR(ServiceArea,1,3);
RUN; 
PROC FREQ DATA=TEST ORDER=FREQ;
TABLE REGION;
RUN; 


/*+++Churn vs. HandsetRefurbished+++*/
PROC FREQ DATA=CHURN;
TABLE CHURN*HandsetRefurbished/MISSING;
WHERE CHURN NE "NA";
RUN; 

PROC GCHART DATA =Churn;
	PIE Churn /SUBGROUP=HandsetRefurbished TYPE=PCT LEGEND=LEGEND1 SLICE=OUTSIDE PERCENT=INSIDE VALUE=NONE NOHEADING;
	WHERE Churn NE "NA";
RUN; 

