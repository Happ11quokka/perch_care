-- =====================================================
-- RLS 정책 성능 최적화
-- 실행 순서: 5번째 (기존 RLS 정책 적용 후)
--
-- 변경 사항: auth.uid() -> (select auth.uid())
-- 이유: auth.uid()가 각 행마다 재평가되지 않고 쿼리당 한 번만 평가되어 성능 향상
-- 참고: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select
-- =====================================================

-- =====================================================
-- 1. PROFILES 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;

CREATE POLICY "profiles_select"
  ON public.profiles FOR SELECT
  USING ((select auth.uid()) = id);

CREATE POLICY "profiles_update"
  ON public.profiles FOR UPDATE
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);

CREATE POLICY "profiles_insert"
  ON public.profiles FOR INSERT
  WITH CHECK ((select auth.uid()) = id);

-- =====================================================
-- 2. PETS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can insert own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can update own pets" ON public.pets;
DROP POLICY IF EXISTS "Users can delete own pets" ON public.pets;
DROP POLICY IF EXISTS "pets_select" ON public.pets;
DROP POLICY IF EXISTS "pets_insert" ON public.pets;
DROP POLICY IF EXISTS "pets_update" ON public.pets;
DROP POLICY IF EXISTS "pets_delete" ON public.pets;

CREATE POLICY "pets_select"
  ON public.pets FOR SELECT
  USING ((select auth.uid()) = user_id);

CREATE POLICY "pets_insert"
  ON public.pets FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "pets_update"
  ON public.pets FOR UPDATE
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "pets_delete"
  ON public.pets FOR DELETE
  USING ((select auth.uid()) = user_id);

-- =====================================================
-- 3. WEIGHT_RECORDS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "Users can insert own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "Users can update own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "Users can delete own pet weight records" ON public.weight_records;
DROP POLICY IF EXISTS "weight_records_select" ON public.weight_records;
DROP POLICY IF EXISTS "weight_records_insert" ON public.weight_records;
DROP POLICY IF EXISTS "weight_records_update" ON public.weight_records;
DROP POLICY IF EXISTS "weight_records_delete" ON public.weight_records;

CREATE POLICY "weight_records_select"
  ON public.weight_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "weight_records_insert"
  ON public.weight_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "weight_records_update"
  ON public.weight_records FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "weight_records_delete"
  ON public.weight_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = weight_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 4. DAILY_RECORDS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "Users can insert own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "Users can update own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "Users can delete own pet daily records" ON public.daily_records;
DROP POLICY IF EXISTS "daily_records_select" ON public.daily_records;
DROP POLICY IF EXISTS "daily_records_insert" ON public.daily_records;
DROP POLICY IF EXISTS "daily_records_update" ON public.daily_records;
DROP POLICY IF EXISTS "daily_records_delete" ON public.daily_records;

CREATE POLICY "daily_records_select"
  ON public.daily_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "daily_records_insert"
  ON public.daily_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "daily_records_update"
  ON public.daily_records FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "daily_records_delete"
  ON public.daily_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = daily_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 5. AI_HEALTH_CHECKS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet health checks" ON public.ai_health_checks;
DROP POLICY IF EXISTS "Users can insert own pet health checks" ON public.ai_health_checks;
DROP POLICY IF EXISTS "Users can delete own pet health checks" ON public.ai_health_checks;
DROP POLICY IF EXISTS "ai_health_checks_select" ON public.ai_health_checks;
DROP POLICY IF EXISTS "ai_health_checks_insert" ON public.ai_health_checks;
DROP POLICY IF EXISTS "ai_health_checks_delete" ON public.ai_health_checks;

CREATE POLICY "ai_health_checks_select"
  ON public.ai_health_checks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = ai_health_checks.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "ai_health_checks_insert"
  ON public.ai_health_checks FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = ai_health_checks.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "ai_health_checks_delete"
  ON public.ai_health_checks FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = ai_health_checks.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 6. FOOD_RECORDS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "Users can insert own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "Users can update own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "Users can delete own pet food records" ON public.food_records;
DROP POLICY IF EXISTS "food_records_select" ON public.food_records;
DROP POLICY IF EXISTS "food_records_insert" ON public.food_records;
DROP POLICY IF EXISTS "food_records_update" ON public.food_records;
DROP POLICY IF EXISTS "food_records_delete" ON public.food_records;

CREATE POLICY "food_records_select"
  ON public.food_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "food_records_insert"
  ON public.food_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "food_records_update"
  ON public.food_records FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "food_records_delete"
  ON public.food_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = food_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 7. WATER_RECORDS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet water records" ON public.water_records;
DROP POLICY IF EXISTS "Users can insert own pet water records" ON public.water_records;
DROP POLICY IF EXISTS "Users can delete own pet water records" ON public.water_records;
DROP POLICY IF EXISTS "water_records_select" ON public.water_records;
DROP POLICY IF EXISTS "water_records_insert" ON public.water_records;
DROP POLICY IF EXISTS "water_records_delete" ON public.water_records;

CREATE POLICY "water_records_select"
  ON public.water_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = water_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "water_records_insert"
  ON public.water_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = water_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "water_records_delete"
  ON public.water_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = water_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 8. SCHEDULES 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "Users can insert own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "Users can update own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "Users can delete own pet schedules" ON public.schedules;
DROP POLICY IF EXISTS "schedules_select" ON public.schedules;
DROP POLICY IF EXISTS "schedules_insert" ON public.schedules;
DROP POLICY IF EXISTS "schedules_update" ON public.schedules;
DROP POLICY IF EXISTS "schedules_delete" ON public.schedules;

CREATE POLICY "schedules_select"
  ON public.schedules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "schedules_insert"
  ON public.schedules FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "schedules_update"
  ON public.schedules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "schedules_delete"
  ON public.schedules FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = schedules.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 9. NOTIFICATIONS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;

CREATE POLICY "notifications_select"
  ON public.notifications FOR SELECT
  USING ((select auth.uid()) = user_id);

CREATE POLICY "notifications_update"
  ON public.notifications FOR UPDATE
  USING ((select auth.uid()) = user_id);

CREATE POLICY "notifications_delete"
  ON public.notifications FOR DELETE
  USING ((select auth.uid()) = user_id);

-- =====================================================
-- 10. WCI_RECORDS 정책 최적화
-- =====================================================
DROP POLICY IF EXISTS "Users can view own pet wci records" ON public.wci_records;
DROP POLICY IF EXISTS "Users can insert own pet wci records" ON public.wci_records;
DROP POLICY IF EXISTS "Users can delete own pet wci records" ON public.wci_records;
DROP POLICY IF EXISTS "wci_records_select" ON public.wci_records;
DROP POLICY IF EXISTS "wci_records_insert" ON public.wci_records;
DROP POLICY IF EXISTS "wci_records_delete" ON public.wci_records;

CREATE POLICY "wci_records_select"
  ON public.wci_records FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = wci_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "wci_records_insert"
  ON public.wci_records FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = wci_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

CREATE POLICY "wci_records_delete"
  ON public.wci_records FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.pets
      WHERE pets.id = wci_records.pet_id
      AND pets.user_id = (select auth.uid())
    )
  );

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ RLS 정책 성능 최적화가 완료되었습니다!';
  RAISE NOTICE '변경 사항: auth.uid() -> (select auth.uid())';
  RAISE NOTICE '효과: 쿼리당 한 번만 평가되어 대규모 데이터에서 성능 향상';
END $$;
