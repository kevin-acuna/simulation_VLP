"""
04_igus_move_positions.py

Control interactivo del gantry igus DLE-RG-0012-BLDC (RobotControl V980-14-004-4)
via CRI (cri_lib).

  - Mover a una posicion absoluta X Y Z [mm] escrita en consola.
  - Recorrer posiciones de prueba predefinidas (TEST_POSITIONS).
  - Test de ejes: mueve +X, +Y, +Z por separado para conocer la direccion fisica.
  - Durante cada movimiento se muestra la posicion actual cada REFRESH_S (100 ms).
  - Cualquier tecla (o Ctrl+C) durante un movimiento -> STOP.

Requisitos: robot referenciado (o "Referencing: Not required" en iRC), E-stop
accesible y el espacio de trabajo libre.
"""

import math
import re
import time

try:
    import msvcrt                      # Windows: detectar tecla sin bloquear
except ImportError:
    msvcrt = None

from cri_lib.cri_controller import CRIController
from cri_lib.cri_errors import CRIConnectionError
from cri_lib.robot_state import KinematicsState, ReferencingAxisState


# ============================================================
# HIPERPARAMETROS
# ============================================================

# --- Conexion ------------------------------------------------
ROBOT_IP = "192.168.3.11"        # robot real. Simulacion iRC: "127.0.0.1"
ROBOT_PORT = 3920                # robot real. Simulacion iRC: 3921
EXPECTED_ROBOT = "DLE-RG-0012-BLDC"
# Versiones del controlador aceptadas: robot real del laboratorio (14-003-3)
# y simulador iRC (14-004-4).
EXPECTED_VERSIONS = ("V980-14-003-3", "V980-14-004-4")
# cri_lib fija un timeout de conexion de solo 0.1 s; el primer intento contra el
# robot real puede tardar ~1 s, asi que se reintenta.
CONNECT_ATTEMPTS = 5
CONNECT_RETRY_PAUSE_S = 1.0

# --- Espacio de trabajo permitido (filtro de seguridad de ESTE script) ---
# Cualquier objetivo fuera de esta caja se rechaza antes de enviarlo al robot.
# (El controlador ademas tiene sus propios limites / virtual box.)
# Convencion iRC de este gantry: Z cartesiana = -A3 -> Z = 0 arriba (home) y
# Z negativa hacia abajo. 700 mm de carrera vertical = Z en [-700, 0].
WORKSPACE_MIN_MM = (0.0, 0.0, -700.0)       # X, Y, Z minimos
WORKSPACE_MAX_MM = (1400.0, 1400.0, 0.0)    # X, Y, Z maximos

# --- Movimiento ----------------------------------------------
VELOCITY_MM_S = 50.0             # velocidad cartesiana del movimiento [mm/s]
MAX_VELOCITY_MM_S = 300.0        # tope para el comando 'v' (catalogo: hasta 1000 mm/s)
ACCELERATION_PCT = 20.0          # % de la aceleracion maxima configurada (iRC por defecto: 40 %)
OVERRIDE_PCT = 100.0             # % global de velocidad del controlador (escala todo)

# --- Monitorizacion / llegada ----------------------------------
REFRESH_S = 0.1                  # periodo de refresco de la posicion en consola
POSITION_TOLERANCE_MM = 1.0      # "llego" si la distancia al objetivo es menor (repetibilidad +/-0.5 mm)
STILL_SPEED_MM_S = 0.5           # por debajo de esta velocidad se considera quieto
STALL_TIME_S = 3.0               # quieto este tiempo lejos del objetivo -> se reporta y se aborta
MOVE_TIMEOUT_MARGIN_S = 30.0     # margen sobre el tiempo estimado antes de abortar

# --- Pruebas -------------------------------------------------
AXIS_TEST_STEP_MM = 100.0        # desplazamiento del test de ejes (comando 'e')
# (nombre, X, Y, Z) en mm; None = mantener la coordenada actual
TEST_POSITIONS = [
    ("centro",        700.0,  700.0, None),
    ("esquina X- Y-", 100.0,  100.0, None),
    ("esquina X+ Y-", 1300.0, 100.0, None),
    ("esquina X+ Y+", 1300.0, 1300.0, None),
    ("esquina X- Y+", 100.0,  1300.0, None),
    ("centro",        700.0,  700.0, None),
]

CONFIRM_EACH_MOVE = True         # pedir ENTER antes de cada movimiento
DISABLE_ON_EXIT = False          # False: motores quedan habilitados al salir
                                 # (si el eje Z no tiene freno, deshabilitar puede dejarlo caer)

AXES = ("X", "Y", "Z")


# ============================================================
# ESTADO / SEGURIDAD
# ============================================================

