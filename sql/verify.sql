-- ============================================================================
-- IPL 2025 Cricket Database - Verification & Sample Queries
-- Run these after ingestion to verify data integrity
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATA INTEGRITY CHECKS
-- ============================================================================

-- 1.1 Row counts for all tables
SELECT 'matches' AS table_name, COUNT(*) AS row_count FROM matches
UNION ALL
SELECT 'innings', COUNT(*) FROM innings
UNION ALL
SELECT 'ball_by_ball', COUNT(*) FROM ball_by_ball
UNION ALL
SELECT 'players', COUNT(*) FROM players;

-- 1.2 Verify all matches have innings
SELECT 
    m.match_id,
    m.source_file,
    COUNT(i.innings_id) AS innings_count
FROM matches m
LEFT JOIN innings i ON m.match_id = i.match_id
GROUP BY m.match_id, m.source_file
HAVING COUNT(i.innings_id) = 0;

-- 1.3 Verify all innings have deliveries
SELECT 
    i.innings_id,
    i.match_id,
    i.innings_number,
    COUNT(b.ball_id) AS delivery_count
FROM innings i
LEFT JOIN ball_by_ball b ON i.match_id = b.match_id AND i.innings_number = b.innings_number
GROUP BY i.innings_id, i.match_id, i.innings_number
HAVING COUNT(b.ball_id) = 0;

-- 1.4 Check for NULL values in critical columns
SELECT 
    'matches with NULL team1' AS issue,
    COUNT(*) AS count
FROM matches WHERE team1 IS NULL
UNION ALL
SELECT 'matches with NULL venue', COUNT(*) FROM matches WHERE venue IS NULL
UNION ALL
SELECT 'deliveries with NULL striker', COUNT(*) FROM ball_by_ball WHERE striker IS NULL
UNION ALL
SELECT 'deliveries with NULL bowler', COUNT(*) FROM ball_by_ball WHERE bowler IS NULL;

-- 1.5 Verify innings totals match ball-by-ball sums
SELECT 
    i.match_id,
    i.innings_number,
    i.total_runs AS innings_total,
    SUM(b.runs_total) AS calculated_total,
    i.total_runs - SUM(b.runs_total) AS difference
FROM innings i
JOIN ball_by_ball b ON i.match_id = b.match_id AND i.innings_number = b.innings_number
GROUP BY i.match_id, i.innings_number, i.total_runs
HAVING i.total_runs != SUM(b.runs_total);

-- ============================================================================
-- SECTION 2: SUMMARY STATISTICS
-- ============================================================================

-- 2.1 Matches by team
SELECT 
    team,
    COUNT(*) AS matches_played,
    SUM(CASE WHEN winner = team THEN 1 ELSE 0 END) AS wins,
    ROUND(SUM(CASE WHEN winner = team THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS win_percentage
FROM (
    SELECT team1 AS team, winner FROM matches
    UNION ALL
    SELECT team2 AS team, winner FROM matches
) t
GROUP BY team
ORDER BY win_percentage DESC;

-- 2.2 Matches by venue
SELECT 
    venue,
    city,
    COUNT(*) AS matches,
    COUNT(*) FILTER (WHERE toss_decision = 'bat') AS chose_bat,
    COUNT(*) FILTER (WHERE toss_decision = 'field') AS chose_field
FROM matches
GROUP BY venue, city
ORDER BY matches DESC;

-- 2.3 Deliveries by phase
SELECT 
    phase,
    COUNT(*) AS total_deliveries,
    SUM(runs_total) AS total_runs,
    COUNT(*) FILTER (WHERE is_wicket) AS wickets,
    ROUND(SUM(runs_total) * 6.0 / COUNT(*) FILTER (WHERE is_legal_delivery), 2) AS run_rate,
    COUNT(*) FILTER (WHERE is_boundary) AS boundaries
FROM ball_by_ball
GROUP BY phase
ORDER BY 
    CASE phase 
        WHEN 'powerplay' THEN 1 
        WHEN 'middle' THEN 2 
        WHEN 'death' THEN 3 
    END;

-- ============================================================================
-- SECTION 3: LLM-FRIENDLY SAMPLE QUERIES
-- These demonstrate the types of questions Blackbox DB Chat can answer
-- ============================================================================

-- Q1: "Who are the top run scorers in IPL 2025?"
SELECT 
    striker AS batter,
    COUNT(DISTINCT match_id) AS matches,
    SUM(runs_batter) AS total_runs,
    COUNT(*) FILTER (WHERE is_legal_delivery) AS balls_faced,
    COUNT(*) FILTER (WHERE is_four) AS fours,
    COUNT(*) FILTER (WHERE is_six) AS sixes,
    ROUND(SUM(runs_batter) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE is_legal_delivery), 0), 2) AS strike_rate
