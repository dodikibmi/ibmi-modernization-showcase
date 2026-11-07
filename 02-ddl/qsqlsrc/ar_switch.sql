-- =====================================================================
-- Stage 2 - step 2 of 3: copy the data and switch the old names over
--
-- The old DDS files are renamed (kept for rollback, see ar_rollback.sql),
-- then each old file name comes back as an SQL INDEX over the new table
-- with the old record format name and exactly the old column list:
--     RCDFMT <old format> ADD <old columns>
-- An SQL index with RCDFMT is a keyed logical file to native I/O; when
-- the key columns are also the first columns, its record format level
-- identifier equals the DDS one, so the existing programs open it
-- without being recompiled (no CPF4131).
-- =====================================================================

-- orphan check before the copy: invoices whose customer does not exist
-- (the legacy data has one - customer 100600; it is reported, not lost,
--  which is why no foreign key is added in this stage)
-- SELECT INCUST, ININV FROM DODIKIBMI2.ARINVP
--   WHERE INCUST NOT IN (SELECT CUCUST FROM DODIKIBMI2.ARCUSTP);

INSERT INTO DODIKIBMI2.AR_CUSTOMER (CUCUST, CUNAME, CUCRLM, CUBAL, CUSTAT)
  SELECT CUCUST, CUNAME, CUCRLM, CUBAL, CUSTAT FROM DODIKIBMI2.ARCUSTP;
INSERT INTO DODIKIBMI2.AR_INVOICES (INCUST, ININV, INIDAT, INDUE, INAMT, INPAID, INLPDT, INSTS)
  SELECT INCUST, ININV, INIDAT, INDUE, INAMT, INPAID, INLPDT, INSTS FROM DODIKIBMI2.ARINVP;
INSERT INTO DODIKIBMI2.AR_PAYMENTS (PYBAT, PYSEQ, PYCUST, PYDATE, PYAMT, PYSTS, PYMSG)
  SELECT PYBAT, PYSEQ, PYCUST, PYDATE, PYAMT, PYSTS, PYMSG FROM DODIKIBMI2.ARPAYP;

-- keep the DDS objects under new names
DROP VIEW DODIKIBMI2.ARINVL1;
RENAME TABLE DODIKIBMI2.ARCUSTP TO SYSTEM NAME ARCUSTP0;
RENAME TABLE DODIKIBMI2.ARINVP  TO SYSTEM NAME ARINVP0;
RENAME TABLE DODIKIBMI2.ARPAYP  TO SYSTEM NAME ARPAYP0;

-- the old names, now SQL indexes with the old record formats
CREATE UNIQUE INDEX DODIKIBMI2.ARCUSTP ON DODIKIBMI2.AR_CUSTOMER (CUCUST)
  RCDFMT ARCUSTR ADD CUCUST, CUNAME, CUCRLM, CUBAL, CUSTAT;

-- ARINVP and ARINVL1 are NOT SQL indexes: an SQL index puts its key
-- columns first in the record format (ARINVP key ININV is the 2nd field,
-- ARINVL1 keys are fields 1, 4, 2), which changes the level identifier.
-- They are DDS logical files over the new table instead - run as CL:
--   CRTLF FILE(DODIKIBMI2/ARINVP)  SRCFILE(QDDSSRC) SRCMBR(ARINVPLF)
--   CRTLF FILE(DODIKIBMI2/ARINVL1) SRCFILE(QDDSSRC) SRCMBR(ARINVL1LF)

CREATE UNIQUE INDEX DODIKIBMI2.ARPAYP ON DODIKIBMI2.AR_PAYMENTS (PYBAT, PYSEQ)
  RCDFMT ARPAYR ADD PYBAT, PYSEQ, PYCUST, PYDATE, PYAMT, PYSTS, PYMSG;
