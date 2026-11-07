**FREE
// =====================================================================
// ARR210 - Post customer payments                     (stage 1: free)
//
// Same rules and same files as the legacy ARR200, rewritten in fully
// free-format RPG: no numbered indicators, no GOTO/TAG, no KLIST,
// built-in functions (%EOF, %FOUND) instead of resulting indicators.
// Behaviour is unchanged - the regression run compares every row.
//
// Rules: every new payment (PYSTS = ' ') is applied to the customer's
// open invoices, oldest due date first. Amount <= 0 or unknown customer
// -> PYSTS 'E'. Money left after all invoices = unapplied credit.
// A customer on hold is released when the balance drops to <= 0.
// =====================================================================
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio);

dcl-f ARPAYP   usage(*update) keyed;
dcl-f ARCUSTP  usage(*update) keyed;
dcl-f ARINVL1  usage(*update) keyed;

dcl-c MSG_INVALID_AMOUNT   'INVALID AMOUNT';
dcl-c MSG_NO_CUSTOMER      'CUSTOMER NOT FOUND';
dcl-c MSG_UNAPPLIED        'UNAPPLIED CREDIT';

dcl-c PAY_NEW     ' ';
dcl-c PAY_POSTED  'P';
dcl-c PAY_ERROR   'E';
dcl-c INV_OPEN    'O';
dcl-c INV_PAID    'P';
dcl-c CUST_HOLD   'H';
dcl-c CUST_ACTIVE 'A';

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
// Post the payment that is in the ARPAYR record buffer
// ---------------------------------------------------------------------
dcl-proc postPayment;
  dcl-s remaining packed(9:2);

  PYMSG = *blanks;

  if PYAMT <= 0;
    rejectPayment(MSG_INVALID_AMOUNT);
    return;
  endif;

  chain PYCUST ARCUSTR;
  if not %found(ARCUSTP);
    rejectPayment(MSG_NO_CUSTOMER);
    return;
  endif;

  remaining = applyToInvoices(PYCUST : PYAMT : PYDATE);

  CUBAL -= PYAMT;
  if CUSTAT = CUST_HOLD and CUBAL <= 0;
    CUSTAT = CUST_ACTIVE;
  endif;
  update ARCUSTR;

  PYSTS = PAY_POSTED;
  if remaining > 0;
    PYMSG = MSG_UNAPPLIED;
  endif;
  update ARPAYR;
end-proc;

// ---------------------------------------------------------------------
// Mark the current payment as rejected
// ---------------------------------------------------------------------
dcl-proc rejectPayment;
  dcl-pi *n;
    message varchar(30) const;
  end-pi;

  PYSTS = PAY_ERROR;
  PYMSG = message;
  update ARPAYR;
end-proc;

// ---------------------------------------------------------------------
// Apply an amount to the open invoices of one customer, oldest due
// date first (ARINVL1 key: customer, due date, invoice).
// Returns what is left over.
// ---------------------------------------------------------------------
dcl-proc applyToInvoices;
  dcl-pi *n packed(9:2);
    customer like(PYCUST) const;
    amount   like(PYAMT) const;
    payDate  like(PYDATE) const;
  end-pi;

  dcl-s remaining packed(9:2);
  dcl-s openAmount packed(9:2);
  dcl-s applied packed(9:2);

  remaining = amount;
  setll customer ARINVR;
  reade customer ARINVR;

  dow not %eof(ARINVL1) and remaining > 0;
    if INSTS = INV_OPEN;
      openAmount = INAMT - INPAID;
      if remaining >= openAmount;
        applied = openAmount;
        INSTS = INV_PAID;
      else;
        applied = remaining;
      endif;
      INPAID += applied;
      remaining -= applied;
      INLPDT = payDate;
      update ARINVR;
    endif;
    reade customer ARINVR;
  enddo;

  return remaining;
end-proc;
