**FREE
// =====================================================================
// ARR240 - Post customer payments                     (stage 4: SQL)
//
// Stage 3 program ARR230 with native record I/O replaced by embedded
// SQL on the tables AR_CUSTOMER, AR_INVOICES and AR_PAYMENTS (long
// names), and one transaction per payment: the customer, its invoices
// and the payment row are committed together or rolled back together.
// The legacy program had no commitment control - a failure halfway
// left an invoice paid and the customer balance unchanged.
// The tables are journaled (created in a library with QSQJRN).
// Business rules still come from service program ARSRV.
// =====================================================================
ctl-opt dftactgrp(*no) actgrp(*new) option(*srcstmt:*nodebugio)
        bnddir('ARBNDDIR');

/copy QRPGLESRC,ARSRVPR

exec sql set option commit = *chg, closqlcsr = *endmod, datfmt = *iso,
                    naming = *sys;

dcl-ds payment qualified;
  batch    zoned(5:0);
  seq      zoned(5:0);
  customer zoned(6:0);
  payDate  zoned(8:0);
  amount   packed(9:2);
end-ds;

dcl-c PAY_POSTED 'P';
dcl-c PAY_ERROR  'E';

// WITH HOLD: the cursor stays open across the COMMIT after each payment
exec sql declare newPayments cursor with hold for
  select BATCH_NO, SEQUENCE_NO, CUSTOMER_ID, PAY_DATE, AMOUNT
    from AR_PAYMENTS
   where PAY_STATUS = ' '
   order by BATCH_NO, SEQUENCE_NO;

exec sql open newPayments;
dow sqlFetchNext();
  postPayment();
enddo;
exec sql close newPayments;

*inlr = *on;
return;

// ---------------------------------------------------------------------
dcl-proc sqlFetchNext;
  dcl-pi *n ind end-pi;

  exec sql fetch next from newPayments into :payment;
  if sqlcode < 0;
    sqlFail('fetch payment');
  endif;
  return sqlcode = 0;
end-proc;

// ---------------------------------------------------------------------
// One payment = one transaction
// ---------------------------------------------------------------------
dcl-proc postPayment;
  dcl-s found ind;
  dcl-s error varchar(30);
  dcl-s status char(1);
  dcl-s balance packed(11:2);
  dcl-s remaining packed(9:2);
  dcl-s message char(30);

  if payment.amount > 0;
    // read and lock the customer row until the commit
    exec sql select CUSTOMER_STATUS, BALANCE into :status, :balance
               from AR_CUSTOMER
              where CUSTOMER_ID = :payment.customer
               with rs use and keep exclusive locks;
    if sqlcode < 0;
      sqlFail('read customer');
    endif;
    found = (sqlcode = 0);
  endif;

  error = AR_validatePayment(payment.amount : found);
  if error <> '';
    setPayment(PAY_ERROR : error);
    exec sql commit;
    return;
  endif;

  remaining = applyToInvoices();

  balance -= payment.amount;
  status = AR_customerStatus(status : balance);
  exec sql update AR_CUSTOMER
              set BALANCE = :balance, CUSTOMER_STATUS = :status
            where CUSTOMER_ID = :payment.customer;
  if sqlcode <> 0;
    sqlFail('update customer');
  endif;

  message = *blanks;
  if remaining > 0;
    message = AR_MSG_UNAPPLIED;
  endif;
  setPayment(PAY_POSTED : message);

  exec sql commit;
end-proc;

// ---------------------------------------------------------------------
// Open invoices of the customer, oldest due date first
// ---------------------------------------------------------------------
dcl-proc applyToInvoices;
  dcl-pi *n packed(9:2) end-pi;

  dcl-s remaining packed(9:2);
  dcl-s applied packed(9:2);
  dcl-s invoiceNo zoned(7:0);
  dcl-s openAmount packed(9:2);

  exec sql declare openInvoices cursor for
    select INVOICE_NO, AMOUNT - PAID
      from AR_INVOICES
     where CUSTOMER_ID = :payment.customer
       and INVOICE_STATUS = 'O'
     order by DUE_DATE, INVOICE_NO
       for update of PAID, INVOICE_STATUS, LAST_PAY_DATE;

  remaining = payment.amount;
  exec sql open openInvoices;

  dow remaining > 0;
    exec sql fetch next from openInvoices into :invoiceNo, :openAmount;
    if sqlcode = 100;
      leave;
    elseif sqlcode < 0;
      sqlFail('fetch invoice');
    endif;

    applied = AR_applyAmount(remaining : openAmount);
    remaining -= applied;
    exec sql update AR_INVOICES
                set PAID = PAID + :applied,
                    INVOICE_STATUS = case when PAID + :applied = AMOUNT
                                          then 'P' else 'O' end,
                    LAST_PAY_DATE = :payment.payDate
              where current of openInvoices;
    if sqlcode <> 0;
      sqlFail('update invoice');
    endif;
  enddo;

  exec sql close openInvoices;
  return remaining;
end-proc;

// ---------------------------------------------------------------------
dcl-proc setPayment;
  dcl-pi *n;
    status  char(1) const;
    message varchar(30) const;
  end-pi;

  exec sql update AR_PAYMENTS
              set PAY_STATUS = :status, MESSAGE = :message
            where BATCH_NO = :payment.batch and SEQUENCE_NO = :payment.seq;
  if sqlcode <> 0;
    sqlFail('update payment');
  endif;
end-proc;

// ---------------------------------------------------------------------
// Unexpected SQL error: undo the current payment and stop the run with
// an escape message (the job log has the SQL message before it)
// ---------------------------------------------------------------------
dcl-proc sqlFail;
  dcl-pi *n;
    action varchar(30) const;
  end-pi;

  dcl-pr QMHSNDPM extpgm('QMHSNDPM');
    msgId     char(7) const;
    msgFile   char(20) const;
    msgData   char(256) const options(*varsize);
    dataLen   int(10) const;
    msgType   char(10) const;
    callStack char(10) const;
    stackCnt  int(10) const;
    msgKey    char(4);
    errorCode char(8);
  end-pr;
  dcl-s key char(4);
  dcl-s errCode char(8) inz(*allx'00');
  dcl-s text varchar(256);

  text = 'ARR240 ' + action + ' failed, SQLSTATE ' + sqlstate
       + ', payment ' + %char(payment.batch) + '/' + %char(payment.seq)
       + ' rolled back';
  exec sql rollback;
  QMHSNDPM('CPF9898' : 'QCPFMSG   *LIBL' : text : %len(text)
           : '*ESCAPE' : '*PGMBDY' : 1 : key : errCode);
end-proc;
