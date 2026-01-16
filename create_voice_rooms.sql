-- Reset everything for a clean installation
-- DROP TABLE ... CASCADE automatically drops associated triggers and constraints
DROP TABLE IF EXISTS public.voice_room_participants CASCADE;
DROP TABLE IF EXISTS public.voice_rooms CASCADE;
DROP TABLE IF EXISTS public.active_calls CASCADE; -- Cleanup legacy table if exists

DROP FUNCTION IF EXISTS public.on_voice_room_deleted();
DROP FUNCTION IF EXISTS public.update_room_participant_count();
DROP FUNCTION IF EXISTS public.increment_room_participants(TEXT, INTEGER);

-- Create voice_rooms table
CREATE TABLE IF NOT EXISTS public.voice_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    participants_count INTEGER DEFAULT 0,
    room_name TEXT UNIQUE NOT NULL -- Used for Jitsi channel
);

-- Create voice_room_participants table for reliable tracking
CREATE TABLE IF NOT EXISTS public.voice_room_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    room_name TEXT NOT NULL REFERENCES public.voice_rooms(room_name) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(room_name, user_id)
);

-- Enable RLS
ALTER TABLE public.voice_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voice_room_participants ENABLE ROW LEVEL SECURITY;

-- voice_rooms Policies
CREATE POLICY "Anyone can view active voice rooms" ON public.voice_rooms FOR SELECT USING (is_active = true);
CREATE POLICY "Anyone can create voice rooms" ON public.voice_rooms FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can manage voice rooms" ON public.voice_rooms FOR ALL USING (true);

-- voice_room_participants Policies
CREATE POLICY "Anyone can view participants" ON public.voice_room_participants FOR SELECT USING (true);
CREATE POLICY "Anyone can join/leave rooms" ON public.voice_room_participants FOR ALL USING (true) WITH CHECK (true);

-- Trigger to automatically update participants_count in voice_rooms
CREATE OR REPLACE FUNCTION public.update_room_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.voice_rooms 
        SET participants_count = (SELECT count(*) FROM public.voice_room_participants WHERE room_name = NEW.room_name)
        WHERE room_name = NEW.room_name;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.voice_rooms 
        SET participants_count = (SELECT count(*) FROM public.voice_room_participants WHERE room_name = OLD.room_name)
        WHERE room_name = OLD.room_name;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_participant_count
AFTER INSERT OR DELETE ON public.voice_room_participants
FOR EACH ROW EXECUTE FUNCTION public.update_room_participant_count();

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_voice_rooms_active ON public.voice_rooms(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_participants_room ON public.voice_room_participants(room_name);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_room_participants;
