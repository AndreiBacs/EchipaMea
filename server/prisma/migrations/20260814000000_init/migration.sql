-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "ProjectStatus" AS ENUM ('planned', 'inProgress', 'done');

-- CreateEnum
CREATE TYPE "PhaseStatus" AS ENUM ('notStarted', 'inProgress', 'pendingReview', 'done');

-- CreateEnum
CREATE TYPE "ClientType" AS ENUM ('individual', 'company', 'publicInstitution');

-- CreateEnum
CREATE TYPE "ClientStatus" AS ENUM ('active', 'inactive', 'blocked');

-- CreateEnum
CREATE TYPE "ClientContactMethod" AS ENUM ('phone', 'email', 'whatsApp');

-- CreateEnum
CREATE TYPE "WorkerRole" AS ENUM ('electrician', 'plumber', 'generalWorker', 'carpenter', 'welder', 'helper', 'painter', 'mason', 'hvacTechnician');

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('admin', 'foreman');

-- CreateEnum
CREATE TYPE "MediaKind" AS ENUM ('photo', 'audio', 'video', 'document');

-- CreateEnum
CREATE TYPE "MediaSlot" AS ENUM ('instructionPhoto', 'instructionAudio', 'reportPhoto', 'reportVoiceMemo');

-- CreateEnum
CREATE TYPE "NotificationKind" AS ENUM ('workerReportSubmitted', 'phaseApproved', 'phaseRejected', 'workerArrived');

-- CreateEnum
CREATE TYPE "ReportSource" AS ENUM ('http', 'websocket');

-- CreateTable
CREATE TABLE "companies" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "addressLine1" TEXT NOT NULL DEFAULT '',
    "city" TEXT NOT NULL DEFAULT '',
    "state" TEXT NOT NULL DEFAULT '',
    "zipCode" TEXT NOT NULL DEFAULT '',
    "iban" TEXT NOT NULL DEFAULT '',
    "cui" TEXT NOT NULL DEFAULT '',
    "vatNumber" TEXT NOT NULL DEFAULT '',
    "regCom" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "companies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'foreman',
    "fullName" TEXT NOT NULL DEFAULT '',
    "phone" TEXT NOT NULL DEFAULT '',
    "jobTitle" TEXT NOT NULL DEFAULT '',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastLoginAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "userId" TEXT,
    "employeeId" TEXT,
    "tokenHash" TEXT NOT NULL,
    "familyId" TEXT NOT NULL,
    "issuedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "revokedAt" TIMESTAMPTZ(6),
    "replacedById" TEXT,
    "userAgent" TEXT,
    "ip" TEXT,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_login_tickets" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "issuedByUserId" TEXT NOT NULL,
    "ticketHash" TEXT NOT NULL,
    "issuedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "redeemedAt" TIMESTAMPTZ(6),
    "redeemedIp" TEXT,
    "redeemedUserAgent" TEXT,

    CONSTRAINT "worker_login_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "realtime_tickets" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "ticketHash" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "userId" TEXT,
    "employeeId" TEXT,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "usedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "realtime_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "clients" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "ClientType" NOT NULL,
    "status" "ClientStatus" NOT NULL,
    "preferredContactMethod" "ClientContactMethod" NOT NULL,
    "notes" TEXT NOT NULL DEFAULT '',
    "email" TEXT NOT NULL DEFAULT '',
    "phone" TEXT NOT NULL DEFAULT '',
    "addressLine1" TEXT NOT NULL DEFAULT '',
    "city" TEXT NOT NULL DEFAULT '',
    "state" TEXT NOT NULL DEFAULT '',
    "zipCode" TEXT NOT NULL DEFAULT '',
    "contactPerson" TEXT NOT NULL DEFAULT '',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),

    CONSTRAINT "clients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employees" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" "WorkerRole" NOT NULL,
    "email" TEXT NOT NULL DEFAULT '',
    "phone" TEXT NOT NULL DEFAULT '',
    "workStartHour" INTEGER NOT NULL,
    "workEndHour" INTEGER NOT NULL,
    "workingDays" INTEGER[],
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),

    CONSTRAINT "employees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "projects" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "useClientAddress" BOOLEAN NOT NULL DEFAULT true,
    "addressLine1" TEXT NOT NULL DEFAULT '',
    "city" TEXT NOT NULL DEFAULT '',
    "state" TEXT NOT NULL DEFAULT '',
    "zipCode" TEXT NOT NULL DEFAULT '',
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "closedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),

    CONSTRAINT "projects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "project_assignments" (
    "projectId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "project_assignments_pkey" PRIMARY KEY ("projectId","employeeId")
);

