**FREE
// =====================================================================
// ARR230 - Post customer payments                (stage 3: service pgm)
//
// Stage 1 program ARR210 with the business rules taken out: validation,
// how much goes to an invoice and the hold release now come from
// service program ARSRV (unit tested by ARSRVT). This program only
// reads and updates the files.
// =====================================================================
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio)
        bnddir('ARBNDDIR');

dcl-f ARPAYP   usage(*update) keyed;
dcl-f ARCUSTP  usage(*update) keyed;
dcl-f ARINVL1  usage(*update) keyed;

/copy QRPGLESRC,ARSRVPR

dcl-c PAY_NEW     ' ';
dcl-c PAY_POSTED  'P';
dcl-c PAY_ERROR   'E';
dcl-c INV_OPEN    'O';
dcl-c INV_PAID    'P';

read ARPAYR;
dow not %eof(ARPAYP);
  if PYSTS = PAY_NEW;
    postPayment();
  endif;
  read ARPAYR;
enddo;

*inlr = *on;
return;

// ---------------------------------------------------------------------
dcl-proc postPayment;
  dcl-s found ind;
  dcl-s error varchar(30);
  dcl-s remaining packed(9:2);

  // the legacy program only looks for the customer when the amount is
  // valid; keep that order (the CHAIN locks the customer record)
  if PYAMT > 0;
    chain PYCUST ARCUSTR;
    found = %found(ARCUSTP);
  endif;

  error = AR_validatePayment(PYAMT : found);
  if error <> '';
    PYSTS = PAY_ERROR;
    PYMSG = error;
    update ARPAYR;
    return;
  endif;

  remaining = applyToInvoices(PYCUST : PYAMT : PYDATE);

  CUBAL -= PYAMT;
  CUSTAT = AR_customerStatus(CUSTAT : CUBAL);
  update ARCUSTR;

  PYSTS = PAY_POSTED;
  PYMSG = *blanks;
  if remaining > 0;
    PYMSG = AR_MSG_UNAPPLIED;
  endif;
  update ARPAYR;
end-proc;

// ---------------------------------------------------------------------
// Oldest due date first (ARINVL1 key: customer, due date, invoice)
// ---------------------------------------------------------------------
dcl-proc applyToInvoices;
  dcl-pi *n packed(9:2);
    customer like(PYCUST) const;
    amount   like(PYAMT) const;
    payDate  like(PYDATE) const;
  end-pi;

  dcl-s remaining packed(9:2);
  dcl-s applied packed(9:2);

  remaining = amount;
  setll customer ARINVR;
  reade customer ARINVR;

  dow not %eof(ARINVL1) and remaining > 0;
    if INSTS = INV_OPEN;
      applied = AR_applyAmount(remaining : INAMT - INPAID);
      INPAID += applied;
      remaining -= applied;
      if INPAID = INAMT;
        INSTS = INV_PAID;
      endif;
      INLPDT = payDate;
      update ARINVR;
    endif;
    reade customer ARINVR;
  enddo;

  return remaining;
end-proc;
