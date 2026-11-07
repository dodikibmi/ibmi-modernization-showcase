     HDATEDIT(*YMD)
      * ================================================================
      *  ARR200 - Post customer payments (legacy style, fixed format)
      *  Every new payment (PYSTS = ' ') is applied to the customer's
      *  open invoices, oldest due date first. Paid invoices get INSTS
      *  'P'. Customer balance goes down by the payment; a customer on
      *  hold is released when the balance drops to zero or below.
      *  Errors: amount <= 0, customer not found -> PYSTS 'E'.
      *  Money left after all invoices stays as unapplied credit.
      *  Indicators: 90 customer not found, 98 end of invoices,
      *              99 end of payments
      * ================================================================
     FARPAYP    UF   E           K DISK
     FARCUSTP   UF   E           K DISK
     FARINVL1   UF   E           K DISK
     DMSGAMT           C                   CONST('INVALID AMOUNT')
     DMSGCUS           C                   CONST('CUSTOMER NOT FOUND')
     DMSGUNA           C                   CONST('UNAPPLIED CREDIT')
     DWREMN            S              9P 2
     DWAPPLY           S              9P 2
     DWOPEN            S              9P 2
     C*
     C                   READ      ARPAYR                                 99
     C     *IN99         DOWEQ     *OFF
     C     PYSTS         IFEQ      ' '
     C                   EXSR      POSTPY
     C                   ENDIF
     C                   READ      ARPAYR                                 99
     C                   ENDDO
     C                   MOVE      *ON           *INLR
     C*
     C* ----------------------------------------------------------------
     C*  POSTPY - post one payment
     C* ----------------------------------------------------------------
     C     POSTPY        BEGSR
     C                   MOVE      *BLANKS       PYMSG
     C     PYAMT         IFLE      0
     C                   MOVE      'E'           PYSTS
     C                   MOVEL     MSGAMT        PYMSG
     C                   UPDATE    ARPAYR
     C                   GOTO      ENDPST
     C                   ENDIF
     C*
     C     PYCUST        CHAIN     ARCUSTR                            90
     C     *IN90         IFEQ      *ON
     C                   MOVE      'E'           PYSTS
     C                   MOVEL     MSGCUS        PYMSG
     C                   UPDATE    ARPAYR
     C                   GOTO      ENDPST
     C                   ENDIF
     C*
     C*  apply to open invoices, oldest due date first
     C                   Z-ADD     PYAMT         WREMN
     C     PYCUST        SETLL     ARINVR
     C     PYCUST        READE     ARINVR                                 98
     C     *IN98         DOWEQ     *OFF
     C     WREMN         ANDGT     0
     C     INSTS         IFEQ      'O'
     C     INAMT         SUB       INPAID        WOPEN
     C     WREMN         IFGE      WOPEN
     C                   Z-ADD     WOPEN         WAPPLY
     C                   MOVE      'P'           INSTS
     C                   ELSE
     C                   Z-ADD     WREMN         WAPPLY
     C                   ENDIF
     C                   ADD       WAPPLY        INPAID
     C                   SUB       WAPPLY        WREMN
     C                   Z-ADD     PYDATE        INLPDT
     C                   UPDATE    ARINVR
     C                   ENDIF
     C     PYCUST        READE     ARINVR                                 98
     C                   ENDDO
     C*
     C                   SUB       PYAMT         CUBAL
     C     CUSTAT        IFEQ      'H'
     C     CUBAL         ANDLE     0
     C                   MOVE      'A'           CUSTAT
     C                   ENDIF
     C                   UPDATE    ARCUSTR
     C                   MOVE      'P'           PYSTS
     C     WREMN         IFGT      0
     C                   MOVEL     MSGUNA        PYMSG
     C                   ENDIF
     C                   UPDATE    ARPAYR
     C     ENDPST        TAG
     C                   ENDSR