-- CreateTable
CREATE TABLE "project_phases" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startDate" DATE NOT NULL,
    "endDate" DATE NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "status" "PhaseStatus" NOT NULL DEFAULT 'notStarted',
    "sortIndex" INTEGER NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,
    "deletedAt" TIMESTAMPTZ(6),

    CONSTRAINT "project_phases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "phase_assignments" (
    "phaseId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "phase_assignments_pkey" PRIMARY KEY ("phaseId","employeeId")
);

-- CreateTable
CREATE TABLE "phase_work_instructions" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "phaseId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "sortIndex" INTEGER NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "phase_work_instructions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "phase_submissions" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "phaseId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "reportId" TEXT,
    "submittedAt" TIMESTAMPTZ(6) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "phase_submissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "phase_reviews" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "phaseId" TEXT NOT NULL,
    "approved" BOOLEAN NOT NULL,
    "reviewedById" TEXT NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "phase_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_sequence_overrides" (
    "companyId" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "orderedPhaseIds" TEXT[],
    "createdById" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "daily_sequence_overrides_pkey" PRIMARY KEY ("projectId","employeeId","day")
);

-- CreateTable
CREATE TABLE "media_assets" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "bucket" TEXT NOT NULL,
    "kind" "MediaKind" NOT NULL,
    "contentType" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "originalName" TEXT NOT NULL DEFAULT '',
    "width" INTEGER,
    "height" INTEGER,
    "durationMs" INTEGER,
    "uploadedByUserId" TEXT,
    "uploadedByEmployeeId" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "work_instruction_media" (
    "instructionId" TEXT NOT NULL,
    "mediaId" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "slot" "MediaSlot" NOT NULL,
    "sortIndex" INTEGER NOT NULL,

    CONSTRAINT "work_instruction_media_pkey" PRIMARY KEY ("instructionId","mediaId")
);

-- CreateTable
CREATE TABLE "worker_report_media" (
    "reportId" TEXT NOT NULL,
    "mediaId" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "slot" "MediaSlot" NOT NULL,
    "sortIndex" INTEGER NOT NULL,
    "clientName" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "worker_report_media_pkey" PRIMARY KEY ("reportId","mediaId")
);

