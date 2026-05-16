import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const SUPABASE_URL = 'https://fxkrulluuuasruqrpvgm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4a3J1bGx1dXVhc3J1cXJwdmdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5NjIwOTksImV4cCI6MjA5NDUzODA5OX0._WtHodshj50jIXWSDbyqM3Us-qgatK1M1vsyUE5Hs5U';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
