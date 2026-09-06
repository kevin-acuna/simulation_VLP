import { Pause, Play, RotateCcw, SlidersHorizontal, X } from 'lucide-react'
import type { CSSProperties } from 'react'
import { MODEL_ID, toMicrowatts } from '../science'
import type { OpticalParameters, OpticalScene, RssChannel } from '../science/types'
import { useRssStream } from '../state/useRssStream'

export interface RssPanelProps {
  scene: OpticalScene
  parameters: OpticalParameters
  onClose: () => void
  onSettings: () => void
}

const CHART = { width: 432, height: 174, left: 54, right: 14, top: 16, bottom: 34 }
const STATUS_LABELS: Record<RssChannel['status'], string> = {
  los: 'LOS',
  'outside-fov': 'Outside FOV',
  'outside-emission': 'Outside emission',
  off: 'Off',
}

function channelStyle(id: string): CSSProperties {
  const suffix = id.match(/(\d+)$/)
  const index = suffix ? Number(suffix[1]) - 1 : Array.from(id).reduce((hash, character) => hash * 31 + character.charCodeAt(0) | 0, 0)
  return { '--rss-channel-color': `var(--rss-series-${((index % 9) + 9) % 9 + 1})` } as CSSProperties
}

function formatPower(powerW: number): string {
  return Number.isFinite(powerW) ? `${toMicrowatts(powerW).toPrecision(6)} µW` : 'Unavailable'
}

function formatTick(value: number): string {
  if (value === 0) return '0'
  return Math.abs(value) < 0.001 || Math.abs(value) >= 10000
    ? value.toExponential(1)
    : Number(value.toPrecision(3)).toString()
}

