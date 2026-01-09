-- =====================================================
-- Perch Care RLS (Row Level Security) Policies
-- 실행 순서: 2번째 (테이블 생성 후)
-- Supabase SQL Editor에서 실행하세요
-- =====================================================

-- =====================================================
-- RLS 활성화
-- =====================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_health_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wci_records ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 1. PROFILES 정책
-- =====================================================
-- 기존 정책 삭제
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

-- 자신의 프로필만 조회
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- 자신의 프로필만 수정
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 자신의 프로필 생성 (트리거로 자동 생성되지만 백업용)
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- =====================================================
-- 2. PETS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can insert own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can update own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can delete own pets" ON public.pets;

-- 자신의 펫만 조회
CREATE POLICY "Users can view own pets"
  ON public.pets FOR SELECT
  USING (auth.uid() = user_id);

-- 자신의 펫 생성
CREATE POLICY "Users can insert own pets"
  ON public.pets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 자신의 펫 수정
CREATE POLICY "Users can update own pets"
  ON public.pets FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 자신의 펫 삭제
CREATE POLICY "Users can delete own pets"
  ON public.pets FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================
-- 3. WEIGHT_RECORDS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "Users can insert own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "Users can update own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "Users can delete own pet weight records" ON public.weight_records;

-- 자신의 펫 체중 기록 조회
CREATE POLICY "Users can view own pet weight records"
  ON public.weight_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- 자신의 펫 체중 기록 생성
CREATE POLICY "Users can insert own pet weight records"
  ON public.weight_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- 자신의 펫 체중 기록 수정
CREATE POLICY "Users can update own pet weight records"
  ON public.weight_records FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- 자신의 펫 체중 기록 삭제
CREATE POLICY "Users can delete own pet weight records"
  ON public.weight_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 4. DAILY_RECORDS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "Users can insert own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "Users can update own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "Users can delete own pet daily records" ON public.daily_records;

CREATE POLICY "Users can view own pet daily records"
  ON public.daily_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own pet daily records"
  ON public.daily_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own pet daily records"
  ON public.daily_records FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own pet daily records"
  ON public.daily_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 5. AI_HEALTH_CHECKS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet health checks" ON public.ai_health_checks;
DROP POLICY IF EXISTS "Users can insert own pet health checks" ON public.ai_health_checks;
DROP POLICY IF EXISTS "Users can delete own pet health checks" ON public.ai_health_checks;

CREATE POLICY "Users can view own pet health checks"
  ON public.ai_health_checks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = ai_health_checks.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own pet health checks"
  ON public.ai_health_checks FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = ai_health_checks.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own pet health checks"
  ON public.ai_health_checks FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = ai_health_checks.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 6. FOOD_RECORDS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "Users can insert own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "Users can update own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "Users can delete own pet food records" ON public.food_records;

CREATE POLICY "Users can view own pet food records"
  ON public.food_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own pet food records"
  ON public.food_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own pet food records"
  ON public.food_records FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own pet food records"
  ON public.food_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 7. WATER_RECORDS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet water records" ON public.water_records;
DROP POLICY IF EXISTS "Users can insert own pet water records" ON public.water_records;
DROP POLICY IF EXISTS "Users can delete own pet water records" ON public.water_records;

CREATE POLICY "Users can view own pet water records"
  ON public.water_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = water_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own pet water records"
  ON public.water_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = water_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own pet water records"
  ON public.water_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = water_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 8. SCHEDULES 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "Users can insert own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "Users can update own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "Users can delete own pet schedules" ON public.schedules;

CREATE POLICY "Users can view own pet schedules"
  ON public.schedules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own pet schedules"
  ON public.schedules FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own pet schedules"
  ON public.schedules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own pet schedules"
  ON public.schedules FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 9. NOTIFICATIONS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================
-- 10. WCI_RECORDS 정책
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet wci records" ON public.wci_records;
DROP POLICY IF EXISTS "Users can insert own pet wci records" ON public.wci_records;
DROP POLICY IF EXISTS "Users can delete own pet wci records" ON public.wci_records;

CREATE POLICY "Users can view own pet wci records"
  ON public.wci_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = wci_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own pet wci records"
  ON public.wci_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = wci_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own pet wci records"
  ON public.wci_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = wci_records.pet_id
      AND pets.user_id = auth.uid()
    )
  );

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ 모든 RLS 정책이 성공적으로 적용되었습니다!';
END $$;
