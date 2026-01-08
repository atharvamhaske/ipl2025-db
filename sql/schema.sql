-- ============================================================================
-- IPL 2025 Cricket Database Schema
-- Optimized for LLM/Natural Language Querying via Blackbox DB Chat
-- ============================================================================

-- Drop existing tables (in correct order due to foreign keys)
DROP TABLE IF EXISTS ball_by_ball CASCADE;
DROP TABLE IF EXISTS innings CASCADE;
DROP TABLE IF EXISTS players CASCADE;
DROP TABLE IF EXISTS matches CASCADE;

-- ============================================================================
-- TABLE 1: matches
-- Stores match-level metadata. One row per match.
-- ============================================================================
CREATE TABLE matches (
    match_id SERIAL PRIMARY KEY,
    source_file TEXT UNIQUE NOT NULL,           -- For idempotency (e.g., "1473438.yaml")
    match_type TEXT NOT NULL,                   -- T20, ODI, Test, etc.
    competition TEXT,                           -- IPL, World Cup, etc.
    season INT,                                 -- Year/season (e.g., 2025)
    match_date DATE NOT NULL,                   -- First day of match
    venue TEXT NOT NULL,                        -- Full venue name
    city TEXT,                                  -- City (may be NULL)
    team1 TEXT NOT NULL,                        -- First team listed
    team2 TEXT NOT NULL,                        -- Second team listed
    toss_winner TEXT,                           -- Team that won the toss
    toss_decision TEXT,                         -- 'bat' or 'field'
    winner TEXT,                                -- Winning team (NULL if no result)
    win_by_runs INT DEFAULT 0,                  -- Runs margin (0 if won by wickets)
    win_by_wickets INT DEFAULT 0,               -- Wickets margin (0 if won by runs)
    result_type TEXT,                           -- 'normal', 'tie', 'no result', 'draw'
    player_of_match TEXT,                       -- Player of the match
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common query patterns
CREATE INDEX idx_matches_date ON matches(match_date);
CREATE INDEX idx_matches_venue ON matches(venue);
CREATE INDEX idx_matches_city ON matches(city);
CREATE INDEX idx_matches_team1 ON matches(team1);
CREATE INDEX idx_matches_team2 ON matches(team2);
CREATE INDEX idx_matches_winner ON matches(winner);
CREATE INDEX idx_matches_season ON matches(season);
CREATE INDEX idx_matches_toss_winner ON matches(toss_winner);

-- ============================================================================
-- TABLE 2: innings
-- Stores innings-level data. Typically 2 rows per match (can be more for super overs).
-- ============================================================================
CREATE TABLE innings (
    innings_id SERIAL PRIMARY KEY,
    match_id INT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    innings_number INT NOT NULL,                -- 1, 2, 3 (super over), 4 (super over)
    batting_team TEXT NOT NULL,                 -- Team batting in this innings
    bowling_team TEXT NOT NULL,                 -- Team bowling in this innings
    total_runs INT DEFAULT 0,                   -- Total runs scored
    total_wickets INT DEFAULT 0,                -- Total wickets lost
    total_overs DECIMAL(4,1) DEFAULT 0,         -- Overs faced (e.g., 19.3)
    total_extras INT DEFAULT 0,                 -- Total extras conceded
    is_super_over BOOLEAN DEFAULT FALSE,        -- True if this is a super over
    UNIQUE(match_id, innings_number)
);

CREATE INDEX idx_innings_match ON innings(match_id);
CREATE INDEX idx_innings_batting_team ON innings(batting_team);
CREATE INDEX idx_innings_bowling_team ON innings(bowling_team);

-- ============================================================================
-- TABLE 3: ball_by_ball
-- Stores every delivery. This is the core analytics table.
-- ============================================================================
CREATE TABLE ball_by_ball (
    ball_id SERIAL PRIMARY KEY,
    match_id INT NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    innings_number INT NOT NULL,                -- 1, 2, 3, 4
    over_number INT NOT NULL,                   -- 0-19 for T20 (0-indexed)
    ball_number INT NOT NULL,                   -- Ball within the over (1-6+)
    batting_team TEXT NOT NULL,                 -- Team batting
    bowling_team TEXT NOT NULL,                 -- Team bowling
    striker TEXT NOT NULL,                      -- Batter facing the ball
    non_striker TEXT NOT NULL,                  -- Batter at non-striker end
    bowler TEXT NOT NULL,                       -- Bowler delivering
    
    -- Runs breakdown
    runs_batter INT DEFAULT 0,                  -- Runs scored by batter
    runs_extras INT DEFAULT 0,                  -- Extra runs (wides, no-balls, etc.)
    runs_total INT DEFAULT 0,                   -- Total runs from this delivery
    
    -- Extras breakdown (for detailed analysis)
    extras_wides INT DEFAULT 0,
    extras_noballs INT DEFAULT 0,
    extras_byes INT DEFAULT 0,
    extras_legbyes INT DEFAULT 0,
    extras_penalty INT DEFAULT 0,
    
    -- Wicket information
    is_wicket BOOLEAN DEFAULT FALSE,            -- True if wicket fell
    wicket_type TEXT,                           -- 'bowled', 'caught', 'lbw', 'run out', etc.
    player_dismissed TEXT,                      -- Player who got out
    fielder TEXT,                               -- Fielder involved (if applicable)
    
    -- Computed/derived fields for easier querying
    is_boundary BOOLEAN DEFAULT FALSE,          -- True if 4 or 6
    is_four BOOLEAN DEFAULT FALSE,              -- True if 4
    is_six BOOLEAN DEFAULT FALSE,               -- True if 6
    is_dot_ball BOOLEAN DEFAULT FALSE,          -- True if 0 runs (no extras)
    is_legal_delivery BOOLEAN DEFAULT TRUE,     -- False for wides/no-balls
    
    -- Phase classification for T20 analysis
    phase TEXT,                                 -- 'powerplay', 'middle', 'death'
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Comprehensive indexes for analytics queries
CREATE INDEX idx_bbb_match ON ball_by_ball(match_id);
CREATE INDEX idx_bbb_innings ON ball_by_ball(match_id, innings_number);
CREATE INDEX idx_bbb_over ON ball_by_ball(over_number);
CREATE INDEX idx_bbb_striker ON ball_by_ball(striker);
CREATE INDEX idx_bbb_bowler ON ball_by_ball(bowler);
CREATE INDEX idx_bbb_batting_team ON ball_by_ball(batting_team);
CREATE INDEX idx_bbb_bowling_team ON ball_by_ball(bowling_team);
CREATE INDEX idx_bbb_wicket ON ball_by_ball(is_wicket);
CREATE INDEX idx_bbb_boundary ON ball_by_ball(is_boundary);
CREATE INDEX idx_bbb_phase ON ball_by_ball(phase);
CREATE INDEX idx_bbb_dismissed ON ball_by_ball(player_dismissed);

-- Composite indexes for common query patterns
CREATE INDEX idx_bbb_bowler_wicket ON ball_by_ball(bowler, is_wicket);
CREATE INDEX idx_bbb_striker_runs ON ball_by_ball(striker, runs_batter);
CREATE INDEX idx_bbb_phase_bowler ON ball_by_ball(phase, bowler);
CREATE INDEX idx_bbb_phase_striker ON ball_by_ball(phase, striker);

-- ============================================================================
-- TABLE 4: players
-- Unique players with their team associations (can play for multiple teams)
-- ============================================================================
CREATE TABLE players (
    player_id SERIAL PRIMARY KEY,
    player_name TEXT NOT NULL,
    team TEXT NOT NULL,
    UNIQUE(player_name, team)
);

CREATE INDEX idx_players_name ON players(player_name);
CREATE INDEX idx_players_team ON players(team);

-- ============================================================================
-- VIEWS for common analytics (LLM-friendly)
-- ============================================================================

-- View: Batter statistics per match
CREATE OR REPLACE VIEW batter_match_stats AS
SELECT 
    m.match_id,
    m.match_date,
    m.venue,
    b.batting_team,
    b.striker AS batter_name,
    COUNT(*) FILTER (WHERE b.is_legal_delivery) AS balls_faced,
    SUM(b.runs_batter) AS runs_scored,
    COUNT(*) FILTER (WHERE b.is_four) AS fours,
    COUNT(*) FILTER (WHERE b.is_six) AS sixes,
    COUNT(*) FILTER (WHERE b.is_dot_ball) AS dot_balls,
    ROUND(SUM(b.runs_batter) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE b.is_legal_delivery), 0), 2) AS strike_rate,
    MAX(CASE WHEN b.is_wicket AND b.player_dismissed = b.striker THEN b.wicket_type END) AS dismissal_type
