export type Vector3 = readonly [number, number, number]

export interface NoiseParameters {
  enabled: boolean
  varianceW2: number
  averagingSamples: number
  seed: number
}

export interface OpticalParameters {
  halfPowerAngleDeg: number
  detectorAreaM2: number
  fovHalfAngleDeg: number
  noise: NoiseParameters
}

export interface OpticalEmitter {
  id: string
  position: Vector3
  normal: Vector3
  powerW: number
  halfPowerAngleDeg: number
}

export interface OpticalDetector {
  position: Vector3
  normal: Vector3
  areaM2: number
  fovHalfAngleDeg: number
}

export interface OpticalScene {
  emitters: readonly OpticalEmitter[]
  detector: OpticalDetector
}

export type ChannelStatus = 'los' | 'outside-fov' | 'outside-emission' | 'off'

export interface LosChannel {
  id: string
  powerW: number
  distanceM: number
  irradianceAngleDeg: number
  incidenceAngleDeg: number
  status: ChannelStatus
}

export interface RssChannel extends LosChannel {
  rssW: number
  standardDeviationW: number
}
