**FREE
// =====================================================================
// ARR330 - Aged trial balance                    (stage 3: service pgm)
//
// Stage 1 program ARR310 with the aging rules taken from service
// program ARSRV, and the legacy *UNKNOWN* defect FIXED: an invoice of
// a customer missing from the master file now prints that customer's
// own number and the name '*UNKNOWN*' (before: the previous customer's
// number and '*UNKNOWN* (FICTIONAL)'). Test: ARSRVT.
// This is the only intended difference in the regression run.
//
// Parameter: as-of date, 8 characters YYYYMMDD.
// =====================================================================
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio)
        bnddir('ARBNDDIR');

dcl-f ARINVL1  usage(*input) keyed;
dcl-f ARCUSTP  usage(*input) keyed;
dcl-f ARR310P  printer oflind(overflow);

/copy QRPGLESRC,ARSRVPR

dcl-pi *n;
  asOfText char(8);
end-pi;

dcl-s overflow ind inz(*off);
dcl-s asOfDate date(*iso);
dcl-s currentCustomer like(INCUST);
dcl-s anyInvoice ind inz(*off);

dcl-c INV_OPEN 'O';

WASOF = %dec(asOfText : 8 : 0);
asOfDate = %date(WASOF : *iso);
printHeadings();

read ARINVR;
dow not %eof(ARINVL1);
  if not anyInvoice or INCUST <> currentCustomer;
    if anyInvoice;
      endCustomer();
    endif;
    startCustomer();
    anyInvoice = *on;
  endif;
  processInvoice();
  read ARINVR;
enddo;

if anyInvoice;
  endCustomer();
endif;
write TL;

*inlr = *on;
return;

// ---------------------------------------------------------------------
dcl-proc printHeadings;
  write H1;
  write H2;
  overflow = *off;
end-proc;

// ---------------------------------------------------------------------
dcl-proc startCustomer;
  dcl-s found ind;

  currentCustomer = INCUST;
  clear T1CUR;
  clear T1030;
  clear T1060;
  clear T1090;
  clear T1OVR;
  clear T1TOT;

  chain INCUST ARCUSTR;
  found = %found(ARCUSTP);
  CUCUST = INCUST;                       // fix: never the previous customer
  CUNAME = AR_customerName(found : CUNAME);
end-proc;

// ---------------------------------------------------------------------
dcl-proc processInvoice;
  if INSTS <> INV_OPEN;
    return;
  endif;

  WOPEN = INAMT - INPAID;
  WDAYS = AR_daysPastDue(asOfDate : INDUE);

  clear D1CUR;
  clear D1030;
  clear D1060;
  clear D1090;
  clear D1OVR;

  select AR_ageBucket(WDAYS);
    when-is AR_BUCKET_CURRENT;
      D1CUR = WOPEN;
      T1CUR += WOPEN;
    when-is AR_BUCKET_1_30;
      D1030 = WOPEN;
      T1030 += WOPEN;
    when-is AR_BUCKET_31_60;
      D1060 = WOPEN;
      T1060 += WOPEN;
    when-is AR_BUCKET_61_90;
      D1090 = WOPEN;
      T1090 += WOPEN;
    other;
      D1OVR = WOPEN;
      T1OVR += WOPEN;
  endsl;
  T1TOT += WOPEN;

  if overflow;
    printHeadings();
  endif;
  write D1;
end-proc;

// ---------------------------------------------------------------------
dcl-proc endCustomer;
  if T1TOT <> 0;
    if overflow;
      printHeadings();
    endif;
    write T1;
  endif;
  TLCUR += T1CUR;
  TL030 += T1030;
  TL060 += T1060;
  TL090 += T1090;
  TLOVR += T1OVR;
  TLTOT += T1TOT;
end-proc;
