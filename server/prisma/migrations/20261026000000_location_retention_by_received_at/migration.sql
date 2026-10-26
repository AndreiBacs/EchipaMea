-- Location retention is measured on the server-assigned receivedAt, not the
-- device-reported capturedAt: a phone with a wrong clock must neither lose
-- fresh samples to the nightly prune nor keep them past the retention window.
DROP INDEX "worker_location_samples_capturedAt_idx";

CREATE INDEX "worker_location_samples_receivedAt_idx" ON "worker_location_samples"("receivedAt");