FROM ball_by_ball b
JOIN matches m ON b.match_id = m.match_id
GROUP BY m.match_id, m.match_date, m.venue, b.batting_team, b.striker;

-- View: Bowler statistics per match
CREATE OR REPLACE VIEW bowler_match_stats AS
SELECT 
    m.match_id,
    m.match_date,
    m.venue,
    b.bowling_team,
    b.bowler AS bowler_name,
    COUNT(*) FILTER (WHERE b.is_legal_delivery) AS balls_bowled,
    ROUND(COUNT(*) FILTER (WHERE b.is_legal_delivery) / 6.0, 1) AS overs_bowled,
    SUM(b.runs_total) AS runs_conceded,
    COUNT(*) FILTER (WHERE b.is_wicket) AS wickets_taken,
    COUNT(*) FILTER (WHERE b.is_dot_ball) AS dot_balls,
    SUM(b.extras_wides) AS wides,
    SUM(b.extras_noballs) AS no_balls,
    ROUND(SUM(b.runs_total) * 6.0 / NULLIF(COUNT(*) FILTER (WHERE b.is_legal_delivery), 0), 2) AS economy_rate
FROM ball_by_ball b
JOIN matches m ON b.match_id = m.match_id
GROUP BY m.match_id, m.match_date, m.venue, b.bowling_team, b.bowler;

