import os
import clr

KINESIS_PATH = r"C:\Program Files\Thorlabs\Kinesis"

# Mantener abierta la ruta de DLL
dll_dir = os.add_dll_directory(KINESIS_PATH)

# Cargar DeviceManager
clr.AddReference(
    os.path.join(
        KINESIS_PATH,
        "Thorlabs.MotionControl.DeviceManagerCLI.dll"
    )
)

from Thorlabs.MotionControl.DeviceManagerCLI import (
    DeviceManagerCLI,
    DeviceFactory
)


print("\n=== TEST MTRS 1: DETECCION ===\n")

# Buscar dispositivos Thorlabs
DeviceManagerCLI.BuildDeviceList()

devices = DeviceManagerCLI.GetDeviceList()

print(f"Dispositivos encontrados: {devices.Count}\n")

if devices.Count == 0:
    raise RuntimeError(
        "No se encontro ningun dispositivo Thorlabs."
    )

for serial in devices:

    serial = str(serial)

    print(f"Serial number: {serial}")

    try:
        info = DeviceFactory.GetDeviceInfo(serial)

        print(f"Nombre:        {info.GetStdDeviceName()}")
        print(f"Type ID:       {info.GetTypeID()}")

    except Exception as e:
        print("No se pudo obtener informacion adicional.")
        print(e)

    print()


print("=== TEST COMPLETADO ===")