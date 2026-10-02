import os
import time
import clr

from System import Decimal


# ============================================================
# CONFIGURACION
# ============================================================

KINESIS_PATH = r"C:\Program Files\Thorlabs\Kinesis"

MOVE_DEG = 2.0       # movimiento pequeño para la prueba
POLLING_MS = 250
TIMEOUT_MS = 60000


# ============================================================
# CARGAR KINESIS
# ============================================================

dll_dir = os.add_dll_directory(KINESIS_PATH)

clr.AddReference(
    os.path.join(
        KINESIS_PATH,
        "Thorlabs.MotionControl.DeviceManagerCLI.dll"
    )
)

clr.AddReference(
    os.path.join(
        KINESIS_PATH,
        "Thorlabs.MotionControl.GenericMotorCLI.dll"
    )
)

clr.AddReference(
    os.path.join(
        KINESIS_PATH,
        "Thorlabs.MotionControl.Benchtop.StepperMotorCLI.dll"
    )
)


from Thorlabs.MotionControl.DeviceManagerCLI import DeviceManagerCLI
from Thorlabs.MotionControl.Benchtop.StepperMotorCLI import BenchtopStepperMotor


# ============================================================
# BUSCAR MTRS
# ============================================================

print("\n=== TEST MTRS 2: MOVIMIENTO ===\n")

DeviceManagerCLI.BuildDeviceList()

devices = DeviceManagerCLI.GetDeviceList()

print(f"Dispositivos encontrados: {devices.Count}")

if devices.Count == 0:
    raise RuntimeError("No se encontro ningun dispositivo Thorlabs.")

if devices.Count > 1:
    print("\nHay varios dispositivos conectados:")
    for d in devices:
        print(" ", d)

    raise RuntimeError(
        "Para esta primera prueba deja conectado solamente el MTRS."
    )


serial = str(devices[0])

print(f"Usando dispositivo: {serial}")


# ============================================================
# CONECTAR AL CONTROLADOR
# ============================================================

device = None
channels = []

try:

    print("\nConectando al MTRS...")

    device = BenchtopStepperMotor.CreateBenchtopStepperMotor(serial)

    device.Connect(serial)

    time.sleep(0.5)

    info = device.GetDeviceInfo()

    print("Conexion correcta.")
    print(f"Descripcion: {info.Description}")
    print(f"Numero de canales: {info.NumChannels}")


    # ========================================================
    # PREPARAR LOS CANALES
    # ========================================================

    for channel_number in range(1, info.NumChannels + 1):

        print(f"\n--- Preparando canal {channel_number} ---")

        channel = device.GetChannel(channel_number)

        # Esperar configuracion
        if not channel.IsSettingsInitialized:

            print("Esperando inicializacion...")

            channel.WaitForSettingsInitialized(10000)

        if not channel.IsSettingsInitialized:
            raise RuntimeError(
                f"El canal {channel_number} no pudo inicializarse."
            )

        # Cargar configuracion del motor
        config = channel.LoadMotorConfiguration(channel.DeviceID)

        print(f"Configuracion: {config.DeviceSettingsName}")

        # Polling
        channel.StartPolling(POLLING_MS)

        time.sleep(0.5)

        # Activar motor
        channel.EnableDevice()

        time.sleep(0.5)

        print(f"Canal {channel_number} habilitado.")
        print(f"Posicion actual: {channel.Position}")

        channels.append(channel)


    # ========================================================
    # PROBAR CADA EJE POR SEPARADO
    # ========================================================

    for i, channel in enumerate(channels, start=1):

        print("\n========================================")
        print(f"PRUEBA DEL CANAL {i}")
        print("========================================")

        print(f"Posicion actual: {channel.Position}")

        input(
            f"\nPulsa ENTER para hacer HOME del canal {i}..."
        )

        print("Haciendo HOME...")

        channel.Home(TIMEOUT_MS)

        print("HOME completado.")
        print(f"Posicion: {channel.Position}")


        input(
            f"\nPulsa ENTER para mover el canal {i} "
            f"a {MOVE_DEG} grados..."
        )

        print(f"Moviendo a {MOVE_DEG} grados...")

        channel.MoveTo(
            Decimal(MOVE_DEG),
            TIMEOUT_MS
        )

        print("Movimiento completado.")
        print(f"Posicion: {channel.Position}")


        input(
            "\nPulsa ENTER para regresar a 0 grados..."
        )

        print("Regresando a 0 grados...")

        channel.MoveTo(
            Decimal(0.0),
            TIMEOUT_MS
        )

        print("Regreso completado.")
        print(f"Posicion final: {channel.Position}")

        input(
            "\nPulsa ENTER para continuar con el siguiente canal..."
        )


    print("\n========================================")
    print("TEST COMPLETADO CORRECTAMENTE")
    print("========================================")


finally:

    print("\nCerrando conexion...")

    for channel in channels:

        try:
            channel.StopPolling()
        except:
            pass

    if device is not None:

        try:
            device.Disconnect()
        except:
            pass

    print("Conexion cerrada.")