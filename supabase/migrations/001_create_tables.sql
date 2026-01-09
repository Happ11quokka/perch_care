-- =====================================================
-- Perch Care Database Schema
-- 실행 순서: 1번째
-- Supabase SQL Editor에서 실행하세요
-- =====================================================

-- =====================================================
-- 1. PROFILES 테이블 (사용자 프로필)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname VARCHAR(100),
  avatar_url TEXT,
  country VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 프로필 자동 생성 트리거 함수
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'nickname');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 (이미 존재하면 삭제 후 재생성)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- updated_at 자동 업데이트 함수
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- profiles updated_at 트리거
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- 2. PETS 테이블 (반려동물 정보)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.pets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  species VARCHAR(50) NOT NULL, -- 'parrot', 'dog', 'cat' 등
  breed VARCHAR(100), -- 품종
  birth_date DATE,
  gender VARCHAR(20), -- 'male', 'female', 'unknown'
  profile_image_url TEXT,
  is_active BOOLEAN DEFAULT TRUE, -- 현재 선택된 펫
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- pets updated_at 트리거
DROP TRIGGER IF EXISTS update_pets_updated_at ON public.pets;
CREATE TRIGGER update_pets_updated_at
  BEFORE UPDATE ON public.pets
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- pets 인덱스
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON public.pets(user_id);
CREATE INDEX IF NOT EXISTS idx_pets_is_active ON public.pets(user_id, is_active);

-- =====================================================
-- 3. WEIGHT_RECORDS 테이블 (체중 기록)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.weight_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  recorded_date DATE NOT NULL,
  weight DECIMAL(10, 2) NOT NULL, -- 그램 단위
  memo TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pet_id, recorded_date)
);

-- weight_records updated_at 트리거
DROP TRIGGER IF EXISTS update_weight_records_updated_at ON public.weight_records;
CREATE TRIGGER update_weight_records_updated_at
  BEFORE UPDATE ON public.weight_records
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- weight_records 인덱스
CREATE INDEX IF NOT EXISTS idx_weight_records_pet_id ON public.weight_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_weight_records_date ON public.weight_records(pet_id, recorded_date);

-- =====================================================
-- 4. DAILY_RECORDS 테이블 (일일 건강 기록)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.daily_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  recorded_date DATE NOT NULL,
  notes TEXT,
  mood VARCHAR(20), -- 'great', 'good', 'normal', 'bad', 'sick'
  activity_level INT CHECK (activity_level >= 1 AND activity_level <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pet_id, recorded_date)
);

-- daily_records updated_at 트리거
DROP TRIGGER IF EXISTS update_daily_records_updated_at ON public.daily_records;
CREATE TRIGGER update_daily_records_updated_at
  BEFORE UPDATE ON public.daily_records
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- daily_records 인덱스
CREATE INDEX IF NOT EXISTS idx_daily_records_pet_id ON public.daily_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_daily_records_date ON public.daily_records(pet_id, recorded_date);

-- =====================================================
-- 5. AI_HEALTH_CHECKS 테이블 (AI 건강 체크)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.ai_health_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  check_type VARCHAR(50) NOT NULL, -- 'eye', 'skin', 'posture', 'oral', 'ear', 'general'
  image_url TEXT,
  result JSONB NOT NULL DEFAULT '{}',
  confidence_score DECIMAL(5, 2), -- 0~100
  status VARCHAR(20) DEFAULT 'normal', -- 'normal', 'warning', 'danger'
  checked_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ai_health_checks 인덱스
CREATE INDEX IF NOT EXISTS idx_ai_health_checks_pet_id ON public.ai_health_checks(pet_id);
CREATE INDEX IF NOT EXISTS idx_ai_health_checks_type ON public.ai_health_checks(pet_id, check_type);
CREATE INDEX IF NOT EXISTS idx_ai_health_checks_status ON public.ai_health_checks(pet_id, status);

-- =====================================================
-- 6. FOOD_RECORDS 테이블 (음식 기록)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.food_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  recorded_date DATE NOT NULL,
  recorded_time TIME,
  meal_type VARCHAR(20), -- 'breakfast', 'lunch', 'dinner', 'snack'
  food_name VARCHAR(200),
  amount DECIMAL(10, 2), -- 그램 단위
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- food_records updated_at 트리거
DROP TRIGGER IF EXISTS update_food_records_updated_at ON public.food_records;
CREATE TRIGGER update_food_records_updated_at
  BEFORE UPDATE ON public.food_records
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- food_records 인덱스
CREATE INDEX IF NOT EXISTS idx_food_records_pet_id ON public.food_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_food_records_date ON public.food_records(pet_id, recorded_date);

-- =====================================================
-- 7. WATER_RECORDS 테이블 (음수 기록)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.water_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  recorded_date DATE NOT NULL,
  recorded_time TIME,
  amount DECIMAL(10, 2), -- ml 단위
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- water_records 인덱스
CREATE INDEX IF NOT EXISTS idx_water_records_pet_id ON public.water_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_water_records_date ON public.water_records(pet_id, recorded_date);

-- =====================================================
-- 8. SCHEDULES 테이블 (일정 관리)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  color VARCHAR(10) NOT NULL DEFAULT '#FF9A42', -- hex color
  reminder_minutes INT, -- 알림 (분 전)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- schedules updated_at 트리거
DROP TRIGGER IF EXISTS update_schedules_updated_at ON public.schedules;
CREATE TRIGGER update_schedules_updated_at
  BEFORE UPDATE ON public.schedules
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- schedules 인덱스
CREATE INDEX IF NOT EXISTS idx_schedules_pet_id ON public.schedules(pet_id);
CREATE INDEX IF NOT EXISTS idx_schedules_time ON public.schedules(pet_id, start_time);

-- =====================================================
-- 9. NOTIFICATIONS 테이블 (알림)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES public.pets(id) ON DELETE SET NULL,
  type VARCHAR(50) NOT NULL, -- 'reminder', 'health_warning', 'system'
  title VARCHAR(200) NOT NULL,
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- notifications 인덱스
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, is_read);

-- =====================================================
-- 10. WCI_RECORDS 테이블 (체형 지수 기록)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.wci_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id UUID NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
  recorded_date DATE NOT NULL,
  wci_score DECIMAL(4, 2) NOT NULL, -- 체형 지수
  status VARCHAR(20), -- 'underweight', 'normal', 'overweight'
  image_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pet_id, recorded_date)
);

-- wci_records 인덱스
CREATE INDEX IF NOT EXISTS idx_wci_records_pet_id ON public.wci_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_wci_records_date ON public.wci_records(pet_id, recorded_date);

-- =====================================================
-- 완료 메시지
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ 모든 테이블이 성공적으로 생성되었습니다!';
END $$;
