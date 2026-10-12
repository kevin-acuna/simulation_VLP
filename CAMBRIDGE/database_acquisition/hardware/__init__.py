"""
Reusable drivers for the optical wireless positioning (OWP) testbed.

Typical use (reads config/testbed.toml, where every device is configured once):

    from hardware.testbed import Testbed
    with Testbed() as tb:
        tb.go_to_pose((700, 700, -300), 144)
        acqs = tb.scope.record(3, 100000)

Modules:
    testbed.Testbed   builds/connects the devices from the config + joint methods
    gantry.Gantry     igus DLE-RG-0012-BLDC through CRI (cri_lib)
    mtrs.MTRS         Thorlabs MTRS through Kinesis .NET (pythonnet)
    scope.Scope       Keysight/Agilent InfiniiVision (MSO-X 4154A) through pyvisa
    sim.*             simulated devices with the same interface (tests without hardware)
"""