-- View: Phase-wise batting performance
CREATE OR REPLACE VIEW phase_batting_stats AS
SELECT 
    b.striker AS batter_name,
    b.phase,
    COUNT(DISTINCT b.match_id) AS matches,
    COUNT(*) FILTER (WHERE b.is_legal_delivery) AS balls_faced,
    SUM(b.runs_batter) AS runs_scored,
    COUNT(*) FILTER (WHERE b.is_four) AS fours,
    COUNT(*) FILTER (WHERE b.is_six) AS sixes,
    ROUND(SUM(b.runs_batter) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE b.is_legal_delivery), 0), 2) AS strike_rate,
    COUNT(*) FILTER (WHERE b.is_wicket AND b.player_dismissed = b.striker) AS dismissals
FROM ball_by_ball b
GROUP BY b.striker, b.phase;

-- View: Phase-wise bowling performance
CREATE OR REPLACE VIEW phase_bowling_stats AS
SELECT 
    b.bowler AS bowler_name,
    b.phase,
    COUNT(DISTINCT b.match_id) AS matches,
    COUNT(*) FILTER (WHERE b.is_legal_delivery) AS balls_bowled,
    SUM(b.runs_total) AS runs_conceded,
    COUNT(*) FILTER (WHERE b.is_wicket) AS wickets_taken,
    ROUND(SUM(b.runs_total) * 6.0 / NULLIF(COUNT(*) FILTER (WHERE b.is_legal_delivery), 0), 2) AS economy_rate
FROM ball_by_ball b
GROUP BY b.bowler, b.phase;

-- View: Toss analysis by venue
CREATE OR REPLACE VIEW toss_venue_analysis AS
SELECT 
    m.venue,
    m.city,
    COUNT(*) AS total_matches,
    COUNT(*) FILTER (WHERE m.toss_decision = 'bat') AS chose_bat,
    COUNT(*) FILTER (WHERE m.toss_decision = 'field') AS chose_field,
    COUNT(*) FILTER (WHERE m.toss_winner = m.winner) AS toss_winner_won_match,
    ROUND(COUNT(*) FILTER (WHERE m.toss_winner = m.winner) * 100.0 / COUNT(*), 2) AS toss_win_match_win_pct
FROM matches m
WHERE m.winner IS NOT NULL
GROUP BY m.venue, m.city;

-- View: Team head-to-head
CREATE OR REPLACE VIEW team_head_to_head AS
SELECT 
    LEAST(m.team1, m.team2) AS team_a,
    GREATEST(m.team1, m.team2) AS team_b,
    COUNT(*) AS matches_played,
    COUNT(*) FILTER (WHERE m.winner = LEAST(m.team1, m.team2)) AS team_a_wins,
    COUNT(*) FILTER (WHERE m.winner = GREATEST(m.team1, m.team2)) AS team_b_wins,
    COUNT(*) FILTER (WHERE m.winner IS NULL OR m.result_type = 'no result') AS no_results
FROM matches m
GROUP BY LEAST(m.team1, m.team2), GREATEST(m.team1, m.team2);

-- ============================================================================
-- Comments for LLM understanding
-- ============================================================================
COMMENT ON TABLE matches IS 'Contains one row per cricket match with metadata like teams, venue, toss, and result';
COMMENT ON TABLE innings IS 'Contains one row per innings in a match (usually 2, more for super overs)';
COMMENT ON TABLE ball_by_ball IS 'Contains every delivery bowled with full context - the core analytics table';
COMMENT ON TABLE players IS 'Unique players and their team associations';

COMMENT ON COLUMN ball_by_ball.phase IS 'T20 phase: powerplay (overs 0-5), middle (overs 6-14), death (overs 15-19)';
COMMENT ON COLUMN ball_by_ball.is_legal_delivery IS 'False for wides and no-balls which do not count as balls faced';
COMMENT ON COLUMN matches.source_file IS 'Original YAML filename for idempotent ingestion';

-- ============================================================================
-- Grant permissions (adjust as needed)
-- ============================================================================
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO app_user;

SELECT 'Schema created successfully!' AS status;
