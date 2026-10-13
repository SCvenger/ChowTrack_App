-- ════════════════════════════════════════════════════════════════
-- MÓDULO SALUD / CARNET VETERINARIO (lado del dueño)
-- Copia de referencia de las migraciones YA APLICADAS en Supabase:
--   20261013200745  health_module_vet_records
--   20261013201700  health_module_index_medications_visit
-- No volver a ejecutar en el proyecto ChowTrack-Backend.
-- ════════════════════════════════════════════════════════════════

-- ── Enums ───────────────────────────────────────────────────────
CREATE TYPE public.pet_sex            AS ENUM ('male', 'female', 'unknown');
CREATE TYPE public.vaccine_type       AS ENUM ('rabies', 'polyvalent', 'leptospirosis', 'bordetella', 'other');
CREATE TYPE public.deworming_type     AS ENUM ('internal', 'external', 'both');
CREATE TYPE public.appointment_status AS ENUM ('scheduled', 'completed', 'cancelled');
CREATE TYPE public.health_doc_type    AS ENUM ('vaccine_certificate', 'lab_result', 'xray', 'prescription', 'other');

-- ── 1. Perfil de salud (1:1 con pets) ───────────────────────────
CREATE TABLE public.pet_health_profiles (
    pet_id              uuid PRIMARY KEY REFERENCES public.pets(id) ON DELETE CASCADE,
    sex                 public.pet_sex NOT NULL DEFAULT 'unknown',
    birth_date          date CHECK (birth_date IS NULL OR birth_date <= CURRENT_DATE),
    color               text CHECK (char_length(color) <= 50),
    is_sterilized       boolean NOT NULL DEFAULT false,
    microchip_id        text CHECK (char_length(microchip_id) <= 30),
    blood_type          text CHECK (char_length(blood_type) <= 20),
    allergies           text[] NOT NULL DEFAULT '{}',
    chronic_conditions  text[] NOT NULL DEFAULT '{}',
    diet_notes          text CHECK (char_length(diet_notes) <= 500),
    vet_name            text CHECK (char_length(vet_name) <= 80),
    vet_clinic          text CHECK (char_length(vet_clinic) <= 100),
    vet_phone           text CHECK (vet_phone IS NULL OR vet_phone ~ '^\+?\d[\d\s-]{6,19}$'),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.pet_health_profiles IS 'Ficha clínica base de la mascota (1 fila por mascota)';

-- ── 2. Cartilla de vacunación ───────────────────────────────────
CREATE TABLE public.pet_vaccinations (
    id            uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id        uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    vaccine_name  text NOT NULL CHECK (char_length(vaccine_name) BETWEEN 2 AND 80),
    vaccine_type  public.vaccine_type NOT NULL DEFAULT 'other',
    dose_number   smallint CHECK (dose_number IS NULL OR dose_number BETWEEN 1 AND 20),
    applied_at    date NOT NULL,
    next_due_at   date,
    batch_number  text CHECK (char_length(batch_number) <= 50),
    vet_name      text CHECK (char_length(vet_name) <= 80),
    clinic_name   text CHECK (char_length(clinic_name) <= 100),
    notes         text CHECK (char_length(notes) <= 500),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pet_vaccinations_due_after_applied CHECK (next_due_at IS NULL OR next_due_at >= applied_at)
);
COMMENT ON TABLE public.pet_vaccinations IS 'Cartilla de vacunación digital';
CREATE INDEX idx_pet_vaccinations_pet ON public.pet_vaccinations (pet_id, applied_at DESC);

-- ── 3. Desparasitaciones ────────────────────────────────────────
CREATE TABLE public.pet_dewormings (
    id              uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id          uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    product_name    text NOT NULL CHECK (char_length(product_name) BETWEEN 2 AND 80),
    deworming_type  public.deworming_type NOT NULL DEFAULT 'internal',
    applied_at      date NOT NULL,
    next_due_at     date,
    weight_kg       numeric(5,2) CHECK (weight_kg IS NULL OR (weight_kg > 0 AND weight_kg <= 150)),
    notes           text CHECK (char_length(notes) <= 500),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pet_dewormings_due_after_applied CHECK (next_due_at IS NULL OR next_due_at >= applied_at)
);
COMMENT ON TABLE public.pet_dewormings IS 'Historial de desparasitaciones internas/externas';
CREATE INDEX idx_pet_dewormings_pet ON public.pet_dewormings (pet_id, applied_at DESC);

-- ── 4. Historial clínico (consultas) ────────────────────────────
CREATE TABLE public.pet_vet_visits (
    id             uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id         uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    visit_date     date NOT NULL,
    reason         text NOT NULL CHECK (char_length(reason) BETWEEN 2 AND 200),
    diagnosis      text CHECK (char_length(diagnosis) <= 1000),
    treatment      text CHECK (char_length(treatment) <= 1000),
    vet_name       text CHECK (char_length(vet_name) <= 80),
    clinic_name    text CHECK (char_length(clinic_name) <= 100),
    weight_kg      numeric(5,2) CHECK (weight_kg IS NULL OR (weight_kg > 0 AND weight_kg <= 150)),
    temperature_c  numeric(4,1) CHECK (temperature_c IS NULL OR temperature_c BETWEEN 30 AND 45),
    cost_bob       numeric(10,2) CHECK (cost_bob IS NULL OR cost_bob >= 0),
    notes          text CHECK (char_length(notes) <= 500),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.pet_vet_visits IS 'Consultas veterinarias registradas por el dueño';
CREATE INDEX idx_pet_vet_visits_pet ON public.pet_vet_visits (pet_id, visit_date DESC);

-- ── 5. Medicamentos / tratamientos ──────────────────────────────
CREATE TABLE public.pet_medications (
    id             uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id         uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    visit_id       uuid REFERENCES public.pet_vet_visits(id) ON DELETE SET NULL,
    name           text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 80),
    dosage         text CHECK (char_length(dosage) <= 80),
    frequency      text CHECK (char_length(frequency) <= 80),
    start_date     date NOT NULL,
    end_date       date,
    prescribed_by  text CHECK (char_length(prescribed_by) <= 80),
    notes          text CHECK (char_length(notes) <= 500),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pet_medications_end_after_start CHECK (end_date IS NULL OR end_date >= start_date)
);
COMMENT ON TABLE public.pet_medications IS 'Medicamentos y tratamientos (activos si end_date es NULL o futura)';
CREATE INDEX idx_pet_medications_pet ON public.pet_medications (pet_id, start_date DESC);

-- ── 6. Control de peso ──────────────────────────────────────────
CREATE TABLE public.pet_weight_logs (
    id           uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id       uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    weight_kg    numeric(5,2) NOT NULL CHECK (weight_kg > 0 AND weight_kg <= 150),
    measured_at  date NOT NULL,
    notes        text CHECK (char_length(notes) <= 200),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.pet_weight_logs IS 'Registro histórico de peso';
CREATE INDEX idx_pet_weight_logs_pet ON public.pet_weight_logs (pet_id, measured_at DESC);

-- ── 7. Citas veterinarias ───────────────────────────────────────
CREATE TABLE public.pet_vet_appointments (
    id            uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id        uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    scheduled_at  timestamptz NOT NULL,
    reason        text NOT NULL CHECK (char_length(reason) BETWEEN 2 AND 200),
    vet_name      text CHECK (char_length(vet_name) <= 80),
    clinic_name   text CHECK (char_length(clinic_name) <= 100),
    address       text CHECK (char_length(address) <= 200),
    status        public.appointment_status NOT NULL DEFAULT 'scheduled',
    notes         text CHECK (char_length(notes) <= 500),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.pet_vet_appointments IS 'Agenda de citas veterinarias del dueño';
CREATE INDEX idx_pet_vet_appointments_pet ON public.pet_vet_appointments (pet_id, scheduled_at);

-- ── 8. Documentos clínicos (archivo en Storage: pet-health) ────
CREATE TABLE public.pet_health_documents (
    id          uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id      uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    title       text NOT NULL CHECK (char_length(title) BETWEEN 2 AND 100),
    doc_type    public.health_doc_type NOT NULL DEFAULT 'other',
    file_path   text NOT NULL UNIQUE,
    mime_type   text NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'application/pdf')),
    size_bytes  integer NOT NULL CHECK (size_bytes > 0),
    issued_at   date,
    notes       text CHECK (char_length(notes) <= 500),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.pet_health_documents IS 'Metadatos de documentos clínicos; el archivo vive en el bucket privado pet-health';
CREATE INDEX idx_pet_health_documents_pet ON public.pet_health_documents (pet_id, created_at DESC);

-- ── 9. Enlaces para compartir el carnet con un veterinario ─────
CREATE TABLE public.pet_health_shares (
    id                uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    pet_id            uuid NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    token             text NOT NULL UNIQUE CHECK (char_length(token) >= 24),
    expires_at        timestamptz NOT NULL,
    revoked_at        timestamptz,
    last_accessed_at  timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.pet_health_shares IS 'Tokens temporales de solo lectura del carnet (QR para el veterinario)';
CREATE INDEX idx_pet_health_shares_pet ON public.pet_health_shares (pet_id, created_at DESC);

-- ── Triggers updated_at (función existente) ─────────────────────
CREATE TRIGGER trg_pet_health_profiles_updated_at  BEFORE UPDATE ON public.pet_health_profiles  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_vaccinations_updated_at     BEFORE UPDATE ON public.pet_vaccinations     FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_dewormings_updated_at       BEFORE UPDATE ON public.pet_dewormings       FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_vet_visits_updated_at       BEFORE UPDATE ON public.pet_vet_visits       FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_medications_updated_at      BEFORE UPDATE ON public.pet_medications      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_weight_logs_updated_at      BEFORE UPDATE ON public.pet_weight_logs      FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_vet_appointments_updated_at BEFORE UPDATE ON public.pet_vet_appointments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER trg_pet_health_documents_updated_at BEFORE UPDATE ON public.pet_health_documents FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── RLS: solo el dueño de la mascota (mismo patrón que nose_embeddings) ──
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'pet_health_profiles', 'pet_vaccinations', 'pet_dewormings', 'pet_vet_visits',
        'pet_medications', 'pet_weight_logs', 'pet_vet_appointments', 'pet_health_documents'
    ]
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format(
            'CREATE POLICY "%s: acceso del dueño" ON public.%I FOR ALL TO authenticated '
            'USING (EXISTS (SELECT 1 FROM public.pets WHERE pets.id = %I.pet_id AND pets.owner_id = (SELECT auth.uid()))) '
            'WITH CHECK (EXISTS (SELECT 1 FROM public.pets WHERE pets.id = %I.pet_id AND pets.owner_id = (SELECT auth.uid())))',
            t, t, t, t
        );
    END LOOP;
END $$;

-- Shares: el dueño solo lee; los tokens los crea/revoca el backend (service_role)
ALTER TABLE public.pet_health_shares ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pet_health_shares: lectura del dueño" ON public.pet_health_shares
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.pets WHERE pets.id = pet_health_shares.pet_id AND pets.owner_id = (SELECT auth.uid())));
CREATE POLICY "pet_health_shares: solo service_role inserta" ON public.pet_health_shares
    FOR INSERT TO authenticated WITH CHECK (false);

-- ── Bucket privado para documentos clínicos ─────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('pet-health', 'pet-health', false, 5242880, ARRAY['image/jpeg', 'image/png', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- ── Migración 2: índice del FK visit_id (advisor de rendimiento) ─
CREATE INDEX idx_pet_medications_visit ON public.pet_medications (visit_id) WHERE visit_id IS NOT NULL;