-- CreateTable
CREATE TABLE "worker_reports" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "phaseId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "submittedAt" TIMESTAMPTZ(6) NOT NULL,
    "submittedAtRaw" TEXT NOT NULL,
    "projectNameSnapshot" TEXT NOT NULL DEFAULT '',
    "phaseNameSnapshot" TEXT NOT NULL DEFAULT '',
    "employeeNameSnapshot" TEXT NOT NULL DEFAULT '',
    "idempotencyKey" TEXT NOT NULL,
    "source" "ReportSource" NOT NULL DEFAULT 'http',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "worker_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_arrivals" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "projectId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "arrivedAt" TIMESTAMPTZ(6) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "worker_arrivals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "recipientUserId" TEXT NOT NULL,
    "kind" "NotificationKind" NOT NULL,
    "payload" JSONB NOT NULL,
    "projectId" TEXT,
    "phaseId" TEXT,
    "employeeId" TEXT,
    "reportId" TEXT,
    "occurredAt" TIMESTAMPTZ(6) NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "readAt" TIMESTAMPTZ(6),

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "worker_location_samples" (
    "id" BIGSERIAL NOT NULL,
    "companyId" TEXT NOT NULL,
    "employeeId" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracyMeters" DOUBLE PRECISION NOT NULL,
    "capturedAt" TIMESTAMPTZ(6) NOT NULL,
    "receivedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "employeeNameSnapshot" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "worker_location_samples_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "users_companyId_deletedAt_idx" ON "users"("companyId", "deletedAt");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_id_companyId_key" ON "users"("id", "companyId");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_tokenHash_key" ON "refresh_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "refresh_tokens_companyId_familyId_idx" ON "refresh_tokens"("companyId", "familyId");

-- CreateIndex
CREATE INDEX "refresh_tokens_expiresAt_idx" ON "refresh_tokens"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "worker_login_tickets_ticketHash_key" ON "worker_login_tickets"("ticketHash");

-- CreateIndex
CREATE INDEX "worker_login_tickets_companyId_employeeId_expiresAt_idx" ON "worker_login_tickets"("companyId", "employeeId", "expiresAt");

-- CreateIndex
CREATE INDEX "worker_login_tickets_expiresAt_idx" ON "worker_login_tickets"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "realtime_tickets_ticketHash_key" ON "realtime_tickets"("ticketHash");

-- CreateIndex
CREATE INDEX "realtime_tickets_expiresAt_idx" ON "realtime_tickets"("expiresAt");

-- CreateIndex
CREATE INDEX "clients_companyId_deletedAt_name_idx" ON "clients"("companyId", "deletedAt", "name");

-- CreateIndex
CREATE UNIQUE INDEX "clients_id_companyId_key" ON "clients"("id", "companyId");

-- CreateIndex
CREATE INDEX "employees_companyId_deletedAt_name_idx" ON "employees"("companyId", "deletedAt", "name");

-- CreateIndex
CREATE UNIQUE INDEX "employees_id_companyId_key" ON "employees"("id", "companyId");

-- CreateIndex
CREATE INDEX "projects_companyId_deletedAt_idx" ON "projects"("companyId", "deletedAt");

-- CreateIndex
CREATE INDEX "projects_companyId_clientId_idx" ON "projects"("companyId", "clientId");

-- CreateIndex
CREATE UNIQUE INDEX "projects_id_companyId_key" ON "projects"("id", "companyId");

-- CreateIndex
CREATE INDEX "project_assignments_companyId_employeeId_idx" ON "project_assignments"("companyId", "employeeId");

-- CreateIndex
CREATE INDEX "project_phases_projectId_sortIndex_idx" ON "project_phases"("projectId", "sortIndex");

-- CreateIndex
CREATE INDEX "project_phases_companyId_status_idx" ON "project_phases"("companyId", "status");

-- CreateIndex
CREATE INDEX "project_phases_companyId_startDate_endDate_idx" ON "project_phases"("companyId", "startDate", "endDate");

-- CreateIndex
CREATE UNIQUE INDEX "project_phases_id_companyId_key" ON "project_phases"("id", "companyId");

-- CreateIndex
CREATE INDEX "phase_assignments_companyId_employeeId_idx" ON "phase_assignments"("companyId", "employeeId");

-- CreateIndex
CREATE INDEX "phase_assignments_projectId_employeeId_idx" ON "phase_assignments"("projectId", "employeeId");

-- CreateIndex
CREATE INDEX "phase_work_instructions_phaseId_sortIndex_idx" ON "phase_work_instructions"("phaseId", "sortIndex");

-- CreateIndex
CREATE UNIQUE INDEX "phase_work_instructions_id_companyId_key" ON "phase_work_instructions"("id", "companyId");

-- CreateIndex
CREATE UNIQUE INDEX "phase_submissions_reportId_key" ON "phase_submissions"("reportId");

-- CreateIndex
CREATE INDEX "phase_submissions_phaseId_submittedAt_idx" ON "phase_submissions"("phaseId", "submittedAt");

-- CreateIndex
CREATE INDEX "phase_submissions_companyId_employeeId_submittedAt_idx" ON "phase_submissions"("companyId", "employeeId", "submittedAt");

-- CreateIndex
CREATE INDEX "phase_reviews_phaseId_createdAt_idx" ON "phase_reviews"("phaseId", "createdAt");

-- CreateIndex
CREATE INDEX "daily_sequence_overrides_companyId_day_idx" ON "daily_sequence_overrides"("companyId", "day");

-- CreateIndex
CREATE UNIQUE INDEX "media_assets_storageKey_key" ON "media_assets"("storageKey");

-- CreateIndex
CREATE INDEX "media_assets_companyId_sha256_idx" ON "media_assets"("companyId", "sha256");

-- CreateIndex
CREATE UNIQUE INDEX "media_assets_id_companyId_key" ON "media_assets"("id", "companyId");

-- CreateIndex
CREATE INDEX "work_instruction_media_instructionId_slot_sortIndex_idx" ON "work_instruction_media"("instructionId", "slot", "sortIndex");

-- CreateIndex
CREATE INDEX "worker_report_media_reportId_slot_sortIndex_idx" ON "worker_report_media"("reportId", "slot", "sortIndex");

-- CreateIndex
CREATE UNIQUE INDEX "worker_reports_idempotencyKey_key" ON "worker_reports"("idempotencyKey");

-- CreateIndex
CREATE INDEX "worker_reports_companyId_phaseId_submittedAt_idx" ON "worker_reports"("companyId", "phaseId", "submittedAt");

-- CreateIndex
CREATE INDEX "worker_reports_companyId_employeeId_submittedAt_idx" ON "worker_reports"("companyId", "employeeId", "submittedAt");

-- CreateIndex
CREATE INDEX "worker_arrivals_companyId_projectId_arrivedAt_idx" ON "worker_arrivals"("companyId", "projectId", "arrivedAt");

-- CreateIndex
CREATE INDEX "notifications_recipientUserId_readAt_createdAt_idx" ON "notifications"("recipientUserId", "readAt", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "notifications_companyId_createdAt_idx" ON "notifications"("companyId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "worker_location_samples_companyId_employeeId_capturedAt_idx" ON "worker_location_samples"("companyId", "employeeId", "capturedAt" DESC);

-- CreateIndex
CREATE INDEX "worker_location_samples_capturedAt_idx" ON "worker_location_samples"("capturedAt");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_login_tickets" ADD CONSTRAINT "worker_login_tickets_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_login_tickets" ADD CONSTRAINT "worker_login_tickets_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_login_tickets" ADD CONSTRAINT "worker_login_tickets_issuedByUserId_fkey" FOREIGN KEY ("issuedByUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "realtime_tickets" ADD CONSTRAINT "realtime_tickets_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "realtime_tickets" ADD CONSTRAINT "realtime_tickets_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "clients" ADD CONSTRAINT "clients_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employees" ADD CONSTRAINT "employees_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "projects" ADD CONSTRAINT "projects_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "projects" ADD CONSTRAINT "projects_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "project_assignments" ADD CONSTRAINT "project_assignments_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "project_assignments" ADD CONSTRAINT "project_assignments_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "project_phases" ADD CONSTRAINT "project_phases_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_assignments" ADD CONSTRAINT "phase_assignments_phaseId_fkey" FOREIGN KEY ("phaseId") REFERENCES "project_phases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_assignments" ADD CONSTRAINT "phase_assignments_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_work_instructions" ADD CONSTRAINT "phase_work_instructions_phaseId_fkey" FOREIGN KEY ("phaseId") REFERENCES "project_phases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_submissions" ADD CONSTRAINT "phase_submissions_phaseId_fkey" FOREIGN KEY ("phaseId") REFERENCES "project_phases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_submissions" ADD CONSTRAINT "phase_submissions_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_submissions" ADD CONSTRAINT "phase_submissions_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "worker_reports"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_reviews" ADD CONSTRAINT "phase_reviews_phaseId_fkey" FOREIGN KEY ("phaseId") REFERENCES "project_phases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "phase_reviews" ADD CONSTRAINT "phase_reviews_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_sequence_overrides" ADD CONSTRAINT "daily_sequence_overrides_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_sequence_overrides" ADD CONSTRAINT "daily_sequence_overrides_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_sequence_overrides" ADD CONSTRAINT "daily_sequence_overrides_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_uploadedByUserId_fkey" FOREIGN KEY ("uploadedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_uploadedByEmployeeId_fkey" FOREIGN KEY ("uploadedByEmployeeId") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_instruction_media" ADD CONSTRAINT "work_instruction_media_instructionId_fkey" FOREIGN KEY ("instructionId") REFERENCES "phase_work_instructions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "work_instruction_media" ADD CONSTRAINT "work_instruction_media_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "media_assets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_report_media" ADD CONSTRAINT "worker_report_media_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "worker_reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_report_media" ADD CONSTRAINT "worker_report_media_mediaId_fkey" FOREIGN KEY ("mediaId") REFERENCES "media_assets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_reports" ADD CONSTRAINT "worker_reports_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_reports" ADD CONSTRAINT "worker_reports_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_reports" ADD CONSTRAINT "worker_reports_phaseId_fkey" FOREIGN KEY ("phaseId") REFERENCES "project_phases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_reports" ADD CONSTRAINT "worker_reports_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_arrivals" ADD CONSTRAINT "worker_arrivals_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_arrivals" ADD CONSTRAINT "worker_arrivals_projectId_fkey" FOREIGN KEY ("projectId") REFERENCES "projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_arrivals" ADD CONSTRAINT "worker_arrivals_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipientUserId_fkey" FOREIGN KEY ("recipientUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_location_samples" ADD CONSTRAINT "worker_location_samples_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "worker_location_samples" ADD CONSTRAINT "worker_location_samples_employeeId_fkey" FOREIGN KEY ("employeeId") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

