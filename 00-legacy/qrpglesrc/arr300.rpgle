     HDATEDIT(*YMD)
      * ================================================================
      *  ARR300 - Aged trial balance (legacy style: RPG cycle)
      *  Primary file ARINVL1 drives the cycle; L1 = customer break.
      *  Parameter: as-of date, 8 characters YYYYMMDD.
      *  Open amount of each open invoice goes into one age bucket by
      *  days past due: current (<= 0), 1-30, 31-60, 61-90, over 90.
      *  Indicators: 01 invoice record, 40 invoice is open,
      *              50 customer has open amount, 90 customer missing
      * ================================================================
     FARINVL1   IP   E           K DISK
     FARCUSTP   IF   E           K DISK
     FQSYSPRT   O    F  132        PRINTER OFLIND(*INOF)
     DWASOF            S              8S 0
     DWASODT           S               D   DATFMT(*ISO)
     DWDUE             S               D   DATFMT(*ISO)
     DWDAYS            S              5P 0
     DWOPEN            S              9P 2
     DD1CUR            S              9P 2
     DD1030            S              9P 2
     DD1060            S              9P 2
     DD1090            S              9P 2
     DD1OVR            S              9P 2
     DT1CUR            S             11P 2
     DT1030            S             11P 2
     DT1060            S             11P 2
     DT1090            S             11P 2
     DT1OVR            S             11P 2
     DT1TOT            S             11P 2
     DTLCUR            S             11P 2
     DTL030            S             11P 2
     DTL060            S             11P 2
     DTL090            S             11P 2
     DTLOVR            S             11P 2
     DTLTOT            S             11P 2
     IARINVR        01
     I              INCUST                      INCUST        L1
     C*
     C     *ENTRY        PLIST
     C                   PARM                    PASOF             8
     C*
     C*  first invoice of a customer: reset its totals, get its name
     C   L1              Z-ADD     0             T1CUR
     C   L1              Z-ADD     0             T1030
     C   L1              Z-ADD     0             T1060
     C   L1              Z-ADD     0             T1090
     C   L1              Z-ADD     0             T1OVR
     C   L1              Z-ADD     0             T1TOT
     C   L1INCUST        CHAIN     ARCUSTR                            90
     C   90              MOVEL     '*UNKNOWN*'   CUNAME
     C*
     C                   SETOFF                                       40
     C     INSTS         IFEQ      'O'
     C                   SETON                                        40
     C     INAMT         SUB       INPAID        WOPEN
     C     *ISO          MOVE      INDUE         WDUE
     C     WASODT        SUBDUR    WDUE          WDAYS:*D
     C                   Z-ADD     0             D1CUR
     C                   Z-ADD     0             D1030
     C                   Z-ADD     0             D1060
     C                   Z-ADD     0             D1090
     C                   Z-ADD     0             D1OVR
     C                   SELECT
     C     WDAYS         WHENLE    0
     C                   Z-ADD     WOPEN         D1CUR
     C                   ADD       WOPEN         T1CUR
     C     WDAYS         WHENLE    30
     C                   Z-ADD     WOPEN         D1030
     C                   ADD       WOPEN         T1030
     C     WDAYS         WHENLE    60
     C                   Z-ADD     WOPEN         D1060
     C                   ADD       WOPEN         T1060
     C     WDAYS         WHENLE    90
     C                   Z-ADD     WOPEN         D1090
     C                   ADD       WOPEN         T1090
     C                   OTHER
     C                   Z-ADD     WOPEN         D1OVR
     C                   ADD       WOPEN         T1OVR
     C                   ENDSL
     C                   ADD       WOPEN         T1TOT
     C                   ENDIF
     C*
     C*  customer total time: roll into grand totals
     CL1   T1TOT         COMP      0                                  5050
     CL1                 ADD       T1CUR         TLCUR
     CL1                 ADD       T1030         TL030
     CL1                 ADD       T1060         TL060
     CL1                 ADD       T1090         TL090
     CL1                 ADD       T1OVR         TLOVR
     CL1                 ADD       T1TOT         TLTOT
     C*
     C     *INZSR        BEGSR
     C                   MOVE      PASOF         WASOF
     C     *ISO          MOVE      WASOF         WASODT
     C                   ENDSR
      *
     OQSYSPRT   H    1P                     2  1
     O         OR    OF
     O                                           18 'AGED TRIAL BALANCE'
     O                                           45 'AS OF'
     O                       WASOF               56 '0   -  -  '
     O                                          123 'PAGE'
     O                       PAGE          Z    128
     O          H    1P                     2
     O         OR    OF
     O                                           18 'CUSTOMER / INVOICE'
     O                                           29 'INV DATE'
     O                                           41 'DUE DATE'
     O                                           48 'DAYS'
     O                                           62 'CURRENT'
     O                                           76 '1-30 DAYS'
     O                                           90 '31-60 DAYS'
     O                                          104 '61-90 DAYS'
     O                                          118 'OVER 90 DAYS'
     O                                          132 'OPEN AMOUNT'
     O          D    01 40                  1
     O                       ININV         Z     16
     O                       INIDAT              29 '0   -  -  '
     O                       INDUE               41 '0   -  -  '
     O                       WDAYS         L     48
     O                       D1CUR         K     62
     O                       D1030         K     76
     O                       D1060         K     90
     O                       D1090         K    104
     O                       D1OVR         K    118
     O                       WOPEN         K    132
     O          T    L1 50               0  2
     O                       CUCUST               6
     O                       CUNAME              37
     O                       T1CUR         K     62
     O                       T1030         K     76
     O                       T1060         K     90
     O                       T1090         K    104
     O                       T1OVR         K    118
     O                       T1TOT         K    132
     O          T    LR                  1  1
     O                                           19 '*** GRAND TOTAL ***'
     O                       TLCUR         J     62
     O                       TL030         J     76
     O                       TL060         J     90
     O                       TL090         J    104
     O                       TLOVR         J    118
     O                       TLTOT         J    132