def snapshot(robot):
    """Copia consistente del estado relevante del robot."""
    with robot.robot_state_lock:
        s = robot.robot_state
        p, j = s.position_robot, s.joints_set_point
        return {
            "pos": (p.X, p.Y, p.Z),
            "abc": (p.A, p.B, p.C),
            "ext": (j.E1, j.E2, j.E3),
            "speed": s.cart_speed_mm_per_s,
            "kin": s.kinematics_state,
            "axes_error": s.combined_axes_error,
            "estop_ok": s.emergency_stop_ok,
            "ref": s.referencing_state,
        }


def is_ready(s):
    return s["kin"] == KinematicsState.NO_ERROR and s["axes_error"] == "NoError"


def fmt_pos(pos):
    return "  ".join(f"{a}={v:8.2f}" for a, v in zip(AXES, pos))


def outside_workspace(target):
    return [
        f"{a}={v:.1f} fuera de [{lo:.0f}, {hi:.0f}]"
        for a, v, lo, hi in zip(AXES, target, WORKSPACE_MIN_MM, WORKSPACE_MAX_MM)
        if not lo <= v <= hi
    ]


class ConnectionLost(RuntimeError):
    pass


def check_connection(robot):
    if not robot.connected:
        raise ConnectionLost(
            "Se perdio la conexion con el controlador. Revisa iRC (Robot Control Log): "
            "si el robot seguia en movimiento, detenlo desde iRC o con el E-stop."
        )


def safe_stop(robot):
    try:
        check_connection(robot)
        robot.stop_move()
    except Exception as e:
        print(f"\n  NO SE PUDO ENVIAR STOP: {e}")
        raise


def key_pressed():
    if msvcrt is not None and msvcrt.kbhit():
        while msvcrt.kbhit():
            msvcrt.getwch()
        return True
    return False


# ============================================================
# MOVIMIENTO CON MONITORIZACION
# ============================================================

def wait_still(robot, timeout=10.0):
    t0 = time.perf_counter()
    while time.perf_counter() - t0 < timeout:
        s = snapshot(robot)
        print(f"\r  {fmt_pos(s['pos'])}  v={s['speed']:7.2f} mm/s  (deteniendo)   ",
              end="", flush=True)
        if abs(s["speed"]) < STILL_SPEED_MM_S:
            break
        time.sleep(REFRESH_S)
    print()


def move_to(robot, target, velocity, label=""):
    """Mueve en linea recta a `target` (X, Y, Z; None = mantener). Devuelve True si llega."""
    s = snapshot(robot)
    target = tuple(cur if t is None else float(t) for cur, t in zip(s["pos"], target))
    problems = outside_workspace(target)
    if problems:
        print(f"  RECHAZADO: {'; '.join(problems)}")
        return False
    if not is_ready(s):
        print(f"  RECHAZADO: robot no listo (kinematics={s['kin'].name}, ejes={s['axes_error']})")
        return False

    dist = math.dist(s["pos"], target)
    v_eff = velocity * OVERRIDE_PCT / 100.0
    t_est = dist / v_eff if v_eff > 0 else float("inf")
    print(f"\n  {label}  {fmt_pos(s['pos'])}  ->  {fmt_pos(target)}")
    print(f"  distancia = {dist:.1f} mm   v = {velocity:g} mm/s (override {OVERRIDE_PCT:g} %)   "
          f"tiempo estimado ~ {t_est:.1f} s")
    if dist <= POSITION_TOLERANCE_MM:
        print("  Ya esta en la posicion.")
        return True
    if CONFIRM_EACH_MOVE and input("  ENTER = mover, n = cancelar: ").strip().lower() == "n":
        print("  Cancelado.")
        return False

    ok = robot.move_cartesian(
        *target, *s["abc"], *s["ext"],
        velocity=velocity, wait_move_finished=False, acceleration=ACCELERATION_PCT,
    )
    if not ok:
        print("  El controlador rechazo el movimiento (revisa limites / mensajes en iRC).")
        return False

    print("  Moviendo... (cualquier tecla o Ctrl+C = STOP)")
    timeout = t_est + MOVE_TIMEOUT_MARGIN_S
    t0 = time.perf_counter()
    last_pos, still_since = s["pos"], None
    try:
        while True:
            time.sleep(REFRESH_S)
            s = snapshot(robot)
            now = time.perf_counter() - t0
            d = math.dist(s["pos"], target)
            moving = abs(s["speed"]) >= STILL_SPEED_MM_S or math.dist(s["pos"], last_pos) > 0.05
            last_pos = s["pos"]
            print(f"\r  [{now:6.1f} s] {fmt_pos(s['pos'])}  v={s['speed']:7.2f} mm/s  "
                  f"falta={d:8.2f} mm   ", end="", flush=True)

            check_connection(robot)
            if key_pressed():
                raise KeyboardInterrupt
            if s["kin"] != KinematicsState.NO_ERROR or s["axes_error"] != "NoError":
                print(f"\n  ERROR durante el movimiento: kinematics={s['kin'].name}, "
                      f"ejes={s['axes_error']}")
                safe_stop(robot)
                return False
            if not moving and d <= POSITION_TOLERANCE_MM:
                print(f"\n  LLEGO en {now:.1f} s. Error = {d:.2f} mm")
                return True
            if moving:
                still_since = None
            else:
                still_since = still_since or now
                if now > 2.0 and now - still_since > STALL_TIME_S:
                    print(f"\n  Detenido a {d:.1f} mm del objetivo sin llegar.")
                    return False
            if now > timeout:
                print("\n  TIMEOUT: deteniendo.")
                safe_stop(robot)
                return False
    except KeyboardInterrupt:
        print("\n  STOP solicitado.")
        safe_stop(robot)
        wait_still(robot)
        return False


