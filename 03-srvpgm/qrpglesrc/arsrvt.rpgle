**FREE
// =====================================================================
// ARSRVT - RPGUnit test suite for service program ARSRV     (stage 3)
// Every exported procedure named test... is one test case. The cases
// are the business rules of the legacy ARR200 / ARR300, including the
// boundaries of every age bucket and the *UNKNOWN* customer defect.
//
// Build: RUCRTRPG TSTPGM(ARSRVT) SRCFILE(QRPGLESRC) BNDSRVPGM(ARSRV)
// Run:   RUCALLTST TSTPGM(ARSRVT)
// =====================================================================
ctl-opt nomain option(*srcstmt:*nodebugio);

/copy DODIKIBMI2/QINCLUDE,TESTCASE
/copy QRPGLESRC,ARSRVPR

// --- payment validation ----------------------------------------------
dcl-proc test_validate_ok export;
  aEqual('' : AR_validatePayment(1500.00 : *on));
end-proc;

dcl-proc test_validate_zero_amount export;
  aEqual(AR_MSG_INVALID_AMOUNT : AR_validatePayment(0 : *on));
end-proc;

dcl-proc test_validate_negative_amount export;
  aEqual(AR_MSG_INVALID_AMOUNT : AR_validatePayment(-50.00 : *on));
end-proc;

dcl-proc test_validate_unknown_customer export;
  aEqual(AR_MSG_NO_CUSTOMER : AR_validatePayment(100.00 : *off));
end-proc;

dcl-proc test_validate_amount_checked_first export;
  // legacy order: an invalid amount wins over an unknown customer
  aEqual(AR_MSG_INVALID_AMOUNT : AR_validatePayment(0 : *off));
end-proc;

// --- applying money to one invoice -----------------------------------
dcl-proc test_apply_pays_invoice_in_full export;
  aEqual('1200.00' : %char(AR_applyAmount(1500.00 : 1200.00)));
end-proc;

dcl-proc test_apply_exact_amount export;
  aEqual('500.00' : %char(AR_applyAmount(500.00 : 500.00)));
end-proc;

dcl-proc test_apply_partial export;
  aEqual('300.00' : %char(AR_applyAmount(300.00 : 500.00)));
end-proc;

dcl-proc test_apply_nothing_left export;
  aEqual('.00' : %char(AR_applyAmount(0 : 500.00)));   // %char drops the leading zero
end-proc;

// --- customer on hold -------------------------------------------------
dcl-proc test_hold_released_at_zero export;
  aEqual('A' : AR_customerStatus('H' : 0));
end-proc;

dcl-proc test_hold_released_on_credit export;
  aEqual('A' : AR_customerStatus('H' : -550.00));
end-proc;

dcl-proc test_hold_kept_with_balance export;
  aEqual('H' : AR_customerStatus('H' : 0.01));
end-proc;

dcl-proc test_active_stays_active export;
  aEqual('A' : AR_customerStatus('A' : 2350.00));
end-proc;

// --- days past due ----------------------------------------------------
dcl-proc test_days_due_today export;
  iEqual(0 : AR_daysPastDue(d'2026-10-31' : 20261031));
end-proc;

dcl-proc test_days_overdue export;
  iEqual(92 : AR_daysPastDue(d'2026-10-31' : 20260731));
end-proc;

dcl-proc test_days_not_yet_due export;
  iEqual(-19 : AR_daysPastDue(d'2026-10-31' : 20261119));
end-proc;

dcl-proc test_days_over_leap_day export;
  iEqual(2 : AR_daysPastDue(d'2024-03-01' : 20240228));
end-proc;

// --- age buckets: every boundary --------------------------------------
dcl-proc test_bucket_boundaries export;
  iEqual(AR_BUCKET_CURRENT : AR_ageBucket(-19));
  iEqual(AR_BUCKET_CURRENT : AR_ageBucket(0));
  iEqual(AR_BUCKET_1_30    : AR_ageBucket(1));
  iEqual(AR_BUCKET_1_30    : AR_ageBucket(30));
  iEqual(AR_BUCKET_31_60   : AR_ageBucket(31));
  iEqual(AR_BUCKET_31_60   : AR_ageBucket(60));
  iEqual(AR_BUCKET_61_90   : AR_ageBucket(61));
  iEqual(AR_BUCKET_61_90   : AR_ageBucket(90));
  iEqual(AR_BUCKET_OVER_90 : AR_ageBucket(91));
end-proc;

// --- customer name on the report (legacy defect) ----------------------
dcl-proc test_name_of_known_customer export;
  aEqual('ARUNA TRADING (FICTIONAL)' : %trimr(AR_customerName(*on : 'ARUNA TRADING (FICTIONAL)')));
end-proc;

dcl-proc test_unknown_customer_has_no_leftover_name export;
  // legacy MOVEL left 'EKA FOODS (FICTIONAL)' behind: '*UNKNOWN* (FICTIONAL)'
  aEqual('*UNKNOWN*' : %trimr(AR_customerName(*off : 'EKA FOODS (FICTIONAL)')));
end-proc;
