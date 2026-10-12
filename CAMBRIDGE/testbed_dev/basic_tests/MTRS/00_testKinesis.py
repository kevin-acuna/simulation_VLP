import os
import clr

KINESIS_PATH = r"C:\Program Files\Thorlabs\Kinesis"

# Permitir a Python encontrar las DLL dependientes
os.add_dll_directory(KINESIS_PATH)

# Cargar la DLL principal de Kinesis
clr.AddReference(
    os.path.join(
        KINESIS_PATH,
        "Thorlabs.MotionControl.DeviceManagerCLI.dll"
    )
)

from Thorlabs.MotionControl.DeviceManagerCLI import DeviceManagerCLI

print("✓ pythonnet funciona")
print("✓ DeviceManagerCLI cargada correctamente")

# Pedir a Kinesis que busque dispositivos
DeviceManagerCLI.BuildDeviceList()

devices = DeviceManagerCLI.GetDeviceList()

print(f"✓ Kinesis responde correctamente")
print(f"Dispositivos encontrados: {devices.Count}")

for serial in devices:
    print("  ", serial)

print("\nTEST COMPLETADO")