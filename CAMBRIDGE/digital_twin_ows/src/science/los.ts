import type { ChannelStatus, LosChannel, OpticalDetector, OpticalEmitter, OpticalScene, Vector3 } from './types'

const DEG_TO_RAD = Math.PI / 180
const COSINE_ROUNDOFF_TOLERANCE = 8 * Number.EPSILON

function validateVector(value: Vector3, name: string): void {
  if (!Array.isArray(value) || value.length !== 3 || !Number.isFinite(value[0]) || !Number.isFinite(value[1]) || !Number.isFinite(value[2])) {
    throw new RangeError(`${name} must contain exactly three finite coordinates`)
  }
}

function unitNormal(value: Vector3, name: string): Vector3 {
  validateVector(value, name)
  const scale = Math.max(Math.abs(value[0]), Math.abs(value[1]), Math.abs(value[2]))
  if (scale === 0) throw new RangeError(`${name} must have nonzero length`)
  const scaled = [value[0] / scale, value[1] / scale, value[2] / scale] as const
  const length = Math.hypot(...scaled)
  return [scaled[0] / length, scaled[1] / length, scaled[2] / length]
}

function dot(a: Vector3, b: Vector3): number {
  return Math.max(-1, Math.min(1, a[0] * b[0] + a[1] * b[1] + a[2] * b[2]))
}

export function lambertianOrder(halfPowerAngleDeg: number): number {
  if (!Number.isFinite(halfPowerAngleDeg) || halfPowerAngleDeg <= 0 || halfPowerAngleDeg >= 90) {
    throw new RangeError('LED half-power angle must be finite and strictly between 0 and 90 degrees')
  }
  const order = -Math.log(2) / Math.log(Math.cos(halfPowerAngleDeg * DEG_TO_RAD))
  if (!Number.isFinite(order) || order <= 0) throw new RangeError('LED half-power angle produces an unrepresentable Lambertian order')
  return order
}

function validateDetector(detector: OpticalDetector): Vector3 {
  validateVector(detector.position, 'Detector position')
  const normal = unitNormal(detector.normal, 'Detector normal')
  if (!Number.isFinite(detector.areaM2) || detector.areaM2 <= 0) {
    throw new RangeError('Active detector area must be finite and positive')
  }
  if (!Number.isFinite(detector.fovHalfAngleDeg) || detector.fovHalfAngleDeg <= 0 || detector.fovHalfAngleDeg > 90) {
    throw new RangeError('Detector FOV half-angle must be finite and in (0, 90] degrees')
  }
  return normal
}

export function evaluateLos(emitter: OpticalEmitter, detector: OpticalDetector): LosChannel {
  validateVector(emitter.position, 'Emitter position')
  const emitterNormal = unitNormal(emitter.normal, 'Emitter normal')
  const detectorNormal = validateDetector(detector)
  const order = lambertianOrder(emitter.halfPowerAngleDeg)
  if (!Number.isFinite(emitter.powerW) || emitter.powerW < 0) {
    throw new RangeError('Transmitted optical power must be finite and nonnegative')
  }
  const displacement: Vector3 = [
    detector.position[0] - emitter.position[0],
    detector.position[1] - emitter.position[1],
    detector.position[2] - emitter.position[2],
  ]
  const distanceM = Math.hypot(...displacement)
  if (!Number.isFinite(distanceM) || distanceM === 0) {
    throw new RangeError('Emitter and detector must have a finite, nonzero separation')
  }
  const direction: Vector3 = [displacement[0] / distanceM, displacement[1] / distanceM, displacement[2] / distanceM]
  const cosPhi = dot(emitterNormal, direction)
  const cosPsi = -dot(detectorNormal, direction)
  let status: ChannelStatus = 'los'
  if (emitter.powerW === 0) status = 'off'
  else if (cosPhi <= 0) status = 'outside-emission'
  else if (cosPsi <= 0 || cosPsi + COSINE_ROUNDOFF_TOLERANCE < Math.cos(detector.fovHalfAngleDeg * DEG_TO_RAD)) status = 'outside-fov'
  const powerW = status === 'los'
    ? emitter.powerW * (order + 1) * detector.areaM2 / (2 * Math.PI) / distanceM / distanceM * cosPhi ** order * cosPsi
    : 0
  if (!Number.isFinite(powerW)) throw new RangeError('Received optical power exceeds the finite numerical range')
  return {
    id: emitter.id,
    powerW,
    distanceM,
    irradianceAngleDeg: Math.acos(cosPhi) / DEG_TO_RAD,
    incidenceAngleDeg: Math.acos(cosPsi) / DEG_TO_RAD,
    status,
  }
}

export function evaluateScene(scene: OpticalScene): LosChannel[] {
  validateDetector(scene.detector)
  return scene.emitters.map((emitter) => evaluateLos(emitter, scene.detector))
}