FROM ball_by_ball
GROUP BY striker
ORDER BY total_runs DESC
LIMIT 15;

-- Q2: "Who are the top wicket takers in IPL 2025?"
SELECT 
    bowler,
    COUNT(DISTINCT match_id) AS matches,
    COUNT(*) FILTER (WHERE is_wicket) AS wickets,
    SUM(runs_total) AS runs_conceded,
    COUNT(*) FILTER (WHERE is_legal_delivery) AS balls_bowled,
    ROUND(SUM(runs_total) * 6.0 / NULLIF(COUNT(*) FILTER (WHERE is_legal_delivery), 0), 2) AS economy,
    ROUND(COUNT(*) FILTER (WHERE is_legal_delivery) * 1.0 / NULLIF(COUNT(*) FILTER (WHERE is_wicket), 0), 2) AS strike_rate
FROM ball_by_ball
GROUP BY bowler
HAVING COUNT(*) FILTER (WHERE is_wicket) > 0
ORDER BY wickets DESC
LIMIT 15;

-- Q3: "Best finishers in death overs (overs 16-20)"
SELECT 
    striker AS batter,
    COUNT(DISTINCT match_id) AS matches,
    SUM(runs_batter) AS death_runs,
    COUNT(*) FILTER (WHERE is_legal_delivery) AS balls_faced,
    COUNT(*) FILTER (WHERE is_six) AS sixes,
    ROUND(SUM(runs_batter) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE is_legal_delivery), 0), 2) AS strike_rate
FROM ball_by_ball
WHERE phase = 'death'
GROUP BY striker
HAVING COUNT(*) FILTER (WHERE is_legal_delivery) >= 20  -- Minimum 20 balls faced
ORDER BY strike_rate DESC
LIMIT 15;

-- Q4: "Best death over bowlers by economy"
SELECT 
    bowler,
    COUNT(DISTINCT match_id) AS matches,
    COUNT(*) FILTER (WHERE is_legal_delivery) AS balls_bowled,
    SUM(runs_total) AS runs_conceded,
    COUNT(*) FILTER (WHERE is_wicket) AS wickets,
    ROUND(SUM(runs_total) * 6.0 / NULLIF(COUNT(*) FILTER (WHERE is_legal_delivery), 0), 2) AS economy
FROM ball_by_ball
WHERE phase = 'death'
GROUP BY bowler
HAVING COUNT(*) FILTER (WHERE is_legal_delivery) >= 30  -- Minimum 5 overs
ORDER BY economy ASC
LIMIT 15;

-- Q5: "Which team collapses most after powerplay?"
-- (Wickets lost in middle overs relative to runs scored)
SELECT 
    batting_team,
    COUNT(DISTINCT match_id) AS matches,
    SUM(runs_total) AS middle_over_runs,
    COUNT(*) FILTER (WHERE is_wicket) AS middle_over_wickets,
    ROUND(SUM(runs_total) * 1.0 / NULLIF(COUNT(*) FILTER (WHERE is_wicket), 0), 2) AS runs_per_wicket
FROM ball_by_ball
WHERE phase = 'middle'
GROUP BY batting_team
ORDER BY runs_per_wicket ASC
LIMIT 10;

