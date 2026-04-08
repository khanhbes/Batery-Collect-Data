double speedMpsToKmh(double speedMps) {
  return speedMps * 3.6;
}

double accelerationMs2({
  required double previousSpeedMps,
  required double currentSpeedMps,
  required double deltaSec,
}) {
  if (deltaSec <= 0) {
    return 0;
  }
  return (currentSpeedMps - previousSpeedMps) / deltaSec;
}
