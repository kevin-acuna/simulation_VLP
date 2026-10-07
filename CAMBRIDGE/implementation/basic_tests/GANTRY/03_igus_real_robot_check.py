"""
03_igus_real_robot_check.py

READ-ONLY diagnostic test for the REAL igus gantry.

Robot expected:
    igus drylin gantry
    DLE-RG-0012-BLDC
    RobotControl V980-14-004-4
    BLDC / 48 V

IMPORTANT:
    This script DOES NOT move the robot.
    It uses CRIClient, not CRIController.

Connection expected:
    Robot IP: 192.168.3.11
    CRI port: 3920

PC Ethernet example:
    IP:      192.168.3.100
    Mask:    255.255.255.0
    Gateway: empty

======================================================================
KNOWN / PUBLISHED LIMITS
======================================================================

DLE-RG-0012 BLDC/EC family (igus catalogue):

    Degrees of freedom:     3 (X, Y, Z)
    Maximum payload:        5 kg
    Maximum speed:          up to 1.0 m/s = 1000 mm/s
    Repeatability:          +/- 0.5 mm

IMPORTANT:
    These are FAMILY / catalogue specifications.

    The exact Cambridge robot may have different:
        - X travel
        - Y travel
        - Z travel
        - software limits
        - maximum joint velocities
        - maximum Cartesian velocity
        - accelerations

    Therefore NEVER hard-code the catalogue workspace as the
    actual physical limits of the laboratory robot.

======================================================================
WHERE THE REAL LIMITS ARE STORED
======================================================================

The robot configuration XML contains:

    SoftwareMinMax
        -> minimum and maximum position of each physical axis

    JointVelocities2
        -> maximum velocity of each axis for the 48 V configuration
           Units for this gantry: mm/s

    JointAccelerations2
        -> maximum acceleration of each axis
           Units for linear axes: mm/s^2

    JointAccelerationIncs2
        -> jerk / acceleration increment
           Units for linear axes: mm/s^3

    CartVelocities2
        VelTrans -> maximum Cartesian XYZ velocity [mm/s]
        VelOri   -> maximum Cartesian orientation velocity [deg/s]

    CartAccelerations2
        AccLin    -> maximum Cartesian acceleration
        AccLinInc -> Cartesian jerk

The suffix "2" is normally the velocity set used by the 48 V
configuration.

======================================================================
CRI COMMAND LIMITS
======================================================================

Cartesian movement:
    velocity argument -> mm/s

Joint movement:
    velocity argument -> percentage of maximum velocity
    documented range: 1.0 ... 100.0 %

Acceleration argument:
    0 ... 100 % of configured maximum acceleration
    if omitted, controller default is normally 40 %

Velocity override:
    project/configuration range: 0 ... 100 %

NOTE ABOUT MINIMUM CARTESIAN SPEED:
    igus does NOT publish a single hardware minimum Cartesian speed
    for the DLE-RG-0012.

    Do NOT interpret 1 mm/s as an official minimum.

    For our first physical test we will intentionally command a LOW
    speed (for example 5-10 mm/s), but that is a conservative test
    value, not the robot's specified minimum.

======================================================================
FIRST PHYSICAL MOVEMENT - LATER, NOT IN THIS SCRIPT
======================================================================

Initial test values I propose:

    displacement:   5 mm
    velocity:       5-10 mm/s
    override:       10 %
    acceleration:   low / conservative

These are TEST SETTINGS, not robot limits.

Before any movement:
    1. E-stop physically accessible
    2. Correct robot identified
    3. Correct RobotControl version
    4. Exact robot configuration checked
    5. Robot referenced
    6. Current XYZ known
    7. Software limits known
    8. Direction of each axis understood
"""


import time

from cri_lib.cri_controller import CRIClient
from cri_lib.robot_state import KinematicsState, ReferencingAxisState


# =====================================================================
# CONNECTION
# =====================================================================

ROBOT_IP = "192.168.3.11"
ROBOT_PORT = 3920


# =====================================================================
# EXPECTED ROBOT
# =====================================================================

EXPECTED_ROBOT = "DLE-RG-0012-BLDC"
EXPECTED_VERSION = "V980-14-004-4"


def yes_no(value):
    return "YES" if value else "NO"


robot = CRIClient()


