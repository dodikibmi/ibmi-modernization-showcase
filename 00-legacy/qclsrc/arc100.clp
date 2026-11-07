/* ARC100 - Accounts receivable daily run (legacy style)         */
/* 1. post payments  2. print aged trial balance                  */
             PGM        PARM(&ASOF)
             DCL        VAR(&ASOF) TYPE(*CHAR) LEN(8)

             CALL       PGM(ARR200)
             CALL       PGM(ARR300) PARM(&ASOF)
             ENDPGM
