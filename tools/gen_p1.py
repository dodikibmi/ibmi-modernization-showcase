"""Generates the fixed-format sources of stage 00-legacy and the printer file of stage 01.

Fictional accounts receivable application:
  ARCUSTP  PF  customer master            ARINVP  PF  open invoices
  ARINVL1  LF  invoices by cust/due/inv   ARPAYP  PF  payments to post
  ARR200   RPGLE fixed: post payments to the oldest invoices first (indicators, GOTO/TAG, subroutine)
  ARR300   RPGLE fixed: aged trial balance, RPG cycle (IP + L1), O-specs to QSYSPRT
  ARC100   CLP: runs both
The report layout table REPORT drives both the O-specs (stage 0) and the printer file
ARR310P (stage 1), so the two spooled reports can be compared line by line.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEG = ROOT / "00-legacy"


def put(b, col, text):
    if col - 1 + len(text) > len(b):
        raise ValueError(f"too long @{col}: {text!r}")
    for i, ch in enumerate(text):
        b[col - 1 + i] = ch


def ln(spec, width=100):
    b = [" "] * width
    put(b, 6, spec)
    return b


# ------------------------------------------------------------------ DDS
def dds(typ="", name="", length="", dtype="", dec="", kw="", ind=""):
    b = ln("A", 80)
    if ind:
        put(b, 7, ind)
    if typ:
        put(b, 17, typ)
    if name:
        put(b, 19, name)
    if length != "":
        put(b, 30, str(length).rjust(5))
    if dtype:
        put(b, 35, dtype)
    if dec != "":
        put(b, 36, str(dec).rjust(2))
    if kw:
        put(b, 45, kw)
    return "".join(b).rstrip()


def ddsc(text=""):
    return ("     A*" + (" " + text if text else "")).rstrip()


# ------------------------------------------------------------------ RPG fixed
def H(kw):
    b = ln("H")
    put(b, 7, kw)
    return "".join(b).rstrip()


def F(name, ftype, desig, fmt, reclen="", key="", device="DISK", kw="", eof=""):
    b = ln("F")
    put(b, 7, name)
    put(b, 17, ftype)
    if desig:
        put(b, 18, desig)
    if eof:
        put(b, 19, eof)
    put(b, 22, fmt)
    if reclen:
        put(b, 23, str(reclen).rjust(5))
    if key:
        put(b, 34, key)
    put(b, 36, device)
    if kw:
        put(b, 44, kw)
    return "".join(b).rstrip()


def D(name, dt="", length="", typ="", dec="", kw=""):
    b = ln("D")
    if name:
        put(b, 7, name)
    if dt:
        put(b, 24, dt)
    if length != "":
        put(b, 33, str(length).rjust(7))
    if typ:
        put(b, 40, typ)
    if dec != "":
        put(b, 41, str(dec).rjust(2))
    if kw:
        put(b, 44, kw)
    return "".join(b).rstrip()


def C(f1="", op="", f2="", res="", length="", dec="", hi="", lo="", eq="", lvl="", ind="", x2=""):
    b = ln("C")
    if lvl:
        put(b, 7, lvl)
    if ind:
        put(b, 9, ind.rjust(3))
    if f1:
        put(b, 12, f1)
    put(b, 26, op)
    if x2:
        put(b, 36, x2)
    if f2:
        if len(f2) > 14:
            raise ValueError(f"factor 2 > 14: {f2}")
        put(b, 36, f2)
    if res:
        put(b, 50, res)
    if length != "":
        put(b, 64, str(length).rjust(5))
    if dec != "":
        put(b, 69, str(dec).rjust(2))
    if hi:
        put(b, 71, hi)
    if lo:
        put(b, 73, lo)
    if eq:
        put(b, 75, eq)
    return "".join(b).rstrip()


def Cc(text=""):
    return ("     C*" + (" " + text if text else "")).rstrip()


def Ic(text=""):
    return ("      *" + (" " + text if text else "")).rstrip()


def IREC(fmt, rii):
    b = ln("I")
    put(b, 7, fmt)
    put(b, 21, rii)
    return "".join(b).rstrip()


def IFLD(ext, lvl):
    b = ln("I")
    put(b, 21, ext)
    put(b, 49, ext)
    put(b, 63, lvl)
    return "".join(b).rstrip()


def OREC(fname, typ, ind="", sb="", sa="", kb="", ka="", rel=""):
    b = ln("O")
    if fname:
        put(b, 7, fname)
    if rel:
        put(b, 16, rel)
    if typ:
        put(b, 17, typ)
    for k, tok in enumerate(ind.split()):   # 21/24/27 = N, 22-23/25-26/28-29 = indicator
        if tok.startswith("N"):
            put(b, 21 + 3 * k, tok)
        else:
            put(b, 22 + 3 * k, tok)
    if sb != "":
        put(b, 40, str(sb).rjust(3))
    if sa != "":
        put(b, 43, str(sa).rjust(3))
    if kb != "":
        put(b, 46, str(kb).rjust(3))
    if ka != "":
        put(b, 49, str(ka).rjust(3))
    return "".join(b).rstrip()


def OFLD(end, field="", edit="", const="", ind=""):
    b = ln("O")
    if ind:
        put(b, 21, ind)
    if field:
        put(b, 30, field)
    if edit:
        put(b, 44, edit)
    put(b, 47, str(end).rjust(5))
    if const:
        put(b, 53, "'" + const + "'")
    return "".join(b).rstrip()


# ------------------------------------------------------------------ layout laporan (dipakai bersama)
# each item: (end position, content): ('c', text) constant | ('w', field, edit word, width) | ('f', field, edit code, width)
DATEWORD = "0   -  -  "   # 8 digit YYYYMMDD -> YYYY-MM-DD
AMT_ENDS = [62, 76, 90, 104, 118, 132]
REPORT = {
    "H1": [(18, ("c", "AGED TRIAL BALANCE")), (45, ("c", "AS OF")),
           (56, ("w", "WASOF", DATEWORD, 10)), (123, ("c", "PAGE")), (128, ("f", "PAGE", "Z", 4))],
    "H2": [(18, ("c", "CUSTOMER / INVOICE")), (29, ("c", "INV DATE")), (41, ("c", "DUE DATE")),
           (48, ("c", "DAYS")), (62, ("c", "CURRENT")), (76, ("c", "1-30 DAYS")), (90, ("c", "31-60 DAYS")),
           (104, ("c", "61-90 DAYS")), (118, ("c", "OVER 90 DAYS")), (132, ("c", "OPEN AMOUNT"))],
    "D1": [(16, ("f", "ININV", "Z", 7)), (29, ("w", "INIDAT", DATEWORD, 10)), (41, ("w", "INDUE", DATEWORD, 10)),
           (48, ("f", "WDAYS", "L", 6))]
          + [(e, ("f", n, "K", 15)) for e, n in zip(AMT_ENDS, ["D1CUR", "D1030", "D1060", "D1090", "D1OVR", "WOPEN"])],
    "T1": [(6, ("f", "CUCUST", "", 6)), (37, ("f", "CUNAME", "", 30))]
          + [(e, ("f", n, "K", 15)) for e, n in zip(AMT_ENDS, ["T1CUR", "T1030", "T1060", "T1090", "T1OVR", "T1TOT"])],
    "TL": [(19, ("c", "*** GRAND TOTAL ***"))]
          + [(e, ("f", n, "J", 15)) for e, n in zip(AMT_ENDS, ["TLCUR", "TL030", "TL060", "TL090", "TLOVR", "TLTOT"])],
}


def write(rel, lines):
    p = LEG / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(("\n".join(lines) + "\n").encode("utf-8"))


# ================================================================== DDS
write("qddssrc/arcustp.pf", [
    ddsc("ARCUSTP - Customer master (fictional data)"),
    dds(kw="UNIQUE"),
    dds("R", "ARCUSTR", kw="TEXT('Customer master')"),
    dds(name="CUCUST", length=6, dtype="S", dec=0, kw="COLHDG('Customer')"),
    dds(name="CUNAME", length=30, dtype="A", kw="COLHDG('Name')"),
    dds(name="CUCRLM", length=9, dtype="P", dec=2, kw="COLHDG('Credit limit')"),
    dds(name="CUBAL", length=11, dtype="P", dec=2, kw="COLHDG('Balance')"),
    dds(name="CUSTAT", length=1, dtype="A", kw="COLHDG('Status' 'A/H')"),
    dds("K", "CUCUST"),
])
write("qddssrc/arinvp.pf", [
    ddsc("ARINVP - Invoices (fictional data)"),
    dds(kw="UNIQUE"),
    dds("R", "ARINVR", kw="TEXT('Invoice')"),
    dds(name="INCUST", length=6, dtype="S", dec=0, kw="COLHDG('Customer')"),
    dds(name="ININV", length=7, dtype="S", dec=0, kw="COLHDG('Invoice')"),
    dds(name="INIDAT", length=8, dtype="S", dec=0, kw="COLHDG('Invoice date' 'YYYYMMDD')"),
    dds(name="INDUE", length=8, dtype="S", dec=0, kw="COLHDG('Due date' 'YYYYMMDD')"),
    dds(name="INAMT", length=9, dtype="P", dec=2, kw="COLHDG('Amount')"),
    dds(name="INPAID", length=9, dtype="P", dec=2, kw="COLHDG('Paid')"),
    dds(name="INLPDT", length=8, dtype="S", dec=0, kw="COLHDG('Last payment' 'YYYYMMDD')"),
    dds(name="INSTS", length=1, dtype="A", kw="COLHDG('Status' 'O/P')"),
    dds("K", "ININV"),
])
write("qddssrc/arinvl1.lf", [
    ddsc("ARINVL1 - Invoices by customer, due date, invoice"),
    dds("R", "ARINVR", kw="PFILE(ARINVP)"),
    dds("K", "INCUST"),
    dds("K", "INDUE"),
    dds("K", "ININV"),
])
write("qddssrc/arpayp.pf", [
    ddsc("ARPAYP - Payments received, posted by ARR200 (fictional data)"),
    dds(kw="UNIQUE"),
    dds("R", "ARPAYR", kw="TEXT('Payment')"),
    dds(name="PYBAT", length=5, dtype="S", dec=0, kw="COLHDG('Batch')"),
    dds(name="PYSEQ", length=5, dtype="S", dec=0, kw="COLHDG('Seq')"),
    dds(name="PYCUST", length=6, dtype="S", dec=0, kw="COLHDG('Customer')"),
    dds(name="PYDATE", length=8, dtype="S", dec=0, kw="COLHDG('Pay date' 'YYYYMMDD')"),
    dds(name="PYAMT", length=9, dtype="P", dec=2, kw="COLHDG('Amount')"),
    dds(name="PYSTS", length=1, dtype="A", kw="COLHDG('Status' 'blank/P/E')"),
    dds(name="PYMSG", length=30, dtype="A", kw="COLHDG('Message')"),
    dds("K", "PYBAT"),
    dds("K", "PYSEQ"),
])

# ================================================================== ARR200
arr200 = [
    H("DATEDIT(*YMD)"),
    Ic("================================================================"),
    Ic(" ARR200 - Post customer payments (legacy style, fixed format)"),
    Ic(" Every new payment (PYSTS = ' ') is applied to the customer's"),
    Ic(" open invoices, oldest due date first. Paid invoices get INSTS"),
    Ic(" 'P'. Customer balance goes down by the payment; a customer on"),
    Ic(" hold is released when the balance drops to zero or below."),
    Ic(" Errors: amount <= 0, customer not found -> PYSTS 'E'."),
    Ic(" Money left after all invoices stays as unapplied credit."),
    Ic(" Indicators: 90 customer not found, 98 end of invoices,"),
    Ic("             99 end of payments"),
    Ic("================================================================"),
    F("ARPAYP", "U", "F", "E", key="K"),
    F("ARCUSTP", "U", "F", "E", key="K"),
    F("ARINVL1", "U", "F", "E", key="K"),
    D("MSGAMT", "C", kw="CONST('INVALID AMOUNT')"),
    D("MSGCUS", "C", kw="CONST('CUSTOMER NOT FOUND')"),
    D("MSGUNA", "C", kw="CONST('UNAPPLIED CREDIT')"),
    D("WREMN", "S", 9, "P", 2),
    D("WAPPLY", "S", 9, "P", 2),
    D("WOPEN", "S", 9, "P", 2),
    Cc(),
    C(op="READ", f2="ARPAYR", eq="99"),
    C(f1="*IN99", op="DOWEQ", f2="*OFF"),
    C(f1="PYSTS", op="IFEQ", f2="' '"),
    C(op="EXSR", f2="POSTPY"),
    C(op="ENDIF"),
    C(op="READ", f2="ARPAYR", eq="99"),
    C(op="ENDDO"),
    C(op="MOVE", f2="*ON", res="*INLR"),
    Cc(),
    Cc("----------------------------------------------------------------"),
    Cc(" POSTPY - post one payment"),
    Cc("----------------------------------------------------------------"),
    C(f1="POSTPY", op="BEGSR"),
    C(op="MOVE", f2="*BLANKS", res="PYMSG"),
    C(f1="PYAMT", op="IFLE", f2="0"),
    C(op="MOVE", f2="'E'", res="PYSTS"),
    C(op="MOVEL", f2="MSGAMT", res="PYMSG"),
    C(op="UPDATE", f2="ARPAYR"),
    C(op="GOTO", f2="ENDPST"),
    C(op="ENDIF"),
    Cc(),
    C(f1="PYCUST", op="CHAIN", f2="ARCUSTR", hi="90"),
    C(f1="*IN90", op="IFEQ", f2="*ON"),
    C(op="MOVE", f2="'E'", res="PYSTS"),
    C(op="MOVEL", f2="MSGCUS", res="PYMSG"),
    C(op="UPDATE", f2="ARPAYR"),
    C(op="GOTO", f2="ENDPST"),
    C(op="ENDIF"),
    Cc(),
    Cc(" apply to open invoices, oldest due date first"),
    C(op="Z-ADD", f2="PYAMT", res="WREMN"),
    C(f1="PYCUST", op="SETLL", f2="ARINVR"),
    C(f1="PYCUST", op="READE", f2="ARINVR", eq="98"),
    C(f1="*IN98", op="DOWEQ", f2="*OFF"),
    C(f1="WREMN", op="ANDGT", f2="0"),
    C(f1="INSTS", op="IFEQ", f2="'O'"),
    C(f1="INAMT", op="SUB", f2="INPAID", res="WOPEN"),
    C(f1="WREMN", op="IFGE", f2="WOPEN"),
    C(op="Z-ADD", f2="WOPEN", res="WAPPLY"),
    C(op="MOVE", f2="'P'", res="INSTS"),
    C(op="ELSE"),
    C(op="Z-ADD", f2="WREMN", res="WAPPLY"),
    C(op="ENDIF"),
    C(op="ADD", f2="WAPPLY", res="INPAID"),
    C(op="SUB", f2="WAPPLY", res="WREMN"),
    C(op="Z-ADD", f2="PYDATE", res="INLPDT"),
    C(op="UPDATE", f2="ARINVR"),
    C(op="ENDIF"),
    C(f1="PYCUST", op="READE", f2="ARINVR", eq="98"),
    C(op="ENDDO"),
    Cc(),
    C(op="SUB", f2="PYAMT", res="CUBAL"),
    C(f1="CUSTAT", op="IFEQ", f2="'H'"),
    C(f1="CUBAL", op="ANDLE", f2="0"),
    C(op="MOVE", f2="'A'", res="CUSTAT"),
    C(op="ENDIF"),
    C(op="UPDATE", f2="ARCUSTR"),
    C(op="MOVE", f2="'P'", res="PYSTS"),
    C(f1="WREMN", op="IFGT", f2="0"),
    C(op="MOVEL", f2="MSGUNA", res="PYMSG"),
    C(op="ENDIF"),
    C(op="UPDATE", f2="ARPAYR"),
    C(f1="ENDPST", op="TAG"),
    C(op="ENDSR"),
]
write("qrpglesrc/arr200.rpgle", arr200)


# ================================================================== ARR300 (cycle)
def ospecs(key):
    out = []
    for end, item in REPORT[key]:
        kind = item[0]
        if kind == "c":
            out.append(OFLD(end, const=item[1]))
        elif kind == "w":
            out.append(OFLD(end, field=item[1], const=item[2]))
        else:
            out.append(OFLD(end, field=item[1], edit=item[2]))
    return out


arr300 = [
    H("DATEDIT(*YMD)"),
    Ic("================================================================"),
    Ic(" ARR300 - Aged trial balance (legacy style: RPG cycle)"),
    Ic(" Primary file ARINVL1 drives the cycle; L1 = customer break."),
    Ic(" Parameter: as-of date, 8 characters YYYYMMDD."),
    Ic(" Open amount of each open invoice goes into one age bucket by"),
    Ic(" days past due: current (<= 0), 1-30, 31-60, 61-90, over 90."),
    Ic(" Indicators: 01 invoice record, 40 invoice is open,"),
    Ic("             50 customer has open amount, 90 customer missing"),
    Ic("================================================================"),
    F("ARINVL1", "I", "P", "E", key="K"),
    F("ARCUSTP", "I", "F", "E", key="K"),
    F("QSYSPRT", "O", "", "F", reclen=132, device="PRINTER", kw="OFLIND(*INOF)"),
    D("WASOF", "S", 8, "S", 0),
    D("WASODT", "S", "", "D", kw="DATFMT(*ISO)"),
    D("WDUE", "S", "", "D", kw="DATFMT(*ISO)"),
    D("WDAYS", "S", 5, "P", 0),
    D("WOPEN", "S", 9, "P", 2),
] + [D(n, "S", 9, "P", 2) for n in ["D1CUR", "D1030", "D1060", "D1090", "D1OVR"]] \
  + [D(n, "S", 11, "P", 2) for n in ["T1CUR", "T1030", "T1060", "T1090", "T1OVR", "T1TOT",
                                     "TLCUR", "TL030", "TL060", "TL090", "TLOVR", "TLTOT"]] + [
    IREC("ARINVR", "01"),
    IFLD("INCUST", "L1"),
    Cc(),
    C(f1="*ENTRY", op="PLIST"),
    C(op="PARM", res="PASOF", length=8),
    Cc(),
    Cc(" first invoice of a customer: reset its totals, get its name"),
    C(ind="L1", op="Z-ADD", f2="0", res="T1CUR"),
    C(ind="L1", op="Z-ADD", f2="0", res="T1030"),
    C(ind="L1", op="Z-ADD", f2="0", res="T1060"),
    C(ind="L1", op="Z-ADD", f2="0", res="T1090"),
    C(ind="L1", op="Z-ADD", f2="0", res="T1OVR"),
    C(ind="L1", op="Z-ADD", f2="0", res="T1TOT"),
    C(ind="L1", f1="INCUST", op="CHAIN", f2="ARCUSTR", hi="90"),
    C(ind="90", op="MOVEL", f2="'*UNKNOWN*'", res="CUNAME"),
    Cc(),
    C(op="SETOFF", hi="40"),
    C(f1="INSTS", op="IFEQ", f2="'O'"),
    C(op="SETON", hi="40"),
    C(f1="INAMT", op="SUB", f2="INPAID", res="WOPEN"),
    C(f1="*ISO", op="MOVE", f2="INDUE", res="WDUE"),
    C(f1="WASODT", op="SUBDUR", f2="WDUE", res="WDAYS:*D"),
    C(op="Z-ADD", f2="0", res="D1CUR"),
    C(op="Z-ADD", f2="0", res="D1030"),
    C(op="Z-ADD", f2="0", res="D1060"),
    C(op="Z-ADD", f2="0", res="D1090"),
    C(op="Z-ADD", f2="0", res="D1OVR"),
    C(op="SELECT"),
    C(f1="WDAYS", op="WHENLE", f2="0"),
    C(op="Z-ADD", f2="WOPEN", res="D1CUR"),
    C(op="ADD", f2="WOPEN", res="T1CUR"),
    C(f1="WDAYS", op="WHENLE", f2="30"),
    C(op="Z-ADD", f2="WOPEN", res="D1030"),
    C(op="ADD", f2="WOPEN", res="T1030"),
    C(f1="WDAYS", op="WHENLE", f2="60"),
    C(op="Z-ADD", f2="WOPEN", res="D1060"),
    C(op="ADD", f2="WOPEN", res="T1060"),
    C(f1="WDAYS", op="WHENLE", f2="90"),
    C(op="Z-ADD", f2="WOPEN", res="D1090"),
    C(op="ADD", f2="WOPEN", res="T1090"),
    C(op="OTHER"),
    C(op="Z-ADD", f2="WOPEN", res="D1OVR"),
    C(op="ADD", f2="WOPEN", res="T1OVR"),
    C(op="ENDSL"),
    C(op="ADD", f2="WOPEN", res="T1TOT"),
    C(op="ENDIF"),
    Cc(),
    Cc(" customer total time: roll into grand totals"),
    C(lvl="L1", f1="T1TOT", op="COMP", f2="0", hi="50", lo="50"),
    C(lvl="L1", op="ADD", f2="T1CUR", res="TLCUR"),
    C(lvl="L1", op="ADD", f2="T1030", res="TL030"),
    C(lvl="L1", op="ADD", f2="T1060", res="TL060"),
    C(lvl="L1", op="ADD", f2="T1090", res="TL090"),
    C(lvl="L1", op="ADD", f2="T1OVR", res="TLOVR"),
    C(lvl="L1", op="ADD", f2="T1TOT", res="TLTOT"),
    Cc(),
    C(f1="*INZSR", op="BEGSR"),
    C(op="MOVE", f2="PASOF", res="WASOF"),
    C(f1="*ISO", op="MOVE", f2="WASOF", res="WASODT"),
    C(op="ENDSR"),
    Ic(),
    OREC("QSYSPRT", "H", ind="1P", kb=1, sa=2),
    OREC("", "", ind="OF", rel="OR"),
] + ospecs("H1") + [
    OREC("", "H", ind="1P", sa=2),
    OREC("", "", ind="OF", rel="OR"),
] + ospecs("H2") + [
    OREC("", "D", ind="01 40", sa=1),
] + ospecs("D1") + [
    OREC("", "T", ind="L1 50", sb=0, sa=2),
] + ospecs("T1") + [
    OREC("", "T", ind="LR", sb=1, sa=1),
] + ospecs("TL")
# O-spec indicators: N in 21/24/27, indicator in 22-23/25-26/28-29
write("qrpglesrc/arr300.rpgle", arr300)

write("qclsrc/arc100.clp", [
    "/* ARC100 - Accounts receivable daily run (legacy style)         */",
    "/* 1. post payments  2. print aged trial balance                  */",
    "             PGM        PARM(&ASOF)",
    "             DCL        VAR(&ASOF) TYPE(*CHAR) LEN(8)",
    "",
    "             CALL       PGM(ARR200)",
    "             CALL       PGM(ARR300) PARM(&ASOF)",
    "             ENDPGM",
])
print("ok")


# ================================================================== stage 01: printer file ARR310P from the same layout
FREE = ROOT / "01-free"
NUMDEF = {  # numeric fields: (length, decimals)
    "WASOF": (8, 0), "ININV": (7, 0), "INIDAT": (8, 0), "INDUE": (8, 0), "WDAYS": (5, 0), "CUCUST": (6, 0),
    "D1CUR": (9, 2), "D1030": (9, 2), "D1060": (9, 2), "D1090": (9, 2), "D1OVR": (9, 2), "WOPEN": (9, 2),
}
for _n in ["T1CUR", "T1030", "T1060", "T1090", "T1OVR", "T1TOT", "TLCUR", "TL030", "TL060", "TL090", "TLOVR", "TLTOT"]:
    NUMDEF[_n] = (11, 2)


def edited_width(name, code):
    ln_, dec = NUMDEF[name]
    if code == "":
        return ln_
    intd = ln_ - dec
    commas = (intd - 1) // 3 if code in "1234ABCDJKNO" else 0
    point = 1 if dec else 0
    sign = 1 if code in "JKLMNOPQ" else 0
    return ln_ + commas + point + sign


def dds_pos(name="", length="", dtype="", dec="", pos="", kw=""):
    b = ln("A", 80)
    if name:
        put(b, 19, name)
    if length != "":
        put(b, 30, str(length).rjust(5))
    if dtype:
        put(b, 35, dtype)
    if dec != "":
        put(b, 36, str(dec).rjust(2))
    if pos != "":
        put(b, 42, str(pos).rjust(3))
    if kw:
        put(b, 45, kw)
    return "".join(b).rstrip()


def prtf_rec(key, rkw):
    out = [dds("R", key, kw=rkw)]
    for end, item in REPORT[key]:
        kind = item[0]
        if kind == "c":
            out.append(dds_pos(pos=end - len(item[1]) + 1, kw="'" + item[1] + "'"))
        elif kind == "w":
            n = item[1]
            out.append(dds_pos(n, NUMDEF[n][0], "S", NUMDEF[n][1], end - 10 + 1, "EDTWRD('" + item[2] + "')"))
        else:
            n, code = item[1], item[2]
            if n == "PAGE":
                out.append(dds_pos(pos=end - 4 + 1, kw="PAGNBR"))
                out.append(dds_pos(kw="EDTCDE(Z)"))
            elif n == "CUNAME":
                out.append(dds_pos(n, 30, "A", "", end - 30 + 1))
            else:
                w = edited_width(n, code)
                out.append(dds_pos(n, NUMDEF[n][0], "S", NUMDEF[n][1], end - w + 1,
                                   f"EDTCDE({code})" if code else ""))
    return out


prtf = [ddsc("ARR310P - Aged trial balance, 132 columns (stage 1)"),
        ddsc("Same layout as the O-specs of legacy ARR300, generated from one table")]
prtf += prtf_rec("H1", "SKIPB(1) SPACEA(2)")
prtf += prtf_rec("H2", "SPACEA(2)")
prtf += prtf_rec("D1", "SPACEA(1)")
prtf += prtf_rec("T1", "SPACEA(2)")
prtf += prtf_rec("TL", "SPACEB(1) SPACEA(1)")
p = FREE / "qddssrc" / "arr310p.prtf"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_bytes(("\n".join(prtf) + "\n").encode("utf-8"))
print("ok prtf")
