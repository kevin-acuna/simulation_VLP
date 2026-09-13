from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class OpticalConfig:
    wavelength: float = 950e-9
    waist: float = 5e-6
    index: float = 1.55
    power: float = .010
    pitch: float = .002
    array_lens_distance: float = .005
    diameter: float = .016
    edge_thickness: float = .002
    radii: tuple = (.015,)
    tiles: int = 1
    tile_spacing: float = .020
    tilt_deg: float = 21.
    array_height: float = 3.
    pd_area: float = 1e-6
    fov_deg: float = 70.
    transmission: float = .90


@dataclass(frozen=True)
class ReceiverNoise:
    bandwidth: float = 100.
    responsivity: float = .7
    temperature: float = 300.
    feedback_resistance: float = 10000.
    amplifier_current_density: float = 2e-12
    background_current: float = 10e-6
    rin: float = 10**(-155/10)
    repeatability: float = .005

    def sigma(self, power):
        power = np.maximum(np.asarray(power), 0.)
        current = self.responsivity * power
        psd = (4*1.380649e-23*self.temperature/self.feedback_resistance
               + self.amplifier_current_density**2
               + 2*1.602176634e-19*(current+self.background_current)
               + self.rin*current**2)
        return np.sqrt(psd*self.bandwidth/self.responsivity**2 + (self.repeatability*power)**2)


def rotation_x(angle):
    c, s = np.cos(angle), np.sin(angle)
    return np.array([[1., 0., 0.], [0., c, -s], [0., s, c]])


def rotation_y(angle):
    c, s = np.cos(angle), np.sin(angle)
    return np.array([[c, 0., s], [0., 1., 0.], [-s, 0., c]])