export default function RssPanel({ scene, parameters, onClose, onSettings }: RssPanelProps) {
  const { samples, paused, setPaused, clear, error } = useRssStream(scene, parameters.noise)
  const noisy = parameters.noise.enabled
  const latest = samples.at(-1)
  const series = scene.emitters.map(({ id }) => ({
    id,
    points: samples.flatMap((sample) => {
      const channel = sample.channels.find((entry) => entry.id === id)
      if (!channel || !Number.isFinite(sample.time) || !Number.isFinite(channel.powerW) || (noisy && !Number.isFinite(channel.rssW))) return []
      return [{ time: sample.time, ideal: toMicrowatts(channel.powerW), measured: noisy ? toMicrowatts(channel.rssW) : toMicrowatts(channel.powerW) }]
    }),
  }))
  let minimum = 0
  let maximum = 0
  for (const { points } of series) {
    for (const point of points) {
      minimum = Math.min(minimum, point.ideal, point.measured)
      maximum = Math.max(maximum, point.ideal, point.measured)
    }
  }
  const span = maximum - minimum || 1
  const yMinimum = minimum < 0 ? minimum - span * 0.08 : 0
  const yMaximum = maximum + span * 0.12
  const endTime = latest && Number.isFinite(latest.time) ? Math.max(20, latest.time) : 20
  const startTime = endTime - 20
  const plotWidth = CHART.width - CHART.left - CHART.right
  const plotHeight = CHART.height - CHART.top - CHART.bottom
  const x = (time: number) => CHART.left + (time - startTime) / (endTime - startTime) * plotWidth
  const y = (value: number) => CHART.top + (yMaximum - value) / (yMaximum - yMinimum) * plotHeight
  const ticks = [0, 0.25, 0.5, 0.75, 1]
  const hasPoints = series.some(({ points }) => points.length > 0)

  return (
    <aside id="rss-chart" className="rss-panel" role="complementary" aria-label="RSS chart" data-model={MODEL_ID} data-sample-count={samples.length} data-time={latest?.time ?? 0} onKeyDown={(event) => { if (event.key === 'Escape') { event.stopPropagation(); onClose() } }}>
      <div className="rss-heading">
        <div><h2>Received optical power</h2><p>{noisy ? 'LOS + AWGN' : 'LOS'}<span aria-hidden="true"> · </span>{paused ? 'Paused' : 'Live'}<span aria-hidden="true"> · </span>20 s window</p></div>
        <button className="icon-button rss-close" aria-label="Close RSS chart" title="Close RSS chart" onClick={onClose}><X size={17} /></button>
      </div>
      <div className="rss-actions">
        <button aria-label={paused ? 'Resume RSS trace' : 'Pause RSS trace'} onClick={() => setPaused(!paused)}>{paused ? <Play size={12} /> : <Pause size={12} />}{paused ? 'Resume' : 'Pause'}</button>
        <button aria-label="Clear RSS trace" onClick={clear}><RotateCcw size={12} />Clear</button>
        <button aria-label="Optical settings" onClick={onSettings}><SlidersHorizontal size={12} />Optical settings</button>
      </div>
      <div className="rss-body">
        {error && <p className="rss-message rss-error" role="alert">RSS unavailable: {error}</p>}
        <figure className="rss-chart-figure">
          <svg className="rss-chart-svg" viewBox={`0 0 ${CHART.width} ${CHART.height}`} role="img" aria-label="Received optical power over time">
            <text x={CHART.left} y="10" className="rss-axis-label">µW</text>
            {ticks.map((fraction) => {
              const value = yMinimum + fraction * (yMaximum - yMinimum)
              return <g key={`y-${fraction}`}><line className="rss-gridline" x1={CHART.left} x2={CHART.width - CHART.right} y1={y(value)} y2={y(value)} /><text className="rss-tick" x={CHART.left - 7} y={y(value) + 3} textAnchor="end">{formatTick(value)}</text></g>
            })}
            <line className="rss-zero-line" x1={CHART.left} x2={CHART.width - CHART.right} y1={y(0)} y2={y(0)} />
            {ticks.map((fraction) => {
              const time = startTime + fraction * (endTime - startTime)
              return <g key={`x-${fraction}`}><line className="rss-axis-mark" x1={x(time)} x2={x(time)} y1={CHART.top + plotHeight} y2={CHART.top + plotHeight + 4} /><text className="rss-tick" x={x(time)} y={CHART.height - 19} textAnchor="middle">{time.toFixed(1)}</text></g>
            })}
            <text x={CHART.left + plotWidth / 2} y={CHART.height - 4} textAnchor="middle" className="rss-axis-label">Time (s)</text>
            {series.map(({ id, points }) => (
              <g key={id} style={channelStyle(id)}>
                {(noisy ? ['ideal', 'measured'] as const : ['ideal'] as const).map((kind) => {
                  const subtle = noisy && kind === 'ideal'
                  const path = points.map((point, index) => `${index === 0 ? 'M' : 'L'}${x(point.time).toFixed(2)} ${y(point[kind]).toFixed(2)}`).join(' ')
                  return <g key={kind} className={subtle ? 'rss-trace rss-trace-ideal' : 'rss-trace'}>
                    {points.length > 1 && <path d={path} />}
                    {points.length === 1 && <circle cx={x(points[0].time)} cy={y(points[0][kind])} r={2.5} />}
                  </g>
                })}
              </g>
            ))}
            {!hasPoints && <text x={CHART.left + plotWidth / 2} y={CHART.top + plotHeight / 2} textAnchor="middle" className="rss-empty-label">{error ? 'Trace unavailable' : paused ? 'Trace cleared · resume to sample' : scene.emitters.length ? 'Warming up…' : 'No LED channels'}</text>}
          </svg>
          <figcaption className="rss-trace-key">{noisy ? <><span><i aria-hidden="true" />Measured RSS</span><span><i className="rss-key-ideal" aria-hidden="true" />Ideal LOS</span><span>Signed estimates are not clipped.</span></> : <span><i aria-hidden="true" />Ideal LOS received power</span>}</figcaption>
        </figure>
        <ul className="rss-channels" aria-label="Current received power by LED">
          {scene.emitters.map(({ id }) => {
            const channel = latest?.channels.find((entry) => entry.id === id)
            return <li key={id} className="rss-channel" style={channelStyle(id)}>
              <div className="rss-channel-name"><span className="rss-swatch" aria-hidden="true" /><strong>{id}</strong>{channel && channel.status !== 'los' && <span className="rss-channel-status">{STATUS_LABELS[channel.status]}</span>}</div>
              <div className="rss-channel-values">
                {channel ? <>
                  {noisy && <output aria-live="off" aria-label={`${id} measured RSS`} data-rss-w={channel.rssW}>{formatPower(channel.rssW)}</output>}
                  <output className={noisy ? 'rss-ideal-value' : undefined} aria-live="off" aria-label={`${id} ideal received power`} data-ideal-power-w={channel.powerW}>{noisy && <span>Ideal </span>}{formatPower(channel.powerW)}</output>
                </> : <span className="rss-waiting">Waiting for sample</span>}
              </div>
            </li>
          })}
        </ul>
        <p className="rss-footnote">20 Hz display rate, not a carrier waveform. Ideal LED channel separation. Direct LOS only; reflections and occlusion are not modelled.</p>
      </div>
    </aside>
  )
}
