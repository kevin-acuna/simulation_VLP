"""Offline numerical regression tests; no VISA or MATLAB required."""
import unittest
import numpy as np
from isac.modem import (modem_config, make_frame, modulate, demodulate, decode,
                       awg_frame, resample_matlab, round_matlab, rate_ratio)


def direct_polyphase_reference(x, up, down):
    # Independent direct FIR summation from the pre-port NumPy reference.
    import math
    divisor = math.gcd(up, down)
    up, down = up//divisor, down//divisor
    if up == down:
        return np.array(x, copy=True)
    half = 10*max(up, down)
    t = np.arange(-half, half+1, dtype=float)
    h = np.sinc(t/max(up, down))/max(up, down)*np.kaiser(2*half+1, 5.)
    h = up*h/h.sum()
    samples = np.arange((len(x)*up+down-1)//down, dtype=np.int64)
    base, phase = (samples*down)//up, (samples*down)%up
    out = np.zeros(len(samples))
    radius = int(np.ceil((half+up-1)/up))
    for j in range(-radius, radius+1):
        ix, ih = base+j, half+phase-j*up
        good = (ix >= 0) & (ix < len(x)) & (ih >= 0) & (ih < len(h))
        out[good] += x[ix[good]]*h[ih[good]]
    return out


class ModemTests(unittest.TestCase):
    def test_all_constellations_gray_bits_and_unit_energy(self):
        for order in (4, 16, 64, 256):
            with self.subTest(order=order):
                b = int(np.log2(order))
                words = ((np.arange(order)[:, None] >> np.arange(b-1, -1, -1)) & 1)
                bits = words.reshape(-1, 1)
                symbols = modulate(bits, order)
                self.assertEqual(len(np.unique(symbols)), order)
                self.assertAlmostEqual(float(np.mean(abs(symbols)**2)), 1., places=14)
                np.testing.assert_array_equal(demodulate(symbols, order), bits)
                # The all-zero word selects the positive outer corner.
                self.assertGreater(symbols[0, 0].real, 0)
                self.assertGreater(symbols[0, 0].imag, 0)
                # Neighbouring descending real-axis values differ by one Gray bit.
                row = symbols[:, 0][np.isclose(symbols[:, 0].imag, symbols[0, 0].imag)]
                row = np.sort(row.real)[::-1]+1j*symbols[0, 0].imag
                decoded = demodulate(row[:, None], order).reshape(-1, b)
                np.testing.assert_array_equal(np.count_nonzero(decoded[1:] != decoded[:-1], axis=1), np.ones(len(row)-1))

    def test_round_ties_match_matlab_and_no_byte_overflow(self):
        np.testing.assert_array_equal(round_matlab([-2.5, -1.5, -.5, .5, 1.5, 2.5]), [-3, -2, -1, 1, 2, 3])
        # For 16QAM, boundary at axis coordinate 0 rounds the index upward.
        z = np.array([[0.+0.j]])
        bits = demodulate(z, 16)
        self.assertLess(modulate(bits, 16)[0, 0].real, 0)

    def test_packet_reproducibility_and_expected_baseline(self):
        p = make_frame()
        other = make_frame()
        for name in ("baseFrame", "payloadBits", "trainingBits"):
            np.testing.assert_array_equal(p[name], other[name])
        self.assertEqual(p["frameLengthBase"], 10880)
        self.assertEqual(p["payloadBitCount"], 1584)
        self.assertAlmostEqual(p["frameDuration"], .00069632)
        self.assertAlmostEqual(p["payloadRateIncludingTraining"], 2274816.1764705884)
        self.assertAlmostEqual(max(abs(p["baseFrame"])), 1.)
        shaped = p["baseFrame"].reshape((1088, 10), order="F")
        np.testing.assert_array_equal(shaped[:64], shaped[-64:])
        # Independent axis formula for QPSK training, from known bit pairs.
        tb = p["trainingBits"]
        expected = ((1-2*tb[::2].astype(float)) + 1j*(1-2*tb[1::2].astype(float)))/np.sqrt(2)
        np.testing.assert_allclose(p["trainingSymbols"], expected, atol=1e-15)

    def test_resampler_against_independent_polyphase_sum(self):
        x = np.random.RandomState(11).normal(size=37)
        for up, down in ((25,32),(25,16),(25,8),(8,25),(1,10),(1024,1),(2,2)):
            with self.subTest(up=up, down=down):
                actual = resample_matlab(x, up, down)
                expected = direct_polyphase_reference(x, up, down)
                np.testing.assert_allclose(actual, expected, rtol=2e-14, atol=3e-15)
        self.assertEqual(rate_ratio(15.625e6,20e6),(25,32))
        self.assertEqual(rate_ratio(15.625e6,10e6),(25,16))
        self.assertEqual(rate_ratio(15.625e6,5e6),(25,8))

    def test_all_orders_offsets_gain_and_cp_channel(self):
        for order in (4,16,64,256):
            p=make_frame(modem_config(order)); n=p["frameLengthBase"]
            x=np.tile(p["baseFrame"],7)
            h=np.zeros(18); h[0]=1.;h[8]=.22;h[17]=-.10
            channel=np.convolve(x,h)[:len(x)]
            cases=[x[offset:offset+3*n] for offset in (0,17,n//2,n-9)]
            cases.extend([-.23*x[137:137+3*n]+2.7,channel[n+371:n+371+3*n]])
            for case, y in enumerate(cases):
                with self.subTest(order=order,case=case):
                    r=decode(p,y,p["FsBase"])
                    self.assertTrue(r["accepted"],r["reason"])
                    self.assertEqual(r["bitErrors"],0)
                    self.assertEqual(r["rejectedFrames"],0)
                    self.assertEqual(r["nBits"],r["nAttemptedBits"])
                    self.assertEqual(r["indexBase"],1)
                    self.assertGreaterEqual(r["frameStartBase"],65)

    def test_scope_rates_and_fractional_capture_offsets(self):
        p=make_frame(); n=p["frameLengthBase"]; x=np.tile(p["baseFrame"],8)
        for fs in (5e6,10e6,20e6):
            up,down=rate_ratio(fs,p["FsBase"])
            cap=resample_matlab(x,up,down)
            count=int(round(.003*fs))
            for offset in (91,781,3199):
                with self.subTest(fs=fs,offset=offset):
                    r=decode(p,cap[offset:offset+count],fs)
                    self.assertTrue(r["accepted"],r["reason"])
                    self.assertEqual(r["bitErrors"],0)
                    self.assertEqual(r["rejectedFrames"],0)

    def test_held_out_payload_errors_are_counted_not_rejected(self):
        for order in (4,16,64,256):
            with self.subTest(order=order):
                p=make_frame(modem_config(order)); n=p["frameLengthBase"]
                y=np.tile(p["baseFrame"],6)
                y[2*n+2176:3*n]*=-1
                r=decode(p,y,p["FsBase"])
                self.assertEqual(r["nFrames"],4)
                self.assertEqual(r["acceptedFrames"],4)
                self.assertEqual(r["rejectedFrames"],0)
                self.assertEqual(r["bitErrors"],528)
                self.assertGreater(r["BER"],1e-3)

    def test_missing_frame_is_rejected_and_attempted_bits_retained(self):
        p=make_frame(modem_config(16)); n=p["frameLengthBase"]
        y=np.tile(p["baseFrame"],6); y[2*n:3*n]=0
        r=decode(p,y,p["FsBase"])
        self.assertEqual((r["nFrames"],r["acceptedFrames"],r["rejectedFrames"]),(4,3,1))
        self.assertEqual(r["nAttemptedBits"],4*p["payloadBitCount"])
        self.assertEqual(r["nBits"],3*p["payloadBitCount"])

    def test_non_signals_short_and_low_sample_rate_rejected(self):
        p=make_frame(); fs=5e6;t=np.arange(15000)/fs
        for y,rate in ((np.zeros(15000),fs),(np.ones(15000)*.4,fs),
                       (.0125*np.sin(2*np.pi*500e3*t),fs),
                       (np.random.RandomState(110911).normal(size=15000),fs),
                       (p["baseFrame"][:-1],p["FsBase"]),
                       (np.tile(p["baseFrame"],3),1e6)):
            r=decode(p,y,rate)
            self.assertFalse(r["accepted"])
            self.assertTrue(r["reason"])

    def test_noise_and_ambient(self):
        p=make_frame(modem_config(16)); x=np.tile(p["baseFrame"],8)
        cap=resample_matlab(x,8,25)
        t=np.arange(15000)/5e6
        for phase in (0,np.pi/2,np.pi):
            y=.0125*cap[781:781+15000]+.081*np.sin(2*np.pi*100*t+phase)+.4
            r=decode(p,y,5e6)
            self.assertTrue(r["accepted"],r["reason"])
            self.assertEqual(r["bitErrors"],0)
        p=make_frame();rng=np.random.RandomState(555)
        y=np.tile(p["baseFrame"],6)+rng.normal(scale=.0001,size=6*p["frameLengthBase"])
        r=decode(p,y,p["FsBase"])
        self.assertEqual(r["bitErrors"],0)

    def test_awg_full_interpolated_frame_and_quantized_decode(self):
        p=make_frame(); codes=awg_frame(p)
        self.assertEqual(codes.dtype,np.int8)
        self.assertEqual(codes.size,11141120)
        self.assertLessEqual(int(np.max(np.abs(codes.astype(int)))),127)
        # Every 1024th DAC point has the original phase; periodic interpolation
        # alters only a global normalization plus tiny FIR ripple.
        base=codes[::1024].astype(float)/127
        r=decode(p,np.tile(base,6),p["FsBase"])
        self.assertEqual(r["rejectedFrames"],0)
        self.assertLessEqual(r["BER"],1e-3)
        # Compare the transmitted interpolation against an independent direct
        # FIR evaluator on a shorter periodically extended packet.
        short=dict(p);short["cfg"]=dict(p["cfg"],samplesPerSymbol=8,FsAWG=p["FsBase"]*8)
        short["baseFrame"]=p["baseFrame"][:73]
        actual=awg_frame(short)
        x=short["baseFrame"];pad=np.r_[x[np.arange(-64,0)%len(x)],x,x[np.arange(64)%len(x)]]
        expected=direct_polyphase_reference(pad,8,1)[64*8:(64+len(x))*8]
        expected=round_matlab(127*expected/max(abs(expected))).astype(np.int8)
        np.testing.assert_array_equal(actual,expected)

    def test_invalid_inputs_rejected(self):
        with self.assertRaises(ValueError):make_frame(modem_config(32))
        with self.assertRaises(ValueError):modulate(np.ones((3,2)),16)
        with self.assertRaises(ValueError):demodulate(np.array([[np.nan]]),64)
        with self.assertRaises(ValueError):decode(make_frame(),[0,np.nan],5e6)
        with self.assertRaises(ValueError):resample_matlab([1,2],0,1)
        with self.assertRaises(ValueError):make_frame(dict(modem_config(),activeBins=[0,1]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
