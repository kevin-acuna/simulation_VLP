#from cri_lib.cri_controller import CRIClient
from cri_lib.cri_controller import CRIController
import time

IP = "127.0.0.1"
PORT = 3921

#robot = CRIClient()
robot = CRIController()

try:
    print(f"Connecting to {IP}:{PORT}...")

    robot.connect(IP, PORT)

    # Esperar a que lleguen mensajes STATUS desde iRC
    time.sleep(1)

    state = robot.robot_state

    print("\n=== CONNECTION OK ===")
    print("Robot type:", state.robot_type)
    print("Robot configuration:", state.robot_configuration)
    print("RobotControl version:", state.robot_control_version)

    print("\n=== CARTESIAN POSITION ===")
    print("X:", state.position_robot.X, "mm")
    print("Y:", state.position_robot.Y, "mm")
    print("Z:", state.position_robot.Z, "mm")
    print("A:", state.position_robot.A, "deg")
    print("B:", state.position_robot.B, "deg")
    print("C:", state.position_robot.C, "deg")

    print("\n=== JOINTS ===")
    print("A1:", state.joints_current.A1)
    print("A2:", state.joints_current.A2)
    print("A3:", state.joints_current.A3)

    print("\n=== STATUS ===")
    print("Emergency stop OK:", state.emergency_stop_ok)
    print("Kinematics:", state.kinematics_state)
    print("Referencing:", state.referencing_state.global_state)

finally:
    robot.close()
    print("\nConnection closed.")