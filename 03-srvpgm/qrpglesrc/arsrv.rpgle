**FREE
// =====================================================================
// ARSRV - accounts receivable business rules        (stage 3, NOMAIN)
//
// The rules that were buried in the calculation specs of ARR200 and
// ARR300, as small procedures without any file I/O, so that they can
// be unit tested (ARSRVT) and reused by batch programs, an API, etc.
//
// Build:  CRTRPGMOD MODULE(ARSRV) SRCFILE(QRPGLESRC)
//         CRTSRVPGM SRVPGM(ARSRV) EXPORT(*SRCFILE) SRCFILE(QRPGLESRC) SRCMBR(ARSRVB)
// =====================================================================
ctl-opt nomain option(*srcstmt:*nodebugio);

/copy QRPGLESRC,ARSRVPR

// ---------------------------------------------------------------------
dcl-proc AR_validatePayment export;
  dcl-pi *n varchar(30);
    amount        packed(9:2) const;
    customerFound ind const;
  end-pi;

  if amount <= 0;
    return AR_MSG_INVALID_AMOUNT;
  endif;
  if not customerFound;
    return AR_MSG_NO_CUSTOMER;
  endif;
  return '';
end-proc;

// ---------------------------------------------------------------------
dcl-proc AR_applyAmount export;
  dcl-pi *n packed(9:2);
    remaining  packed(9:2) const;
    openAmount packed(9:2) const;
  end-pi;

  if remaining <= 0 or openAmount <= 0;
    return 0;
  endif;
  if remaining >= openAmount;
    return openAmount;
  endif;
  return remaining;
end-proc;

// ---------------------------------------------------------------------
dcl-proc AR_customerStatus export;
  dcl-pi *n char(1);
    status  char(1) const;
    balance packed(11:2) const;
  end-pi;

  if status = 'H' and balance <= 0;
    return 'A';
  endif;
  return status;
end-proc;

// ---------------------------------------------------------------------
dcl-proc AR_daysPastDue export;
  dcl-pi *n int(10);
    asOf   date(*iso) const;
    dueYmd zoned(8:0) const;
  end-pi;

  return %diff(asOf : %date(dueYmd : *iso) : *days);
end-proc;

// ---------------------------------------------------------------------
dcl-proc AR_ageBucket export;
  dcl-pi *n int(10);
    daysPastDue int(10) const;
  end-pi;

  select;
    when daysPastDue <= 0;
      return AR_BUCKET_CURRENT;
    when daysPastDue <= 30;
      return AR_BUCKET_1_30;
    when daysPastDue <= 60;
      return AR_BUCKET_31_60;
    when daysPastDue <= 90;
      return AR_BUCKET_61_90;
    other;
      return AR_BUCKET_OVER_90;
  endsl;
end-proc;

// ---------------------------------------------------------------------
dcl-proc AR_customerName export;
  dcl-pi *n char(30);
    found ind const;
    name  char(30) const;
  end-pi;

  if found;
    return name;
  endif;
  return AR_UNKNOWN_CUSTOMER;      // the whole field, not 9 characters
end-proc;
