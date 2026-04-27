-- Supabase Configuration
-- Centralized connection settings for the multiplayer module

-- Attempt to load local environment variables if available
local env = {}
pcall(function() env = require("env") end)

return {
    url = "https://pjlpuyicytcfowacmzgz.supabase.co",
    anon_key = os.getenv("SUPABASE_ANON_KEY") or env.SUPABASE_ANON_KEY or "YOUR_ANON_KEY_HERE",
}