try:

    # -----------------------------------------------------------------
    # 1. CONNECT
    # -----------------------------------------------------------------

    print("=" * 70)
    print("IGUS REAL ROBOT - READ-ONLY DIAGNOSTIC")
    print("=" * 70)

    print(f"\nConnecting to {ROBOT_IP}:{ROBOT_PORT}...")

    robot.connect(
        ROBOT_IP,
        ROBOT_PORT,
        application_name="Kevin-Gantry-Diagnostic",
        application_version="1-0-0"
    )

    # Wait for fresh STATUS information from RobotControl
    robot.wait_for_status_update(timeout=5)

    # Give additional status messages time to arrive
    time.sleep(0.5)

    state = robot.robot_state

    print("Connection established.")


    # -----------------------------------------------------------------
    # 2. IDENTIFICATION
    # -----------------------------------------------------------------

    print("\n" + "=" * 70)
    print("ROBOT IDENTIFICATION")
    print("=" * 70)

    print("Robot type:          ", state.robot_type)
    print("Robot configuration: ", state.robot_configuration)
    print("RobotControl version:", state.robot_control_version)
    print("Project file:        ", state.project_file)
    print("Robot axes:          ", state.robot_axes_count)


    type_ok = EXPECTED_ROBOT in state.robot_type
    version_ok = state.robot_control_version == EXPECTED_VERSION

    print("\nExpected robot:      ", EXPECTED_ROBOT)
    print("Robot type match:    ", yes_no(type_ok))

    print("Expected version:    ", EXPECTED_VERSION)
    print("Version match:       ", yes_no(version_ok))


    # -----------------------------------------------------------------
    # 3. CARTESIAN POSITION
    # -----------------------------------------------------------------

    p = state.position_robot

    print("\n" + "=" * 70)
    print("CARTESIAN POSITION")
    print("=" * 70)

    print(f"X = {p.X:10.3f} mm")
    print(f"Y = {p.Y:10.3f} mm")
    print(f"Z = {p.Z:10.3f} mm")

    print(f"A = {p.A:10.3f} deg")
    print(f"B = {p.B:10.3f} deg")
    print(f"C = {p.C:10.3f} deg")

    print(f"\nCurrent Cartesian speed = "
          f"{state.cart_speed_mm_per_s:.3f} mm/s")


    # -----------------------------------------------------------------
    # 4. PHYSICAL AXES
    # -----------------------------------------------------------------

    j = state.joints_current

    print("\n" + "=" * 70)
    print("PHYSICAL AXES")
    print("=" * 70)

    print(f"A1 = {j.A1:10.3f}")
    print(f"A2 = {j.A2:10.3f}")
    print(f"A3 = {j.A3:10.3f}")

    print("""
For this gantry we expect approximately:

    A1 <-> one linear Cartesian axis
    A2 <-> one linear Cartesian axis
    A3 <-> vertical linear axis

Do NOT assume the signs until they have been verified physically.
""")


    # -----------------------------------------------------------------
    # 5. SAFETY / POWER STATUS
    # -----------------------------------------------------------------

    print("=" * 70)
    print("SAFETY / POWER")
    print("=" * 70)

    print("Emergency stop circuit OK:",
          state.emergency_stop_ok)

    print("Main relay:               ",
          state.main_relay)

    print("Supply voltage:            ",
          f"{state.supply_voltage:.2f} V")

    print("Total current:             ",
          f"{state.current_total:.3f} A")

    print("Active control:            ",
          state.active_control)

    print("Operation mode:            ",
          state.operation_mode)


    # -----------------------------------------------------------------
    # 6. KINEMATICS
    # -----------------------------------------------------------------

    print("\n" + "=" * 70)
    print("KINEMATICS")
    print("=" * 70)

    print("Kinematics state: ",
          state.kinematics_state)

    print("Axes error:       ",
          state.combined_axes_error)


    # -----------------------------------------------------------------
    # 7. REFERENCING
    # -----------------------------------------------------------------

    ref = state.referencing_state

    print("\n" + "=" * 70)
    print("REFERENCING")
    print("=" * 70)

    print("Referencing mandatory:",
          ref.mandatory)

    print("Global state:          ",
          ref.global_state)

    print("A1:                    ",
          ref.A1)

    print("A2:                    ",
          ref.A2)

    print("A3:                    ",
          ref.A3)


    referenced = (
        ref.global_state == ReferencingAxisState.REFERENCED
    )


    # -----------------------------------------------------------------
    # 8. AXIS ERRORS
    # -----------------------------------------------------------------

    print("\n" + "=" * 70)
    print("AXIS ERROR STATES")
    print("=" * 70)

    for i in range(state.robot_axes_count):

        err = state.error_states[i]

        print(f"\nAxis A{i + 1}:")

        print("  over temperature :", err.over_temp)
        print("  E-stop / low V   :", err.estop_lowv)
        print("  motor not enabled:", err.motor_not_enabled)
        print("  communication    :", err.com)
        print("  position lag     :", err.position_lag)
        print("  encoder           :", err.ENC)
        print("  overcurrent       :", err.overcurrent)
        print("  driver            :", err.driver)


    # -----------------------------------------------------------------
    # 9. FINAL DIAGNOSTIC
    # -----------------------------------------------------------------

    print("\n" + "=" * 70)
    print("DIAGNOSTIC SUMMARY")
    print("=" * 70)

    print("Communication:       OK")
    print("Correct robot type: ", yes_no(type_ok))
    print("Correct SW version: ", yes_no(version_ok))
    print("E-stop circuit OK:  ", yes_no(state.emergency_stop_ok))
    print("Referenced:         ", yes_no(referenced))

    print("\nIMPORTANT:")
    print("No Reset, Enable, Reference or movement command was sent.")
    print("This test was READ-ONLY.")


    # -----------------------------------------------------------------
    # 10. DECISION FOR NEXT STEP
    # -----------------------------------------------------------------

    if not type_ok:

        print("""
WARNING:
The connected robot does NOT match DLE-RG-0012-BLDC.

DO NOT proceed to movement.
""")

    elif not version_ok:

        print("""
WARNING:
RobotControl version differs from V980-14-004-4.

DO NOT proceed to movement until checked.
""")

    elif not state.emergency_stop_ok:

        print("""
WARNING:
The emergency-stop circuit is not reporting OK.

DO NOT proceed to movement.
""")

    elif not referenced:

        print("""
Robot identification and safety communication look correct,
but the robot is NOT REFERENCED.

The next step must be referencing/checking the physical axes
before attempting Cartesian motion.
""")

    else:

        print("""
Basic diagnostic conditions look correct.

DO NOT MOVE YET.

Next:
    obtain/check the REAL robot configuration limits,
    verify current XYZ versus those limits,
    then perform a very small low-speed test.
""")


finally:

    robot.close()

    print("\nConnection closed.")
    