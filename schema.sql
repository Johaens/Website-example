-- ================================================================
-- SideQuest AI Database Schema (PostgreSQL for Supabase)
-- ================================================================

-- Create custom types for Quest Types and Rarity Tiers
CREATE TYPE quest_type_enum AS ENUM ('main', 'side', 'boss');
CREATE TYPE rarity_enum AS ENUM ('Common', 'Rare', 'Epic', 'Legendary');

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    total_xp INT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 1,
    selected_theme VARCHAR(50) NOT NULL DEFAULT 'cyberpunk',
    companion_persona VARCHAR(50) NOT NULL DEFAULT 'sarcastic_coach',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Daily Briefings Table
CREATE TABLE IF NOT EXISTS public.daily_briefings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    energy_level INT NOT NULL CHECK (energy_level >= 1 AND energy_level <= 10),
    weather VARCHAR(50) NOT NULL DEFAULT 'sunny',
    mood_tags TEXT[] NOT NULL DEFAULT '{}',
    raw_input TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Quests Table
CREATE TABLE IF NOT EXISTS public.quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    briefing_id UUID REFERENCES public.daily_briefings(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    quest_type quest_type_enum NOT NULL DEFAULT 'main',
    xp_reward INT NOT NULL DEFAULT 25,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    rerouted_from_id UUID REFERENCES public.quests(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Daily Cards Table (Trading Cards from Nightly Debrief)
CREATE TABLE IF NOT EXISTS public.daily_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    card_title VARCHAR(255) NOT NULL,
    lore_text TEXT NOT NULL,
    image_url TEXT NOT NULL,
    rarity rarity_enum NOT NULL DEFAULT 'Common',
    xp_earned INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for Fast Query Performance
CREATE INDEX IF NOT EXISTS idx_quests_user_id ON public.quests(user_id);
CREATE INDEX IF NOT EXISTS idx_quests_briefing_id ON public.quests(briefing_id);
CREATE INDEX IF NOT EXISTS idx_daily_briefings_user ON public.daily_briefings(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_cards_user ON public.daily_cards(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_briefings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_cards ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can manage own briefings" ON public.daily_briefings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own quests" ON public.quests FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own daily cards" ON public.daily_cards FOR ALL USING (auth.uid() = user_id);

-- Trigger to auto-create profile on Auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, total_xp, level, selected_theme, companion_persona)
  VALUES (new.id, 0, 1, 'cyberpunk', 'sarcastic_coach');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
