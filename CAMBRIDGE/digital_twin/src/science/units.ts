function finite(value: number, name: string, nonnegative = false): number {
  if (!Number.isFinite(value) || (nonnegative && value < 0)) {
    throw new RangeError(`${name} must be finite${nonnegative ? ' and nonnegative' : ''}`)
  }
  return value
}

export function toMicrowatts(watts: number): number {
  return finite(finite(watts, 'Optical power') * 1e6, 'Optical power in microwatts')
}

export function toSquareMillimeters(squareMeters: number): number {
  return finite(finite(squareMeters, 'Active area', true) * 1e6, 'Active area in square millimetres')
}

export function fromSquareMillimeters(squareMillimeters: number): number {
  return finite(squareMillimeters, 'Active area', true) / 1e6
}

export function toNoiseSigmaNanowatts(varianceW2: number): number {
  return finite(Math.sqrt(finite(varianceW2, 'Noise variance', true)) * 1e9, 'Noise sigma in nanowatts')
}

export function fromNoiseSigmaNanowatts(sigmaNw: number): number {
  return finite((finite(sigmaNw, 'Noise sigma', true) / 1e9) ** 2, 'Noise variance in square watts')
}