-- Q6: "Does winning toss help at each venue?"
SELECT 
    venue,
    COUNT(*) AS total_matches,
    COUNT(*) FILTER (WHERE toss_winner = winner) AS toss_winner_won,
    ROUND(COUNT(*) FILTER (WHERE toss_winner = winner) * 100.0 / COUNT(*), 2) AS toss_advantage_pct,
    COUNT(*) FILTER (WHERE toss_decision = 'field' AND toss_winner = winner) AS field_first_wins,
    COUNT(*) FILTER (WHERE toss_decision = 'bat' AND toss_winner = winner) AS bat_first_wins
FROM matches
WHERE winner IS NOT NULL
GROUP BY venue
HAVING COUNT(*) >= 3
ORDER BY toss_advantage_pct DESC;

-- Q7: "Most boundaries hit by a player"
SELECT 
    striker AS batter,
    COUNT(*) FILTER (WHERE is_four) AS fours,
    COUNT(*) FILTER (WHERE is_six) AS sixes,
    COUNT(*) FILTER (WHERE is_boundary) AS total_boundaries,
    SUM(CASE WHEN is_four THEN 4 WHEN is_six THEN 6 ELSE 0 END) AS boundary_runs
FROM ball_by_ball
GROUP BY striker
ORDER BY total_boundaries DESC
LIMIT 15;

-- Q8: "Best powerplay bowlers"
SELECT 
    bowler,
    COUNT(DISTINCT match_id) AS matches,
    COUNT(*) FILTER (WHERE is_legal_delivery) AS balls,
    SUM(runs_total) AS runs,
    COUNT(*) FILTER (WHERE is_wicket) AS wickets,
    ROUND(SUM(runs_total) * 6.0 / NULLIF(COUNT(*) FILTER (WHERE is_legal_delivery), 0), 2) AS economy
FROM ball_by_ball
WHERE phase = 'powerplay'
GROUP BY bowler
HAVING COUNT(*) FILTER (WHERE is_legal_delivery) >= 24  -- Minimum 4 overs
ORDER BY economy ASC
LIMIT 15;

-- Q9: "Head-to-head: Team vs Team"
SELECT 
    team1,
    team2,
    COUNT(*) AS matches,
    COUNT(*) FILTER (WHERE winner = team1) AS team1_wins,
    COUNT(*) FILTER (WHERE winner = team2) AS team2_wins,
    COUNT(*) FILTER (WHERE winner IS NULL) AS no_results
FROM matches
GROUP BY team1, team2
ORDER BY matches DESC;

-- Q10: "Highest individual scores"
SELECT 
    m.match_date,
    m.venue,
    b.striker AS batter,
    b.batting_team,
    SUM(b.runs_batter) AS runs,
    COUNT(*) FILTER (WHERE b.is_legal_delivery) AS balls,
    COUNT(*) FILTER (WHERE b.is_four) AS fours,
    COUNT(*) FILTER (WHERE b.is_six) AS sixes,
    ROUND(SUM(b.runs_batter) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE b.is_legal_delivery), 0), 2) AS strike_rate
FROM ball_by_ball b
JOIN matches m ON b.match_id = m.match_id
GROUP BY m.match_id, m.match_date, m.venue, b.striker, b.batting_team
ORDER BY runs DESC
LIMIT 15;

-- Q11: "Best bowling figures in a match"
SELECT 
    m.match_date,
    m.venue,
    b.bowler,
    b.bowling_team,
    COUNT(*) FILTER (WHERE b.is_wicket) AS wickets,
    SUM(b.runs_total) AS runs_conceded,
    COUNT(*) FILTER (WHERE b.is_legal_delivery) AS balls,
    ROUND(SUM(b.runs_total) * 6.0 / NULLIF(COUNT(*) FILTER (WHERE b.is_legal_delivery), 0), 2) AS economy