def axis_test(robot, velocity):
    """Mueve +STEP (o -STEP si no cabe) en cada eje por separado y regresa."""
    print("\n=== TEST DE EJES: observa hacia donde se mueve fisicamente cada eje ===")
    for i, axis in enumerate(AXES):
        start = snapshot(robot)["pos"]
        step = AXIS_TEST_STEP_MM
        if start[i] + step > WORKSPACE_MAX_MM[i]:
            step = -step
        target = [None, None, None]
        target[i] = start[i] + step
        if not move_to(robot, target, velocity, f"[{axis} {step:+.0f} mm]"):
            return
        input(f"  Observa la direccion de {axis}{'+' if step > 0 else '-'}. ENTER para regresar...")
        back = [None, None, None]
        back[i] = start[i]
        if not move_to(robot, back, velocity, f"[{axis} regreso]"):
            return


def monitor(robot):
    print("Monitor de posicion (cualquier tecla o Ctrl+C para salir)")
    try:
        while not key_pressed():
            check_connection(robot)
            s = snapshot(robot)
            print(f"\r  {fmt_pos(s['pos'])}  v={s['speed']:7.2f} mm/s  "
                  f"kin={s['kin'].name:<10} ejes={s['axes_error']:<10}", end="", flush=True)
            time.sleep(REFRESH_S)
    except KeyboardInterrupt:
        pass
    print()


# ============================================================
# PROGRAMA PRINCIPAL
# ============================================================

HELP = """
Comandos:
  X Y Z      mover a posicion absoluta en mm, p.ej.  700 700 -300
             (Z = 0 arriba, negativa hacia abajo)
             usa * para mantener un eje, p.ej.       * * -200
  p          listar posiciones de prueba
  p N        mover a la posicion de prueba N
  t          recorrer TODAS las posiciones de prueba
  e          test de ejes (+X, +Y, +Z por separado)
  v N        cambiar velocidad a N mm/s
  m          monitor de posicion en vivo (sin mover)
  s          estado del robot
  h          ayuda
  q          salir
"""


def print_state(robot):
    s = snapshot(robot)
    print(f"  Posicion:   {fmt_pos(s['pos'])}   (A,B,C = {s['abc']})")
    print(f"  Velocidad:  {s['speed']:.2f} mm/s    v comando = {velocity:g} mm/s   "
          f"override = {OVERRIDE_PCT:g} %   acel = "
          f"{'controlador' if ACCELERATION_PCT is None else f'{ACCELERATION_PCT:g} %'}")
    print(f"  Kinematics: {s['kin'].name}   ejes: {s['axes_error']}   E-stop OK: {s['estop_ok']}")
    print(f"  Referencia: {s['ref'].global_state.name} (obligatoria: {s['ref'].mandatory})")
    out = outside_workspace(s["pos"])
    print(f"  Workspace:  {'DENTRO' if not out else 'FUERA -> ' + '; '.join(out)}")


def connect_robot():
    """Conecta con reintentos (un CRIController nuevo por intento)."""
    for attempt in range(1, CONNECT_ATTEMPTS + 1):
        print(f"Conectando a {ROBOT_IP}:{ROBOT_PORT} (intento {attempt}/{CONNECT_ATTEMPTS})...")
        r = CRIController()
        try:
            r.connect(ROBOT_IP, ROBOT_PORT,
                      application_name="Kevin-Gantry-Move", application_version="1-0-0")
            return r
        except CRIConnectionError as e:
            print(f"  fallo: {e.__cause__ or e}")
            time.sleep(CONNECT_RETRY_PAUSE_S)
    raise RuntimeError(
        f"No se pudo conectar a {ROBOT_IP}:{ROBOT_PORT}. Revisa el cable/IP del PC "
        f"(192.168.3.x) y que el controlador este encendido."
    )


def version_tuple(version):
    """'V980-14-003-3' -> (14, 3, 3)."""
    m = re.match(r"V\d+-(\d+)-(\d+)-(\d+)", version)
    return tuple(int(x) for x in m.groups()) if m else (0, 0, 0)


