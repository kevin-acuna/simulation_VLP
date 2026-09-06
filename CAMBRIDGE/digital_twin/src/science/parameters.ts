import type { OpticalParameters } from './types'

export const OPTICAL_LIMITS = Object.freeze({
  halfPowerAngleDeg: Object.freeze({ min: 1, max: 89 }),
  detectorAreaM2: Object.freeze({ min: 1e-8, max: 1e-4 }),
  fovHalfAngleDeg: Object.freeze({ min: 1, max: 90 }),
  varianceW2: Object.freeze({ min: 0, max: 1e-8 }),
  averagingSamples: Object.freeze({ min: 1, max: 1e6 }),
  seed: Object.freeze({ min: 0, max: 4294967295 }),
})

export function createOpticalParameters(): OpticalParameters {
  return {
    halfPowerAngleDeg: 45,
    detectorAreaM2: 4.8e-3 * 5.5e-3,
    fovHalfAngleDeg: 85,
    noise: {
      enabled: false,
      varianceW2: 30e6 * 10 ** -21,
      averagingSamples: 1000,
      seed: 42,
    },
  }
}

function ownField(value: unknown, key: string): unknown {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return undefined
  const descriptor = Object.getOwnPropertyDescriptor(value, key)
  return descriptor && 'value' in descriptor ? descriptor.value : undefined
}

function bounded(value: unknown, fallback: number, limits: { min: number; max: number }, integer = false): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback
  const clamped = Math.min(limits.max, Math.max(limits.min, value))
  return integer ? Math.round(clamped) : clamped
}

export function normalizeOpticalParameters(value: unknown): OpticalParameters {
  const defaults = createOpticalParameters()
  const noise = ownField(value, 'noise')
  const enabled = ownField(noise, 'enabled')
  return {
    halfPowerAngleDeg: bounded(ownField(value, 'halfPowerAngleDeg'), defaults.halfPowerAngleDeg, OPTICAL_LIMITS.halfPowerAngleDeg),
    detectorAreaM2: bounded(ownField(value, 'detectorAreaM2'), defaults.detectorAreaM2, OPTICAL_LIMITS.detectorAreaM2),
    fovHalfAngleDeg: bounded(ownField(value, 'fovHalfAngleDeg'), defaults.fovHalfAngleDeg, OPTICAL_LIMITS.fovHalfAngleDeg),
    noise: {
      enabled: typeof enabled === 'boolean' ? enabled : defaults.noise.enabled,
      varianceW2: bounded(ownField(noise, 'varianceW2'), defaults.noise.varianceW2, OPTICAL_LIMITS.varianceW2),
      averagingSamples: bounded(ownField(noise, 'averagingSamples'), defaults.noise.averagingSamples, OPTICAL_LIMITS.averagingSamples, true),
      seed: bounded(ownField(noise, 'seed'), defaults.noise.seed, OPTICAL_LIMITS.seed, true),
    },
  }
}
