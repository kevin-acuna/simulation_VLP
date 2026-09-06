import type { NoiseParameters, OpticalScene } from '../science/types'
import { getFixtures } from './config'
import { getPhotodiodePosition } from './receiver'
import type { TwinConfig } from './types'

export function toOpticalScene(config: TwinConfig): OpticalScene {
  return {
    emitters: getFixtures(config).map((fixture) => ({
      id: fixture.id,
      position: fixture.position,
      normal: [0, 0, -1],
      powerW: fixture.power,
      halfPowerAngleDeg: config.optical.halfPowerAngleDeg,
    })),
    detector: {
      position: getPhotodiodePosition(config.receiver),
      normal: [0, 0, 1],
      areaM2: config.optical.detectorAreaM2,
      fovHalfAngleDeg: config.optical.fovHalfAngleDeg,
    },
  }
}

export function opticalScenarioKey(scene: OpticalScene, noise: NoiseParameters): string {
  return JSON.stringify({
    emitters: scene.emitters.map((emitter) => ({
      id: emitter.id,
      position: emitter.position,
      normal: emitter.normal,
      powerW: emitter.powerW,
      halfPowerAngleDeg: emitter.halfPowerAngleDeg,
    })),
    detector: {
      normal: scene.detector.normal,
      areaM2: scene.detector.areaM2,
      fovHalfAngleDeg: scene.detector.fovHalfAngleDeg,
    },
    noise: {
      enabled: noise.enabled,
      varianceW2: noise.varianceW2,
      averagingSamples: noise.averagingSamples,
      seed: noise.seed,
    },
  })
}
