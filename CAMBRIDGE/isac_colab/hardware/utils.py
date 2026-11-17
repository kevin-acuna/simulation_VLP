"""Shared helpers."""

import math
import time


def wrap180(angle_deg):
    return (angle_deg + 180.0) % 360.0 - 180.0


def move_time_estimate(distance, vel, acc):
    """Duration of a trapezoidal velocity profile (triangular if vel is never reached)."""
    distance = abs(distance)
    if distance >= vel ** 2 / acc:
        return distance / vel + vel / acc
    return 2.0 * math.sqrt(distance / acc)


class RateTimer:
    """Fixed-rate timer without accumulated drift."""

    def __init__(self, rate_hz):
        self.period = 1.0 / rate_hz
        self.next = time.perf_counter()

    def wait(self):
        self.next += self.period
        delay = self.next - time.perf_counter()
        if delay > 0:
            time.sleep(delay)
        else:
            self.next = time.perf_counter()
