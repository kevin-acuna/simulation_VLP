import { useId, useState } from 'react'
import { Minus, Plus } from 'lucide-react'
import type { CSSProperties, ReactNode } from 'react'

interface RangeFieldProps {
  label: string
  value: number
  min: number
  max: number
  step: number
  unit?: string
  digits?: number
  onChange: (value: number) => void
}

function NumberEditor({ value, min, max, step, label, digits = 1, onChange }: Omit<RangeFieldProps, 'unit'>) {
  const [draft, setDraft] = useState<string | null>(null)
  function commit() {
    const parsed = Number(draft)
    if (draft !== null && draft.trim() !== '' && Number.isFinite(parsed)) {
      onChange(Number(Math.min(max, Math.max(min, Math.round(parsed / step) * step)).toFixed(8)))
    }
    setDraft(null)
  }
  return (
    <input
      className="number-input"
      aria-label={`${label} value`}
      type="number"
      min={min}
      max={max}
      step={step}
      value={draft ?? value.toFixed(digits)}
      onChange={(event) => setDraft(event.target.value)}
      onBlur={commit}
      onKeyDown={(event) => {
        if (event.key === 'Enter') event.currentTarget.blur()
        if (event.key === 'Escape') setDraft(null)
      }}
    />
  )
}

export function RangeField(props: RangeFieldProps) {
  const id = useId()
  const fill = `${((props.value - props.min) / (props.max - props.min)) * 100}%`
  return (
    <div className="range-field">
      <div className="field-heading">
        <label htmlFor={id}>{props.label}</label>
        <div className="value-field"><NumberEditor {...props} /><span>{props.unit}</span></div>
      </div>
      <input
        id={id}
        type="range"
        aria-label={props.label}
        min={props.min}
        max={props.max}
        step={props.step}
        value={props.value}
        style={{ '--range-fill': fill } as CSSProperties}
        onChange={(event) => props.onChange(Number(event.target.value))}
      />
    </div>
  )
}

export function Toggle({ label, description, checked, onChange, disabled = false }: {
  label: string
  description: string
  checked: boolean
  onChange: (checked: boolean) => void
  disabled?: boolean
}) {
  return (
    <label className={`toggle-row${disabled ? ' disabled' : ''}`}>
      <span><strong>{label}</strong><small>{description}</small></span>
      <input type="checkbox" role="switch" checked={checked} disabled={disabled} onChange={(event) => onChange(event.target.checked)} />
      <span className="switch-track" aria-hidden="true"><span /></span>
    </label>
  )
}

export function Choice<T extends string>({ label, value, options, onChange }: {
  label: string
  value: T
  options: { value: T; label: string; icon: ReactNode }[]
  onChange: (value: T) => void
}) {
  return (
    <div className="choice-field">
      <span className="field-label">{label}</span>
      <div className="choices" role="group" aria-label={label}>
        {options.map((option) => (
          <button key={option.value} className={value === option.value ? 'choice active' : 'choice'} aria-pressed={value === option.value} onClick={() => onChange(option.value)}>
            {option.icon}<span>{option.label}</span>
          </button>
        ))}
      </div>
    </div>
  )
}

export function Stepper({ value, onChange }: { value: number; onChange: (value: number) => void }) {
  return (
    <div className="stepper-row">
      <span><strong>LED count</strong><small>Ceiling-mounted emitters</small></span>
      <div className="stepper">
        <button aria-label="Remove one LED" disabled={value <= 1} onClick={() => onChange(value - 1)}><Minus size={14} /></button>
        <output aria-label="LED count">{String(value).padStart(2, '0')}</output>
        <button aria-label="Add one LED" disabled={value >= 9} onClick={() => onChange(value + 1)}><Plus size={14} /></button>
      </div>
    </div>
  )
}
