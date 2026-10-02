from cri_lib.cri_controller import CRIController
import time


# ============================================================
# SIMULATION ONLY
# ============================================================

IP = "127.0.0.1"
PORT = 3921

DX = 10.0          # mm
VELOCITY = 10.0    # mm/s
OVERRIDE = 10.0    # %


# Safety guard: this script must NEVER control the real robot
if IP != "127.0.0.1":
    raise RuntimeError("This script is for SIMULATION ONLY.")


robot = CRIController()

try:
    # --------------------------------------------------------
    # 1. Connect
    # --------------------------------------------------------
    print(f"Connecting to simulation at {IP}:{PORT}...")

    robot.connect(IP, PORT)
    time.sleep(0.5)

    print("Connected.")
    print("Robot:", robot.robot_state.robot_type)
    print("Version:", robot.robot_state.robot_control_version)

    p = robot.robot_state.position_robot

    print("\nInitial position:")
    print(f"X = {p.X:.2f} mm")
    print(f"Y = {p.Y:.2f} mm")
    print(f"Z = {p.Z:.2f} mm")

    # --------------------------------------------------------
    # 2. Acquire active control
    # --------------------------------------------------------
    print("\nRequesting active control...")

    if not robot.set_active_control(True):
        raise RuntimeError("Could not acquire active control.")

    print("Active control acquired.")

    # --------------------------------------------------------
    # 3. Reset and enable
    # --------------------------------------------------------
    print("Resetting controller...")

    if not robot.reset():
        raise RuntimeError("Reset failed.")

    print("Enabling robot...")

    if not robot.enable():
        raise RuntimeError("Enable failed.")

    # --------------------------------------------------------
    # 4. Wait until controller is ready
    # --------------------------------------------------------
    print("Waiting for kinematics...")

    if not robot.wait_for_kinematics_ready(timeout=10):
        raise RuntimeError("Kinematics did not become ready.")

    print("Robot ready.")

    # --------------------------------------------------------
    # 5. Limit global speed
    # --------------------------------------------------------
    if not robot.set_override(OVERRIDE):
        raise RuntimeError("Could not set override.")

    print(f"Override set to {OVERRIDE:.0f}%.")

    # --------------------------------------------------------
    # 6. Move +10 mm in X
    # --------------------------------------------------------
    print(f"\nMoving +{DX:.1f} mm in X...")

    success = robot.move_base_relative(
        X=DX,
        Y=0,
        Z=0,
        A=0,
        B=0,
        C=0,
        E1=0,
        E2=0,
        E3=0,
        velocity=VELOCITY,
        wait_move_finished=True
    )

    if not success:
        raise RuntimeError("Movement +X failed.")

    time.sleep(0.2)

    p = robot.robot_state.position_robot

    print("Movement completed.")
    print(f"X = {p.X:.2f} mm")
    print(f"Y = {p.Y:.2f} mm")
    print(f"Z = {p.Z:.2f} mm")

    # --------------------------------------------------------
    # 7. Return -10 mm in X
    # --------------------------------------------------------
    print(f"\nReturning -{DX:.1f} mm in X...")

    success = robot.move_base_relative(
        X=-DX,
        Y=0,
        Z=0,
        A=0,
        B=0,
        C=0,
        E1=0,
        E2=0,
        E3=0,
        velocity=VELOCITY,
        wait_move_finished=True
    )

    if not success:
        raise RuntimeError("Movement -X failed.")

    time.sleep(0.2)

    p = robot.robot_state.position_robot

    print("Returned.")
    print(f"X = {p.X:.2f} mm")
    print(f"Y = {p.Y:.2f} mm")
    print(f"Z = {p.Z:.2f} mm")


finally:
    print("\nCleaning up...")

    try:
        robot.disable()
    except Exception:
        pass

    try:
        robot.set_active_control(False)
    except Exception:
        pass

    robot.close()

    print("Connection closed.")