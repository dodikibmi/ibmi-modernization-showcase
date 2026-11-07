-- Test data for the regression run (all names and numbers are fictional).
-- As-of date of the run: 2026-10-31. Each statement ends with ';' on its own line end.
-- Library DODIKIBMI2 = data library on PUB400; change it to your own.

DELETE FROM DODIKIBMI2.ARPAYP;
DELETE FROM DODIKIBMI2.ARINVP;
DELETE FROM DODIKIBMI2.ARCUSTP;

INSERT INTO DODIKIBMI2.ARCUSTP (CUCUST, CUNAME, CUCRLM, CUBAL, CUSTAT) VALUES
  (100100, 'ARUNA TRADING (FICTIONAL)',   50000.00, 3850.00, 'A'),
  (100200, 'BINTANG RETAIL (FICTIONAL)',  10000.00, 3000.00, 'H'),
  (100300, 'CAKRA LOGISTICS (FICTIONAL)', 20000.00, 1450.00, 'A'),
  (100400, 'DELTA MART (FICTIONAL)',       5000.00,    0.00, 'A'),
  (100500, 'EKA FOODS (FICTIONAL)',       15000.00, 2000.00, 'A');

-- customer 100600 has an invoice but no master record (report shows *UNKNOWN*)
INSERT INTO DODIKIBMI2.ARINVP (INCUST, ININV, INIDAT, INDUE, INAMT, INPAID, INLPDT, INSTS) VALUES
  (100100, 2600101, 20260701, 20260731, 1200.00,   0.00, 0, 'O'),
  (100100, 2600102, 20260815, 20260914,  800.00, 300.00, 20260920, 'O'),
  (100100, 2600103, 20261001, 20261031, 1500.00,   0.00, 0, 'O'),
  (100100, 2600104, 20261020, 20261119,  650.00,   0.00, 0, 'O'),
  (100200, 2600201, 20260601, 20260701, 2000.00,   0.00, 0, 'O'),
  (100200, 2600202, 20260901, 20261001, 1000.00,   0.00, 0, 'O'),
  (100300, 2600301, 20260710, 20260809,  300.00,   0.00, 0, 'O'),
  (100300, 2600302, 20260805, 20260904,  450.00,   0.00, 0, 'O'),
  (100300, 2600303, 20260920, 20261020,  700.00,   0.00, 0, 'O'),
  (100400, 2600401, 20260801, 20260831,  500.00, 500.00, 20260825, 'P'),
  (100500, 2600501, 20260910, 20261010,  900.00,   0.00, 0, 'O'),
  (100500, 2600502, 20261015, 20261114, 1100.00,   0.00, 0, 'O'),
  (100600, 2600601, 20260901, 20260915,  250.00,   0.00, 0, 'O');

-- batch 1: one case per business rule
INSERT INTO DODIKIBMI2.ARPAYP (PYBAT, PYSEQ, PYCUST, PYDATE, PYAMT, PYSTS, PYMSG) VALUES
  (1, 1, 100100, 20261025, 1500.00, ' ', ' '),  -- pays 2600101 in full, 300 into 2600102
  (1, 2, 100200, 20261026, 3000.00, ' ', ' '),  -- pays everything, customer released from hold
  (1, 3, 100300, 20261027, 2000.00, ' ', ' '),  -- 550 left over: unapplied credit
  (1, 4, 999999, 20261027,  100.00, ' ', ' '),  -- unknown customer
  (1, 5, 100500, 20261028,    0.00, ' ', ' '),  -- zero amount
  (1, 6, 100500, 20261028,  400.00, ' ', ' '),  -- partial payment
  (1, 7, 100100, 20261029,  -50.00, ' ', ' '),  -- negative amount
  (1, 8, 100400, 20260825,  500.00, 'P', 'POSTED EARLIER');  -- already posted: skipped
