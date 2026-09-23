"""
AgriMind Windows Service Installer
Registers the FastAPI backend as a Windows service that starts automatically on boot.

Usage (run as Administrator):
    python service.py install    # Install the service
    python service.py start      # Start it now
    python service.py stop       # Stop it
    python service.py remove     # Uninstall the service
    python service.py status     # Check status
"""
import os
import sys
import subprocess

SERVICE_NAME = "AgriMindServer"
DISPLAY_NAME = "AgriMind - AI Agricultural Requirement System"
DESCRIPTION  = "FastAPI backend for AgriMind multilingual agricultural requirement analysis system."


def _python() -> str:
    return sys.executable


def _project_root() -> str:
    return os.path.dirname(os.path.abspath(__file__))


def _nssm() -> str:
    """Try to find nssm.exe; download it if missing."""
    paths = [
        r"C:\nssm\nssm.exe",
        r"C:\tools\nssm\nssm.exe",
        os.path.join(_project_root(), "nssm.exe"),
    ]
    for p in paths:
        if os.path.exists(p):
            return p

    # Fall back to sc.exe approach
    return None


def _run(cmd, check=True):
    print(f"  > {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.stdout: print(result.stdout.strip())
    if result.stderr: print(result.stderr.strip())
    if check and result.returncode not in (0, 1):
        raise RuntimeError(f"Command failed: {cmd}")
    return result


def install():
    print(f"\n[AgriMind] Installing Windows service: {SERVICE_NAME}")
    root = _project_root()
    python = _python()
    uvicorn = os.path.join(os.path.dirname(python), "uvicorn.exe")
    if not os.path.exists(uvicorn):
        uvicorn = f'"{python}" -m uvicorn'

    nssm = _nssm()

    if nssm:
        # ── NSSM method (best) ───────────────────────────────────────
        _run(f'"{nssm}" install {SERVICE_NAME} "{python}"')
        _run(f'"{nssm}" set {SERVICE_NAME} AppParameters "-m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000"')
        _run(f'"{nssm}" set {SERVICE_NAME} AppDirectory "{root}"')
        _run(f'"{nssm}" set {SERVICE_NAME} DisplayName "{DISPLAY_NAME}"')
        _run(f'"{nssm}" set {SERVICE_NAME} Description "{DESCRIPTION}"')
        _run(f'"{nssm}" set {SERVICE_NAME} Start SERVICE_AUTO_START')
        _run(f'"{nssm}" set {SERVICE_NAME} AppStdout "{root}\\logs\\agrimind.log"')
        _run(f'"{nssm}" set {SERVICE_NAME} AppStderr "{root}\\logs\\agrimind_err.log"')
        _run(f'"{nssm}" set {SERVICE_NAME} AppRotateFiles 1')
        _run(f'"{nssm}" set {SERVICE_NAME} AppRotateBytes 5000000')
        print(f"\n[AgriMind] Service installed via NSSM.")
    else:
        # ── SC.exe fallback ──────────────────────────────────────────
        cmd = f'"{python}" -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000'
        _run(
            f'sc create {SERVICE_NAME} '
            f'binPath= "cmd /c cd /d \\"{root}\\" && {cmd}" '
            f'DisplayName= "{DISPLAY_NAME}" '
            f'start= auto '
            f'type= own'
        )
        _run(f'sc description {SERVICE_NAME} "{DESCRIPTION}"')
        print(f"\n[AgriMind] Service installed via sc.exe.")

    os.makedirs(os.path.join(root, "logs"), exist_ok=True)
    print(f"[AgriMind] Service '{SERVICE_NAME}' installed successfully!")
    print(f"[AgriMind] Run: python service.py start")


def start():
    print(f"\n[AgriMind] Starting service: {SERVICE_NAME}")
    _run(f"sc start {SERVICE_NAME}", check=False)
    print(f"[AgriMind] Service started! Server running at http://localhost:8000")


def stop():
    print(f"\n[AgriMind] Stopping service: {SERVICE_NAME}")
    _run(f"sc stop {SERVICE_NAME}", check=False)
    print(f"[AgriMind] Service stopped.")


def remove():
    print(f"\n[AgriMind] Removing service: {SERVICE_NAME}")
    stop()
    import time; time.sleep(2)
    nssm = _nssm()
    if nssm:
        _run(f'"{nssm}" remove {SERVICE_NAME} confirm', check=False)
    else:
        _run(f"sc delete {SERVICE_NAME}", check=False)
    print(f"[AgriMind] Service removed.")


def status():
    print(f"\n[AgriMind] Service status: {SERVICE_NAME}")
    r = _run(f"sc query {SERVICE_NAME}", check=False)
    if r.returncode != 0:
        print("  Service is NOT installed.")
    else:
        lines = r.stdout.strip().split('\n')
        for line in lines:
            if 'STATE' in line or 'NAME' in line:
                print(f"  {line.strip()}")


def print_help():
    print(__doc__)


COMMANDS = {
    'install': install,
    'start': start,
    'stop': stop,
    'remove': remove,
    'status': status,
}


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print_help()
        sys.exit(0)

    # Check for admin rights
    import ctypes
    if not ctypes.windll.shell32.IsUserAnAdmin():
        print("[AgriMind] ERROR: This script must be run as Administrator!")
        print("  Right-click Command Prompt → 'Run as administrator'")
        sys.exit(1)

    COMMANDS[sys.argv[1]]()
