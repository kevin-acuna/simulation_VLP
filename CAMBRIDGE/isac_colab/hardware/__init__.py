"""
Gantry + MTRS drivers of the ISAC testbed (copied from the database_acquisition tool, same behaviour).

    testbed.Testbed   builds/connects the gantry and the MTRS from config/devices.toml + joint pose methods
    gantry.Gantry     igus DLE-RG-0012-BLDC through CRI (cri_lib)
    mtrs.MTRS         Thorlabs MTRS through Kinesis .NET (pythonnet)
    sim.*             simulated gantry / MTRS with the same interface (tests without hardware)
"""
