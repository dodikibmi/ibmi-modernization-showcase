**FREE
// =====================================================================
// ARR340 - Aged trial balance                          (stage 4: SQL)
//
// Stage 3 program ARR330 with native I/O replaced by one SQL query:
// open invoices LEFT JOIN customers (no CHAIN per customer; a missing
// customer comes back as NULL and is detected with a null indicator),
// read with a multi-row FETCH into a data structure array.
// Aging rules still come from service program ARSRV; the printer file
// ARR310P is unchanged, so the report must equal the stage 3 report.
//
// Parameter: as-of date, 8 characters YYYYMMDD.
// =====================================================================
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio)
        bnddir('ARBNDDIR');

dcl-f ARR310P printer oflind(overflow);

/copy QRPGLESRC,ARSRVPR

exec sql set option commit = *none, closqlcsr = *endmod, datfmt = *iso,
                    naming = *sys;

dcl-pi *n;
  asOfText char(8);
end-pi;

dcl-c ROWS_PER_FETCH 100;

dcl-ds invoice qualified dim(ROWS_PER_FETCH);
  customer    zoned(6:0);
  invoiceNo   zoned(7:0);
  invoiceDate zoned(8:0);
  dueDate     zoned(8:0);
  openAmount  packed(9:2);
  name        char(30);
end-ds;

// null indicators: one row per fetched row, one entry per column
dcl-ds nulls qualified dim(ROWS_PER_FETCH);
  ind int(5) dim(6);
end-ds;

dcl-s overflow ind inz(*off);
dcl-s asOfDate date(*iso);
dcl-s currentCustomer zoned(6:0);
dcl-s anyInvoice ind inz(*off);
dcl-s fetched int(10);
dcl-s i int(10);

WASOF = %dec(asOfText : 8 : 0);
asOfDate = %date(WASOF : *iso);
printHeadings();

exec sql declare openInvoices cursor for
  select i.CUSTOMER_ID, i.INVOICE_NO, i.INVOICE_DATE, i.DUE_DATE,
         i.AMOUNT - i.PAID, c.CUSTOMER_NAME
    from AR_INVOICES i
         left join AR_CUSTOMER c on c.CUSTOMER_ID = i.CUSTOMER_ID
   where i.INVOICE_STATUS = 'O'
   order by i.CUSTOMER_ID, i.DUE_DATE, i.INVOICE_NO;

exec sql open openInvoices;
dou fetched < ROWS_PER_FETCH;
  exec sql fetch next from openInvoices
             for :ROWS_PER_FETCH rows into :invoice :nulls;
  if sqlcode < 0;
    snd-msg *escape %msg('CPF9898' : 'QCPFMSG' : 'ARR340 fetch failed, SQLSTATE ' + sqlstate);
  endif;
  fetched = sqlerrd(3);
  for i = 1 to fetched;
    if not anyInvoice or invoice(i).customer <> currentCustomer;
      if anyInvoice;
        endCustomer();
      endif;
      startCustomer(i);
      anyInvoice = *on;
    endif;
    printInvoice(i);
  endfor;
enddo;
exec sql close openInvoices;

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
  dcl-pi *n;
    row int(10) const;
  end-pi;

  currentCustomer = invoice(row).customer;
  clear T1CUR;
  clear T1030;
  clear T1060;
  clear T1090;
  clear T1OVR;
  clear T1TOT;

  CUCUST = invoice(row).customer;
  // column 6 (customer name) is NULL when the LEFT JOIN found no customer
  CUNAME = AR_customerName(nulls(row).ind(6) = 0 : invoice(row).name);
end-proc;

// ---------------------------------------------------------------------
dcl-proc printInvoice;
  dcl-pi *n;
    row int(10) const;
  end-pi;

  ININV  = invoice(row).invoiceNo;
  INIDAT = invoice(row).invoiceDate;
  INDUE  = invoice(row).dueDate;
  WOPEN  = invoice(row).openAmount;
  WDAYS  = AR_daysPastDue(asOfDate : INDUE);

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