class OpticalModel:
    def __init__(self, config=OpticalConfig()):
        self.config = config
        c = config
        if c.tiles not in (1, 9) or not c.radii:
            raise ValueError('Choose one or nine tiles and at least one lens state.')
        if min(c.waist, c.wavelength, c.pitch, c.diameter, c.edge_thickness, c.pd_area, c.array_lens_distance) <= 0 or c.index <= 1:
            raise ValueError('Optical dimensions must be positive and index greater than one.')
        if not 0 < c.fov_deg <= 90 or not 0 < c.transmission <= 1 or c.power <= 0:
            raise ValueError('Invalid receiver, power or transmission.')
        x, y = np.meshgrid(np.arange(-2, 3)*c.pitch, np.arange(2, -3, -1)*c.pitch)
        self.local_xy = np.column_stack((x.ravel(), y.ravel()))
        x, y = self.local_xy.T
        rho2 = x*x + y*y
        aperture = c.diameter/2
        if np.max(rho2) >= aperture**2:
            raise ValueError('VCSEL chief rays fall outside the common lens aperture.')
        zr = np.pi*c.waist**2/c.wavelength
        q_in = c.array_lens_distance + 1j*zr
        self.local_directions, self.local_q, self.thicknesses = [], [], []
        self.center_thicknesses, self.clipping_bounds = [], []
        reference_dc = c.array_lens_distance + c.edge_thickness + .015 - np.sqrt(.015**2-aperture**2)
        alpha = np.deg2rad(c.tilt_deg)*np.array([-1, -1, -1, 0, 0, 0, 1, 1, 1])
        beta = np.deg2rad(c.tilt_deg)*np.array([-1, 0, 1, 1, 0, -1, -1, 0, 1])
        offsets = c.tile_spacing*np.array([[1, 1], [0, 1], [-1, 1], [1, 0], [0, 0], [-1, 0], [1, -1], [0, -1], [-1, -1]])
        tile_ids = [4] if c.tiles == 1 else range(9)
        origins, directions, q_values, state_ids, all_tile_ids = [], [], [], [], []
        for k, radius in enumerate(c.radii):
            magnitude, sign = abs(radius), np.sign(radius)
            if magnitude <= aperture or radius**2 <= c.index**2*np.max(rho2):
                raise ValueError('Impossible spherical cap or total internal reflection of a chief ray.')
            center_thickness = c.edge_thickness + sign*(magnitude-np.sqrt(radius**2-aperture**2))
            thickness = center_thickness + sign*(np.sqrt(radius**2-rho2)-magnitude)
            if center_thickness <= 0 or np.min(thickness) <= 0:
                raise ValueError('The chosen edge thickness gives a non-positive lens center thickness.')
            root = np.sqrt(radius**2-rho2)
            factor = (np.sqrt(radius**2-c.index**2*rho2)-c.index*root)/(magnitude*radius)
            local_v = np.column_stack((factor*x, factor*y, c.index+factor*sign*root))
            b = thickness/c.index
            cc = (1-c.index)/radius
            d = 1+b*cc
            transformed = (q_in+b)/(cc*q_in+d)
            width_exit = np.sqrt(c.wavelength/np.pi*np.abs(transformed)**2/transformed.imag)
            clipping_bound = np.exp(-2*(aperture-np.sqrt(rho2))**2/width_exit**2)
            if np.max(clipping_bound) > .01:
                raise ValueError('Finite-aperture clipping is not negligible for this pitch/lens.')
            self.local_directions.append(local_v)
            self.local_q.append(transformed)
            self.thicknesses.append(thickness)
            self.center_thicknesses.append(center_thickness)
            self.clipping_bounds.append(clipping_bound)
            local_exit = np.column_stack((x, y, c.array_lens_distance+thickness))
            for tile in tile_ids:
                rotation = rotation_y(np.pi+beta[tile]) @ rotation_x(alpha[tile])
                array_origin = (rotation @ np.array([0., 0., reference_dc])
                                + np.array([-offsets[tile, 0], offsets[tile, 1], c.array_height+reference_dc]))
                origins.append(local_exit @ rotation.T + array_origin)
                directions.append(local_v @ rotation.T)
                q_values.append(transformed)
                state_ids.extend([k]*25)
                all_tile_ids.extend([tile]*25)
        self.origins = np.concatenate(origins)
        self.directions = np.concatenate(directions)
        self.q = np.concatenate(q_values)
        self.state_ids = np.array(state_ids)
        self.tile_ids = np.array(all_tile_ids)
        self.n_channels = len(self.q)

    def width_squared(self, distance):
        s = np.asarray(distance)[..., None]
        return self.config.wavelength/np.pi*((s+self.q.real)**2+self.q.imag**2)/self.q.imag

    def power_and_jacobian(self, position, normal=(0., 0., 1.), jacobian=True):
        p = np.asarray(position, dtype=float)
        normal = np.asarray(normal, dtype=float)
        if p.shape[-1] != 3 or normal.shape != (3,) or not np.isclose(np.linalg.norm(normal), 1):
            raise ValueError('Position must end in three coordinates and normal must be a unit 3-vector.')
        displacement = p[..., None, :] - self.origins
        axial = np.einsum('...ij,ij->...i', displacement, self.directions)
        transverse = displacement - axial[..., None]*self.directions
        rho2 = np.sum(transverse**2, axis=-1)
        a = axial+self.q.real
        width2 = self.config.wavelength/np.pi*(a*a+self.q.imag**2)/self.q.imag
        cosine = -self.directions @ normal
        visible = (cosine >= np.cos(np.deg2rad(self.config.fov_deg))) & (axial > 0)
        coefficient = 2*self.config.power*self.config.transmission*self.config.pd_area/np.pi
        power = coefficient*np.maximum(cosine, 0)/width2*np.exp(-2*rho2/width2)*visible
        if not jacobian:
            return power
        dwidth = (2*self.config.wavelength/np.pi*a/self.q.imag)[..., None]*self.directions
        gradient = power[..., None]*((2*rho2/width2**2-1/width2)[..., None]*dwidth-4*transverse/width2[..., None])
        return power, gradient

    def power_at(self, position, normal=(0., 0., 1.)):
        return self.power_and_jacobian(position, normal, jacobian=False)

    def footprint_centers(self, height=0.):
        distance = (height-self.origins[:, 2])/self.directions[:, 2]
        return self.origins + distance[:, None]*self.directions

    def diagnostics(self):
        return {
            'focal_mm': [1000*r/(self.config.index-1) for r in self.config.radii],
            'optical_power_diopters': [(self.config.index-1)/r for r in self.config.radii],
            'center_thickness_mm': (1000*np.array(self.center_thicknesses)).tolist(),
            'max_clipping_upper_bound': float(np.max(self.clipping_bounds)),
            'max_chief_ray_tilt_deg': float(np.rad2deg(np.arccos(self.directions @ np.array([0., 0., -1.]))).max()),
            'min_virtual_waist_distance_mm': float(1000*self.q.real.min()),
            'min_output_rayleigh_range_mm': float(1000*self.q.imag.min()),
            'center_beam_radius_at_3m_mm': [float(1000*np.sqrt(self.config.wavelength/np.pi*((3+q[12].real)**2+q[12].imag**2)/q[12].imag)) for q in self.local_q],
        }
