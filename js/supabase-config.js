window.SUPABASE_CONFIG = {
  url: 'https://fxkrulluuuasruqrpvgm.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4a3J1bGx1dXVhc3J1cXJwdmdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5NjIwOTksImV4cCI6MjA5NDUzODA5OX0._WtHodshj50jIXWSDbyqM3Us-qgatK1M1vsyUE5Hs5U'
};
window.supabaseClient = window.supabase ? window.supabase.createClient(window.SUPABASE_CONFIG.url, window.SUPABASE_CONFIG.anonKey) : null;
