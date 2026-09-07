import { RotateCcw } from 'lucide-react'
import { RangeField, Toggle } from './Controls'
import {
  createOpticalParameters,
  fromNoiseSigmaNanowatts,
  fromSquareMillimeters,
  lambertianOrder,
  noiseStandardDeviation,
  OPTICAL_LIMITS,
  toMicrowatts,
  toNoiseSigmaNanowatts,
  toSquareMillimeters,
} from '../science'
import type { OpticalParameters } from '../science/types'

export interface OpticalSettingsProps {
  parameters: OpticalParameters
  onChange: (parameters: OpticalParameters) => void
}

export default function OpticalSettings({ parameters, onChange }: OpticalSettingsProps) {
  const { noise } = parameters
  const sigmaMean = toMicrowatts(noiseStandardDeviation(noise))

  function setNoise(update: Partial<OpticalParameters['noise']>) {
    onChange({ ...parameters, noise: { ...noise, ...update } })
  }

  return (
    <div className="optical-settings">
      <section className="control-section">
        <div className="section-title"><h3>Optical channel</h3><span className="optical-badge">LOS ONLY</span></div>
        <p className="section-description">Lambertian emitters and an upward-facing photodiode. Received power is calculated in watts, independently of rendered brightness.</p>
        <RangeField
          label="LED half-power angle"
          value={parameters.halfPowerAngleDeg}
          {...OPTICAL_LIMITS.halfPowerAngleDeg}
          step={0.1}
          unit="°"
          onChange={(halfPowerAngleDeg) => onChange({ ...parameters, halfPowerAngleDeg })}
        />
        <dl className="optical-readouts">
          <div><dt>Lambertian order · m</dt><dd><output aria-label="Lambertian order">{lambertianOrder(parameters.halfPowerAngleDeg).toFixed(4)}</output></dd></div>
        </dl>
        <RangeField
          label="PD active area"
          value={toSquareMillimeters(parameters.detectorAreaM2)}
          min={toSquareMillimeters(OPTICAL_LIMITS.detectorAreaM2.min)}
          max={toSquareMillimeters(OPTICAL_LIMITS.detectorAreaM2.max)}
          step={0.01}
          digits={2}
          unit="mm²"
          onChange={(area) => onChange({ ...parameters, detectorAreaM2: fromSquareMillimeters(area) })}
        />
        <p className="helper">Default active area: 4.8 × 5.5 mm = 26.4 mm² (MATLAB baseline). The drawn 1 cm × 1 cm PD is its package, not its active area.</p>
        <RangeField
          label="PD FOV half-angle"
          value={parameters.fovHalfAngleDeg}
          {...OPTICAL_LIMITS.fovHalfAngleDeg}
          step={0.1}
          unit="°"
          onChange={(fovHalfAngleDeg) => onChange({ ...parameters, fovHalfAngleDeg })}
        />
        <p className="helper">The PD normal points up along world Z. Platform yaw does not tilt it.</p>
      </section>
      <section className="control-section optical-noise">
        <div className="section-title"><h3>RSS measurement noise</h3><span>W-DOMAIN</span></div>
        <Toggle label="Gaussian RSS noise" description="Independent additive noise on each LED channel." checked={noise.enabled} onChange={(enabled) => setNoise({ enabled })} />
        <RangeField
          label="Noise standard deviation"
          value={toNoiseSigmaNanowatts(noise.varianceW2)}
          min={toNoiseSigmaNanowatts(OPTICAL_LIMITS.varianceW2.min)}
          max={toNoiseSigmaNanowatts(OPTICAL_LIMITS.varianceW2.max)}
          step={0.1}
          digits={2}
          unit="nW"
          onChange={(sigma) => setNoise({ varianceW2: fromNoiseSigmaNanowatts(sigma) })}
        />
        <p className="helper">Per-sample σ before averaging; stored variance: {noise.varianceW2.toExponential(3)} W².</p>
        <RangeField
          label="Samples averaged"
          value={noise.averagingSamples}
          {...OPTICAL_LIMITS.averagingSamples}
          step={1}
          digits={0}
          onChange={(averagingSamples) => setNoise({ averagingSamples })}
        />
        <RangeField
          label="Noise seed"
          value={noise.seed}
          {...OPTICAL_LIMITS.seed}
          step={1}
          digits={0}
          onChange={(seed) => setNoise({ seed })}
        />
        <dl className="optical-readouts">
          <div><dt>σ mean · after averaging</dt><dd><output aria-label="Averaged noise standard deviation">{sigmaMean.toPrecision(5)} µW</output></dd></div>
        </dl>
        <p className="helper">{noise.enabled ? 'Noise is enabled.' : 'Noise is off; effective σ mean is zero.'} Averaging controls measurement uncertainty, not the chart display rate. A fixed seed makes the noise reproducible.</p>
        <p className="helper">This is an additive Gaussian optical-power model in W, not a shot-noise or thermal-noise circuit model. Noisy RSS estimates may be negative; ideal optical power remains nonnegative.</p>
      </section>
      <section className="control-section optical-assumptions">
        <div className="section-title"><h3>Model boundaries</h3><span>DIRECT PATH</span></div>
        <p className="helper">LED transmitted power (Pt) and positions are controlled in Lighting. Optical LED positions use the anchor coordinates, excluding decorative housing offsets.</p>
        <p className="helper">Reflections, NLOS paths and occlusion are not modelled. Visual walls, shadows and materials do not alter the optical channel.</p>
      </section>
      <button className="reset-button" onClick={() => onChange(createOpticalParameters())}><RotateCcw size={13} />Reset optical parameters</button>
      <p className="helper optical-reset-note">Only optical and noise parameters reset; room, lighting, receiver and view remain unchanged.</p>
    </div>
  )
}
