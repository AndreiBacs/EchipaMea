-- Constraints and search indexes that the Prisma schema language cannot express.
--
-- Prisma has no CHECK-constraint syntax, so the invariants below live here.
-- They are enforced in application code too; this is the layer that survives a
-- bug in that code, a manual UPDATE, or a future service writing to the same DB.

-- --------------------------------------------------------------------------
-- Employees: working-hours schedule that gates telemetry.
-- --------------------------------------------------------------------------
ALTER TABLE "employees"
  ADD CONSTRAINT "employees_workStartHour_range"
  CHECK ("workStartHour" >= 0 AND "workStartHour" <= 23);

ALTER TABLE "employees"
  ADD CONSTRAINT "employees_workEndHour_range"
  CHECK ("workEndHour" >= 0 AND "workEndHour" <= 23);

-- ISO-8601 weekdays only (1=Mon .. 7=Sun), matching Dart's DateTime.weekday.
ALTER TABLE "employees"
  ADD CONSTRAINT "employees_workingDays_valid"
  CHECK ("workingDays" <@ ARRAY[1,2,3,4,5,6,7]);

-- --------------------------------------------------------------------------
-- Phases: a date window must not run backwards.
-- --------------------------------------------------------------------------
ALTER TABLE "project_phases"
  ADD CONSTRAINT "project_phases_date_window"
  CHECK ("endDate" >= "startDate");

ALTER TABLE "project_phases"
  ADD CONSTRAINT "project_phases_sortIndex_nonnegative"
  CHECK ("sortIndex" >= 0);

ALTER TABLE "phase_work_instructions"
  ADD CONSTRAINT "phase_work_instructions_sortIndex_nonnegative"
  CHECK ("sortIndex" >= 0);

-- --------------------------------------------------------------------------
-- Telemetry: reject impossible coordinates at the storage layer.
-- --------------------------------------------------------------------------
ALTER TABLE "worker_location_samples"
  ADD CONSTRAINT "worker_location_samples_latitude_range"
  CHECK ("latitude" >= -90 AND "latitude" <= 90);

ALTER TABLE "worker_location_samples"
  ADD CONSTRAINT "worker_location_samples_longitude_range"
  CHECK ("longitude" >= -180 AND "longitude" <= 180);

ALTER TABLE "worker_location_samples"
  ADD CONSTRAINT "worker_location_samples_accuracy_nonnegative"
  CHECK ("accuracyMeters" >= 0);

-- Same bounds for the last-known position carried on the employee row.
ALTER TABLE "employees"
  ADD CONSTRAINT "employees_latitude_range"
  CHECK ("latitude" IS NULL OR ("latitude" >= -90 AND "latitude" <= 90));

ALTER TABLE "employees"
  ADD CONSTRAINT "employees_longitude_range"
  CHECK ("longitude" IS NULL OR ("longitude" >= -180 AND "longitude" <= 180));

ALTER TABLE "projects"
  ADD CONSTRAINT "projects_latitude_range"
  CHECK ("latitude" IS NULL OR ("latitude" >= -90 AND "latitude" <= 90));

ALTER TABLE "projects"
  ADD CONSTRAINT "projects_longitude_range"
  CHECK ("longitude" IS NULL OR ("longitude" >= -180 AND "longitude" <= 180));

-- --------------------------------------------------------------------------
-- Media: a zero-byte asset is always a bug.
-- --------------------------------------------------------------------------
ALTER TABLE "media_assets"
  ADD CONSTRAINT "media_assets_byteSize_positive"
  CHECK ("byteSize" > 0);

-- --------------------------------------------------------------------------
-- Case-insensitive name search behind the `?q=` filter on list endpoints.
-- Without trigram indexes an ILIKE '%term%' degrades to a sequential scan.
-- --------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX "clients_name_trgm_idx"   ON "clients"   USING GIN ("name" gin_trgm_ops);
CREATE INDEX "employees_name_trgm_idx" ON "employees" USING GIN ("name" gin_trgm_ops);
CREATE INDEX "projects_name_trgm_idx"  ON "projects"  USING GIN ("name" gin_trgm_ops);

-- Note on emails: `users.email` carries a plain unique index from the Prisma
-- schema, and the application lowercases before both insert and lookup. A
-- functional UNIQUE(LOWER(email)) index would be stricter, but Prisma cannot
-- represent one, so migrate would report permanent schema drift against it.
