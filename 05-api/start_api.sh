#!/QOpenSys/pkgs/bin/bash
# Start the AR REST API on the IBM i (stage 5).
# From a PC, one command opens an SSH tunnel and starts the server:
#   ssh -t -p 2222 -L 48410:127.0.0.1:48410 USER@pub400.com \
#       /QOpenSys/pkgs/bin/bash /home/USER/ar/api/start_api.sh
# Then open http://localhost:48410/api/aging?asof=2026-10-31 on the PC.
# Ctrl+C stops it. No password is needed: itoolkit runs inside this job.
export AR_LIB=${AR_LIB:-DODIKIBMI1}
export AR_DATA=${AR_DATA:-DODIKIBMI2}
export PORT=${PORT:-48410}
cd "$(dirname "$0")" || exit 1
exec /QOpenSys/pkgs/bin/python3.9 server.py