velocity = VELOCITY_MM_S
robot = None

try:
    print("=" * 70)
    print("IGUS GANTRY - CONTROL DE POSICION")
    print("=" * 70)
    robot = connect_robot()
    robot.wait_for_status_update(timeout=5)
    time.sleep(0.5)
    try:
        robot.get_referencing_info()
    except Exception as e:
        print(f"AVISO: no se pudo leer el estado de referencia ({e}).")

    st = robot.robot_state
    print(f"Robot:   {st.robot_type}\nVersion: {st.robot_control_version}")
    if EXPECTED_ROBOT not in st.robot_type:
        raise RuntimeError(f"El robot conectado no es {EXPECTED_ROBOT}.")
    if st.robot_control_version not in EXPECTED_VERSIONS:
        if input(f"AVISO: version no esperada {EXPECTED_VERSIONS}. Continuar? [s/N]: ").lower() != "s":
            raise SystemExit
    # El parametro de aceleracion de Move Cart requiere RobotControl >= V14-004-1
    if version_tuple(st.robot_control_version) < (14, 4, 1):
        ACCELERATION_PCT = None
        print("AVISO: esta version no admite aceleracion por movimiento; "
              "se usa la del controlador (40 % por defecto).")
    if not st.emergency_stop_ok:
        if ROBOT_IP not in ("127.0.0.1", "localhost"):
            raise RuntimeError("El circuito de E-stop no esta OK.")
        print("AVISO: E-stop no reportado como OK (normal en el simulador iRC).")

    if not robot.set_active_control(True):
        raise RuntimeError("No se pudo obtener el control activo del robot.")
    print("Control activo obtenido.")

    if not is_ready(snapshot(robot)):
        input("Motores no listos. ENTER para Reset + Enable (Ctrl+C para cancelar)...")
        if not robot.reset() or not robot.enable():
            raise RuntimeError("Reset/Enable fallo.")
        if not robot.wait_for_kinematics_ready(timeout=10):
            s = snapshot(robot)
            raise RuntimeError(f"Robot no listo: kinematics={s['kin'].name}, ejes={s['axes_error']}")

    ref = snapshot(robot)["ref"]
    if ref.mandatory and ref.global_state != ReferencingAxisState.REFERENCED:
        raise RuntimeError("Robot no referenciado. Referencialo en iRC y vuelve a ejecutar.")

    if not robot.set_override(OVERRIDE_PCT):
        raise RuntimeError("No se pudo fijar el override.")

    print("\nRobot listo.")
    print_state(robot)
    print(HELP)

    while True:
        check_connection(robot)
        try:
            cmd = input(f"\n[{fmt_pos(snapshot(robot)['pos'])}] > ").strip().lower().split()
        except (KeyboardInterrupt, EOFError):
            break
        if not cmd:
            continue

        try:
            if cmd[0] == "q":
                break
            elif cmd[0] == "h":
                print(HELP)
            elif cmd[0] == "s":
                print_state(robot)
            elif cmd[0] == "m":
                monitor(robot)
            elif cmd[0] == "e":
                axis_test(robot, velocity)
            elif cmd[0] == "v" and len(cmd) == 2:
                velocity = min(float(cmd[1]), MAX_VELOCITY_MM_S)
                print(f"  Velocidad = {velocity:g} mm/s")
            elif cmd[0] == "p" and len(cmd) == 1:
                for n, (name, *xyz) in enumerate(TEST_POSITIONS):
                    print(f"  {n}: {name:<15} {xyz}")
            elif cmd[0] == "p" and len(cmd) == 2:
                name, *xyz = TEST_POSITIONS[int(cmd[1])]
                move_to(robot, xyz, velocity, f"[{name}]")
            elif cmd[0] == "t":
                for n, (name, *xyz) in enumerate(TEST_POSITIONS):
                    if not move_to(robot, xyz, velocity, f"[{n}: {name}]"):
                        print("  Secuencia interrumpida.")
                        break
            elif len(cmd) == 3:
                move_to(robot, [None if c == "*" else float(c) for c in cmd], velocity, "[manual]")
            else:
                print("  Comando no reconocido (h = ayuda).")
        except (ValueError, IndexError):
            print("  Valor invalido (h = ayuda).")

except ConnectionLost as e:
    print(f"\n\n  {e}")

finally:
    print("\nCerrando...")
    if robot is not None and robot.connected:
        try:
            if snapshot(robot)["speed"] >= STILL_SPEED_MM_S:
                robot.stop_move()
            if DISABLE_ON_EXIT:
                robot.disable()
            robot.set_active_control(False)
        except Exception as e:
            print(f"  Aviso al cerrar: {e}")
    if robot is not None:
        robot.close()
    print("Conexion cerrada.")
