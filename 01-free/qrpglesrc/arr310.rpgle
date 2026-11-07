**FREE
// =====================================================================
// ARR310 - Aged trial balance                         (stage 1: free)
//
// The legacy ARR300 relies on the RPG cycle (primary file, L1 control
// level, O-specs). Fully free RPG has no I- or O-specs, so the cycle
// is replaced by an explicit read loop with a customer break, and the
// printed lines come from an externally described printer file ARR310P
// whose layout is generated from the same table as the old O-specs.
// The spooled output must be identical to ARR300 line by line.
//
// Parameter: as-of date, 8 characters YYYYMMDD.
// =====================================================================
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio);

dcl-f ARINVL1  usage(*input) keyed;
dcl-f ARCUSTP  usage(*input) keyed;
dcl-f ARR310P  printer oflind(overflow);

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
// First invoice of a customer: reset its totals, get its name
// ---------------------------------------------------------------------
dcl-proc startCustomer;
  currentCustomer = INCUST;
  T1CUR = 0;
  T1030 = 0;
  T1060 = 0;
  T1090 = 0;
  T1OVR = 0;
  T1TOT = 0;

  chain INCUST ARCUSTR;
  if not %found(ARCUSTP);
    // KNOWN DEFECT, kept on purpose in stage 1 (pure refactor, output
    // must match the legacy program): like MOVEL in ARR300 this only
    // overlays the first 9 characters, and CUCUST still holds the
    // previous customer. Fixed in stage 3, covered by a unit test.
    %subst(CUNAME : 1 : 9) = '*UNKNOWN*';
  endif;
end-proc;

// ---------------------------------------------------------------------
// One invoice: put its open amount into an age bucket and print it
// ---------------------------------------------------------------------
dcl-proc processInvoice;
  if INSTS <> INV_OPEN;
    return;
  endif;

  WOPEN = INAMT - INPAID;
  WDAYS = %diff(asOfDate : %date(INDUE : *iso) : *days);

  D1CUR = 0;
  D1030 = 0;
  D1060 = 0;
  D1090 = 0;
  D1OVR = 0;

  select;
    when WDAYS <= 0;
      D1CUR = WOPEN;
      T1CUR += WOPEN;
    when WDAYS <= 30;
      D1030 = WOPEN;
      T1030 += WOPEN;
    when WDAYS <= 60;
      D1060 = WOPEN;
      T1060 += WOPEN;
    when WDAYS <= 90;
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
// Last invoice of a customer: print its total, roll into grand total
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
