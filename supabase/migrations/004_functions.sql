-- =====================================================
-- Perch Care Database Functions
-- 실행 순서: 4번째 (모든 설정 후)
-- Supabase SQL Editor에서 실행하세요
-- =====================================================

-- =====================================================
-- 1. 월별 체중 평균 조회 함수
-- =====================================================
CREATE OR REPLACE FUNCTION get_monthly_weight_averages(
  p_pet_id UUID,
  p_year INT DEFAULT NULL
)
RETURNS TABLE (
  year INT,
  month INT,
  avg_weight DECIMAL(10, 2),
  min_weight DECIMAL(10, 2),
  max_weight DECIMAL(10, 2),
  record_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    EXTRACT(YEAR FROM wr.recorded_date)::INT AS year,
    EXTRACT(MONTH FROM wr.recorded_date)::INT AS month,
    ROUND(AVG(wr.weight), 2)::DECIMAL(10, 2) AS avg_weight,
    MIN(wr.weight)::DECIMAL(10, 2) AS min_weight,
    MAX(wr.weight)::DECIMAL(10, 2) AS max_weight,
    COUNT(*)::INT AS record_count
  FROM public.weight_records wr
  INNER JOIN public.pets p ON p.id = wr.pet_id
  WHERE wr.pet_id = p_pet_id
    AND p.user_id = auth.uid()
    AND (p_year IS NULL OR EXTRACT(YEAR FROM wr.recorded_date) = p_year)
  GROUP BY
    EXTRACT(YEAR FROM wr.recorded_date),
    EXTRACT(MONTH FROM wr.recorded_date)
  ORDER BY year DESC, month DESC;
END;
$$;

-- =====================================================
-- 2. 주간 체중 데이터 조회 함수
-- =====================================================
CREATE OR REPLACE FUNCTION get_weekly_weight_data(
  p_pet_id UUID,
  p_year INT,
  p_month INT,
  p_week INT -- 1~5 (해당 월의 몇 번째 주)
)
RETURNS TABLE (
  recorded_date DATE,
  weight DECIMAL(10, 2),
  day_of_week INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_first_day DATE;
BEGIN
  -- 해당 월의 첫 날
  v_first_day := make_date(p_year, p_month, 1);

  -- 주의 시작일 계산 (월요일 기준)
  v_start_date := v_first_day + ((p_week - 1) * 7) * INTERVAL '1 day';
  v_end_date := v_start_date + INTERVAL '6 days';

  -- 월을 넘어가지 않도록 제한
  IF v_end_date > (v_first_day + INTERVAL '1 month' - INTERVAL '1 day') THEN
    v_end_date := v_first_day + INTERVAL '1 month' - INTERVAL '1 day';
  END IF;

  RETURN QUERY
  SELECT
    wr.recorded_date,
    wr.weight,
    EXTRACT(DOW FROM wr.recorded_date)::INT AS day_of_week
  FROM public.weight_records wr
  INNER JOIN public.pets p ON p.id = wr.pet_id
  WHERE wr.pet_id = p_pet_id
    AND p.user_id = auth.uid()
    AND wr.recorded_date >= v_start_date
    AND wr.recorded_date <= v_end_date
  ORDER BY wr.recorded_date;
END;
$$;

-- =====================================================
-- 3. 특정 기간 체중 변화율 계산 함수
-- =====================================================
CREATE OR REPLACE FUNCTION get_weight_change_rate(
  p_pet_id UUID,
  p_days INT DEFAULT 30
)
RETURNS TABLE (
  start_weight DECIMAL(10, 2),
  end_weight DECIMAL(10, 2),
  change_amount DECIMAL(10, 2),
  change_rate DECIMAL(5, 2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_weight DECIMAL(10, 2);
  v_end_weight DECIMAL(10, 2);
BEGIN
  -- 시작 체중 (기간 시작일에 가장 가까운 기록)
  SELECT wr.weight INTO v_start_weight
  FROM public.weight_records wr
  INNER JOIN public.pets p ON p.id = wr.pet_id
  WHERE wr.pet_id = p_pet_id
    AND p.user_id = auth.uid()
    AND wr.recorded_date >= CURRENT_DATE - p_days
  ORDER BY wr.recorded_date ASC
  LIMIT 1;

  -- 종료 체중 (가장 최근 기록)
  SELECT wr.weight INTO v_end_weight
  FROM public.weight_records wr
  INNER JOIN public.pets p ON p.id = wr.pet_id
  WHERE wr.pet_id = p_pet_id
    AND p.user_id = auth.uid()
  ORDER BY wr.recorded_date DESC
  LIMIT 1;

  IF v_start_weight IS NULL OR v_end_weight IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    v_start_weight,
    v_end_weight,
    (v_end_weight - v_start_weight)::DECIMAL(10, 2),
    ROUND(((v_end_weight - v_start_weight) / v_start_weight * 100), 2)::DECIMAL(5, 2);
END;
$$;

-- =====================================================
-- 4. 일일 기록 요약 조회 함수 (캘린더용)
-- =====================================================
CREATE OR REPLACE FUNCTION get_daily_summary(
  p_pet_id UUID,
  p_year INT,
  p_month INT
)
RETURNS TABLE (
  recorded_date DATE,
  has_weight BOOLEAN,
  has_food BOOLEAN,
  has_water BOOLEAN,
  has_health_check BOOLEAN,
  mood VARCHAR(20)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH date_range AS (
    SELECT generate_series(
      make_date(p_year, p_month, 1),
      make_date(p_year, p_month, 1) + INTERVAL '1 month' - INTERVAL '1 day',
      INTERVAL '1 day'
    )::DATE AS d
  )
  SELECT
    dr.d AS recorded_date,
    EXISTS(SELECT 1 FROM public.weight_records wr WHERE wr.pet_id = p_pet_id AND wr.recorded_date = dr.d) AS has_weight,
    EXISTS(SELECT 1 FROM public.food_records fr WHERE fr.pet_id = p_pet_id AND fr.recorded_date = dr.d) AS has_food,
    EXISTS(SELECT 1 FROM public.water_records wtr WHERE wtr.pet_id = p_pet_id AND wtr.recorded_date = dr.d) AS has_water,
    EXISTS(SELECT 1 FROM public.ai_health_checks ahc WHERE ahc.pet_id = p_pet_id AND ahc.checked_at::DATE = dr.d) AS has_health_check,
    (SELECT drc.mood FROM public.daily_records drc WHERE drc.pet_id = p_pet_id AND drc.recorded_date = dr.d LIMIT 1) AS mood
  FROM date_range dr
  INNER JOIN public.pets p ON p.id = p_pet_id AND p.user_id = auth.uid()
  ORDER BY dr.d;
END;
$$;

-- =====================================================
-- 5. 펫 건강 통계 조회 함수
-- =====================================================
CREATE OR REPLACE FUNCTION get_pet_health_stats(
  p_pet_id UUID
)
RETURNS TABLE (
  total_weight_records INT,
  total_food_records INT,
  total_water_records INT,
  total_health_checks INT,
  last_weight DECIMAL(10, 2),
  last_weight_date DATE,
  avg_weight_30days DECIMAL(10, 2),
  abnormal_health_checks INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::INT FROM public.weight_records WHERE pet_id = p_pet_id),
    (SELECT COUNT(*)::INT FROM public.food_records WHERE pet_id = p_pet_id),
    (SELECT COUNT(*)::INT FROM public.water_records WHERE pet_id = p_pet_id),
    (SELECT COUNT(*)::INT FROM public.ai_health_checks WHERE pet_id = p_pet_id),
    (SELECT wr.weight FROM public.weight_records wr WHERE wr.pet_id = p_pet_id ORDER BY wr.recorded_date DESC LIMIT 1),
    (SELECT wr.recorded_date FROM public.weight_records wr WHERE wr.pet_id = p_pet_id ORDER BY wr.recorded_date DESC LIMIT 1),
    (SELECT ROUND(AVG(wr.weight), 2)::DECIMAL(10, 2) FROM public.weight_records wr WHERE wr.pet_id = p_pet_id AND wr.recorded_date >= CURRENT_DATE - 30),
    (SELECT COUNT(*)::INT FROM public.ai_health_checks WHERE pet_id = p_pet_id AND status != 'normal')
  FROM public.pets p
  WHERE p.id = p_pet_id AND p.user_id = auth.uid();
END;
$$;

-- =====================================================
-- 6. 읽지 않은 알림 개수 조회 함수
-- =====================================================
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INT
    FROM public.notifications
    WHERE user_id = auth.uid() AND is_read = FALSE
  );
END;
$$;

-- =====================================================
-- 7. 오늘 일정 조회 함수
-- =====================================================
CREATE OR REPLACE FUNCTION get_today_schedules(
  p_pet_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  pet_id UUID,
  pet_name VARCHAR(100),
  title VARCHAR(200),
  description TEXT,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  color VARCHAR(10)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.pet_id,
    p.name AS pet_name,
    s.title,
    s.description,
    s.start_time,
    s.end_time,
    s.color
  FROM public.schedules s
  INNER JOIN public.pets p ON p.id = s.pet_id
  WHERE p.user_id = auth.uid()
    AND DATE(s.start_time) = CURRENT_DATE
    AND (p_pet_id IS NULL OR s.pet_id = p_pet_id)
  ORDER BY s.start_time;
END;
$$;

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ 모든 데이터베이스 함수가 성공적으로 생성되었습니다!';
END $$;
