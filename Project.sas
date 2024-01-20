/*code for importing data from excel sheet into sas session*/
FILENAME REFFILE '/home/u63727923/project.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.PROJECT;
	GETNAMES=YES;
RUN;

/*summary stat for age*/
data project1;
    set project;
    format dob1 date9.;
    /*creating new variable for date of birth*/
   dob=compress(cat(month, '/', day, '/', year));
   dob1=input(dob, mmddyy10.);
   /*creating a new variable for age*/
   age=(diagdt-dob1)/365;
   
   output;
   trt=2;
   output;
run;
/*summary parameters for age*/
proc sort data=project1;
by trt;
run;

proc means data=project1 noprint;
var age;
output out=agestats;
by trt;
run;

data agestats;
    set agestats;
    length value $10.;
    ord=1;
    if _stat_='N' then do; subord=1; value=strip(put(age, 8.));end;
    else if _stat_='MEAN' then do; subord=2; value=strip(put(age, 8.1));end;
    else if _stat_='STD' then do; subord=3; value=strip(put(age, 8.2));end;
    else if _stat_='MIN' then do; subord=4; value=strip(put(age, 8.1));end;
    else if _stat_='MAX' then do; subord=5; value=strip(put(age, 8.1));end;
    rename _stat_=stat;
    drop _type_ _freq_ age;
run;

/*summary stat for age group*/
data project2;
    set project1;
    length agegroup $15;
    if age<=18 then agegroup='<=18 years';
    else if 18<age<65 then agegroup='18 to 65 years';
    else if age>65 then agegroup='>65 years';
run;


/*summary parameters for agegroup*/

proc freq data=project2 noprint;
table trt*agegroup / outpct out=agegrpstats;
run;

data agegrpstats;
    set agegrpstats;
    value=cat(count, ' (', strip(put(round(pct_row,.1),8.1)), '%)');
    ord=2;
    if agegroup='<=18 years' then subord=1;
    else if agegroup='18 to 65 years' then subord=2;
    else if agegroup='>65 years' then subord=3;
    rename agegroup=stat;
    drop count percent pct_row pct_col;
run;

/*summary stat for gender*/
proc format;
value genfmt
1='Male'
2='Female'
;
run;

data project3;
    set project2;
    sex=put(gender, genfmt.);
run;

proc freq data=project3 noprint;
table trt*sex / outpct out=genderstats;
run;

data genderstats;
    set genderstats;
    value=cat(count, ' (', strip(put(round(pct_row,.1),8.1)), '%)');
    ord=3;
    if sex='Male' then subord=1;
    else subord=2;
    rename sex=stat;
    drop count percent pct_row pct_col;
run;

/*summary stat for race*/
proc format;
value racefmt
1='White'
2='Black'
3='Hispanic'
4='Asian'
5='Other'
;
run;

data project4;
    set project3;
    racec=put(race, racefmt.);
run;

proc freq data=project4 noprint;
table trt*racec / outpct out=racestats;
run;

data racestats;
    set racestats;
    value=cat(count, ' (', strip(put(round(pct_row,.1),8.1)), '%)');
    ord=4;
    if racec='Asian' then subord=1;
    else if racec='Black' then subord=2;
    else if racec='Hispanic' then subord=3;
    else if racec='White' then subord=4;
    else if racec='Other' then subord=5;
    
    rename racec = stat;
    drop count percent pct_row pct_col;
run;

/*appending allstat together*/
data allstats;
    set agestats agegrpstats genderstats racestats;
run;

/*transposing datanby treatment groups*/
proc sort data=allstats;
by ord subord stat;
run;

proc transpose data=allstats out=t_allstats prefix=_;
var value;
id trt;
by ord subord stat;
run;

data final;
length stat $30;
    set t_allstats;
    by ord subord;
    output;
    if first.ord then do; 
       if ord=1 then stat='Age(years)';
       if ord=2; then stat='Age Groups';
       if ord=3; then stat='Gender';
       if ord=4; then stat='Race';
       subord=0;
       _0='';
       _1='';
       _2='';
    output;
    end;
    
proc sort;
by ord subord;
run;    
    
proc sql noprint;
select count(*) into :placebo from project1 where trt=0;
select count(*) into :active from project1 where trt=1;
select count(*) into :total from project1 where trt=2;
quit;

%let placebo=&placebo;
%let active=&active;
%let total=&total;

/*constructing final report*/
title 'Table 1.1';
title2 'Demographic and Baseline Characteristics by Treatment Group';
title3 'Randomized Population';
footnote 'Note: Percentages are based on the number of non-missing values in each treatment group.';

proc report data=final split='|';
columns ord subord stat _0 _1 _2;
define ord/ noprint order;
define subord/ noprint order;
define stat / display width =50 "" ;
define _0 / display width =30 "Placebo| (N=&placebo)";
define _1 / display width =30 "Active Treatment| (N=&active)";
define _2 / display width =30 "All Patients| (N=&total)";
run; 