FROM ball_by_ball b
JOIN matches m ON b.match_id = m.match_id
GROUP BY m.match_id, m.match_date, m.venue, b.bowler, b.bowling_team
HAVING COUNT(*) FILTER (WHERE b.is_wicket) >= 3
ORDER BY wickets DESC, runs_conceded ASC
LIMIT 15;

-- Q12: "Dot ball percentage by bowler"
SELECT 
    bowler,
    COUNT(*) FILTER (WHERE is_legal_delivery) AS legal_balls,
    COUNT(*) FILTER (WHERE is_dot_ball) AS dot_balls,
    ROUND(COUNT(*) FILTER (WHERE is_dot_ball) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE is_legal_delivery), 0), 2) AS dot_ball_pct
FROM ball_by_ball
GROUP BY bowler
HAVING COUNT(*) FILTER (WHERE is_legal_delivery) >= 60  -- Minimum 10 overs
ORDER BY dot_ball_pct DESC
LIMIT 15;

-- Q13: "Most expensive overs"
SELECT 
    m.match_date,
    b.batting_team,
    b.bowler,
    b.over_number + 1 AS over_number_display,
    SUM(b.runs_total) AS runs_in_over
FROM ball_by_ball b
JOIN matches m ON b.match_id = m.match_id
GROUP BY m.match_id, m.match_date, b.batting_team, b.bowler, b.over_number
ORDER BY runs_in_over DESC
LIMIT 15;

-- Q14: "Wicket types distribution"
SELECT 
    wicket_type,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM ball_by_ball
WHERE is_wicket = TRUE
GROUP BY wicket_type
ORDER BY count DESC;

-- Q15: "Player dismissal patterns"
SELECT 
    player_dismissed AS batter,
    COUNT(*) AS total_dismissals,
    COUNT(*) FILTER (WHERE wicket_type = 'caught') AS caught,
    COUNT(*) FILTER (WHERE wicket_type = 'bowled') AS bowled,
    COUNT(*) FILTER (WHERE wicket_type = 'lbw') AS lbw,
    COUNT(*) FILTER (WHERE wicket_type = 'run out') AS run_out,
    COUNT(*) FILTER (WHERE wicket_type = 'stumped') AS stumped
FROM ball_by_ball
WHERE is_wicket = TRUE AND player_dismissed IS NOT NULL
GROUP BY player_dismissed
HAVING COUNT(*) >= 3
ORDER BY total_dismissals DESC
LIMIT 15;

-- ============================================================================
-- SECTION 4: VIEWS VERIFICATION
-- ============================================================================

-- Verify batter_match_stats view
SELECT * FROM batter_match_stats LIMIT 5;

-- Verify bowler_match_stats view
SELECT * FROM bowler_match_stats LIMIT 5;

-- Verify phase_batting_stats view
SELECT * FROM phase_batting_stats WHERE phase = 'death' ORDER BY strike_rate DESC LIMIT 5;

-- Verify phase_bowling_stats view
SELECT * FROM phase_bowling_stats WHERE phase = 'death' ORDER BY economy ASC LIMIT 5;

-- Verify toss_venue_analysis view
SELECT * FROM toss_venue_analysis ORDER BY total_matches DESC LIMIT 5;

-- ============================================================================
-- SECTION 5: QUICK HEALTH CHECK (Run this for fast verification)
-- ============================================================================

SELECT 
    'Database Health Check' AS status,
    (SELECT COUNT(*) FROM matches) AS matches,
    (SELECT COUNT(*) FROM innings) AS innings,
    (SELECT COUNT(*) FROM ball_by_ball) AS deliveries,
    (SELECT COUNT(*) FROM players) AS players,
    (SELECT COUNT(DISTINCT striker) FROM ball_by_ball) AS unique_batters,
    (SELECT COUNT(DISTINCT bowler) FROM ball_by_ball) AS unique_bowlers,
    (SELECT MIN(match_date) FROM matches) AS first_match,
    (SELECT MAX(match_date) FROM matches) AS last_match;
