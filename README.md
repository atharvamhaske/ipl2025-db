# 🏏 IPL 2025 Cricket Database

A fully normalized PostgreSQL database for IPL 2025 cricket data, optimized for natural language querying via **Blackbox DB Chat**.

---

**Created by Atharva Mhaske with pair programmer [@blackboxai](https://blackbox.ai)** 🤖

---

## 📁 Project Structure

```
ipl-db/
├── README.md                 # This file
├── data/                     # Raw YAML match files (74 matches)
│   ├── 1473438.yaml
│   ├── 1473439.yaml
│   └── ... (74 files total)
├── scripts/                  # Python & Shell scripts
│   ├── ingest_cricket_data.py   # Main ingestion script
│   └── setup_postgres.sh        # PostgreSQL setup helper
└── sql/                      # SQL files
    ├── schema.sql            # Database schema (tables, indexes, views)
    └── verify.sql            # Verification & sample queries
```

## 📊 Database Schema

### Tables

| Table | Description | Rows |
|-------|-------------|------|
| `matches` | Match-level metadata (teams, venue, toss, result) | 74 |
| `innings` | Innings summary (runs, wickets, overs) | 148 |
| `ball_by_ball` | Every delivery with full context | 17,285 |
| `players` | Unique players with team associations | 202 |

### Pre-built Views (LLM-Friendly)

| View | Description |
|------|-------------|
| `batter_match_stats` | Batter performance per match |
| `bowler_match_stats` | Bowler performance per match |
| `phase_batting_stats` | Batting stats by T20 phase (powerplay/middle/death) |
| `phase_bowling_stats` | Bowling stats by T20 phase |
| `toss_venue_analysis` | Toss impact analysis by venue |
| `team_head_to_head` | Head-to-head records between teams |

## 🚀 Quick Start

### Prerequisites

- PostgreSQL 12+ installed and running
- Python 3.8+ with pip
- Database `cricketdb` created

### Step 1: Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE cricketdb;
\q
```

### Step 2: Install Python Dependencies

```bash
pip install pyyaml psycopg2-binary
```

### Step 3: Initialize Schema

```bash
# Initialize the database schema
psql -U postgres -d cricketdb -f sql/schema.sql
```

### Step 4: Run Data Ingestion

```bash
# Set your database URL
export DATABASE_URL="postgresql://postgres:yourpassword@localhost:5432/cricketdb"

# Run ingestion
python scripts/ingest_cricket_data.py \
    --db-url "$DATABASE_URL" \
    --data-dir ./data/

# Or use the setup script (handles everything)
./scripts/setup_postgres.sh
```

### Step 5: Verify Ingestion

```bash
# Connect to database and run verification
psql -U postgres -d cricketdb -f sql/verify.sql
```

## 🔧 Configuration Options

```bash
python scripts/ingest_cricket_data.py --help

Options:
  --db-url TEXT       PostgreSQL connection URL
  --data-dir TEXT     Directory containing YAML files (default: ./data/)
  --schema-file TEXT  Path to schema SQL file (default: sql/schema.sql)
  --init-schema       Initialize database schema before ingestion
```

## 🏏 Sample Queries for Blackbox DB Chat

Once ingested, you can ask natural language questions like:

### Batting
- "Who are the top run scorers in IPL 2025?"
- "Best finishers in death overs"
- "Highest strike rate in powerplay"
- "Most sixes hit by a player"
- "How many runs did Virat Kohli score in the final?"

### Bowling
- "Top wicket takers in IPL 2025"
- "Best economy rate in death overs"
- "Most dot balls bowled"
- "Best bowling figures in a match"

### Team Analysis
- "Which team wins most after losing toss?"
- "Head-to-head: CSK vs MI"
- "Which team collapses most in middle overs?"

### Venue Analysis
- "Does winning toss help at Wankhede?"
- "Highest scoring venue"
- "Best bowling venue"

## 📐 Schema Details

### matches
| Column | Type | Description |
|--------|------|-------------|
| match_id | SERIAL | Primary key |
| source_file | TEXT | Original YAML filename (for idempotency) |
| match_type | TEXT | T20, ODI, etc. |
| competition | TEXT | IPL |
| season | INT | 2025 |
| match_date | DATE | Match date |
| venue | TEXT | Stadium name |
| city | TEXT | City name |
| team1, team2 | TEXT | Playing teams |
| toss_winner | TEXT | Team that won toss |
| toss_decision | TEXT | 'bat' or 'field' |
| winner | TEXT | Winning team |
| win_by_runs | INT | Margin (if batting first won) |
| win_by_wickets | INT | Margin (if chasing team won) |
| result_type | TEXT | 'normal', 'tie', 'no result' |
| player_of_match | TEXT | Player of the match |

### ball_by_ball
| Column | Type | Description |
|--------|------|-------------|
| ball_id | SERIAL | Primary key |
| match_id | INT | Foreign key to matches |
| innings_number | INT | 1, 2, 3 (super over), 4 |
| over_number | INT | 0-19 (0-indexed) |
| ball_number | INT | 1-6+ |
| batting_team | TEXT | Team batting |
| bowling_team | TEXT | Team bowling |
| striker | TEXT | Batter on strike |
| non_striker | TEXT | Non-striker |
| bowler | TEXT | Bowler |
| runs_batter | INT | Runs scored by batter |
| runs_extras | INT | Extra runs |
| runs_total | INT | Total runs from delivery |
| extras_wides | INT | Wide runs |
| extras_noballs | INT | No-ball runs |
| extras_byes | INT | Bye runs |
| extras_legbyes | INT | Leg-bye runs |
| is_wicket | BOOLEAN | Wicket fell on this ball |
| wicket_type | TEXT | 'bowled', 'caught', 'lbw', etc. |
| player_dismissed | TEXT | Batter dismissed |
| fielder | TEXT | Fielder involved |
| is_boundary | BOOLEAN | Four or six |
| is_four | BOOLEAN | Four hit |
| is_six | BOOLEAN | Six hit |
| is_dot_ball | BOOLEAN | No runs scored |
| is_legal_delivery | BOOLEAN | Not a wide/no-ball |
| phase | TEXT | 'powerplay', 'middle', 'death' |

## 🔄 Re-ingestion

The script is **idempotent** - running it again will skip already-ingested matches:

```bash
# Safe to run multiple times
python scripts/ingest_cricket_data.py --data-dir ./data/
```

To force re-ingestion, drop and recreate the schema:

```bash
psql -U postgres -d cricketdb -f sql/schema.sql
python scripts/ingest_cricket_data.py --data-dir ./data/
```

## 📈 Database Statistics (IPL 2025)

| Metric | Value |
|--------|-------|
| Total Matches | 74 |
| Total Innings | 148 |
| Total Deliveries | 17,285 |
| Unique Players | 202 |
| Unique Batters | 166 |
| Unique Bowlers | 128 |
| Season Start | March 22, 2025 |
| Season End | June 3, 2025 |

## 🏆 Quick Stats (IPL 2025)

### Top Run Scorers
| Batter | Runs | SR |
|--------|------|-----|
| B Sai Sudharsan | 759 | 156.17 |
| SA Yadav | 717 | 167.92 |
| V Kohli | 657 | 144.71 |
| Shubman Gill | 650 | 157.00 |
| MR Marsh | 627 | 164.57 |

### Top Wicket Takers
| Bowler | Wickets | Economy |
|--------|---------|---------|
| M Prasidh Krishna | 26 | 8.58 |
| Noor Ahmad | 24 | 8.32 |
| TA Boult | 23 | 9.02 |
| Arshdeep Singh | 22 | 9.03 |
| JR Hazlewood | 22 | 8.84 |

## 🐛 Troubleshooting

### Connection Issues
```bash
# Test PostgreSQL connection
psql -U postgres -d cricketdb -c "SELECT 1"
```

### Missing Dependencies
```bash
pip install pyyaml psycopg2-binary
```

### Permission Issues
```bash
# Grant permissions
psql -U postgres -d cricketdb -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO your_user"
```

## 🤖 Blackbox DB Chat Integration

Connect your PostgreSQL database to Blackbox DB Chat:

1. **Start Blackbox CLI:**
   ```bash
   blackbox
   ```

2. **Configure database connection:**
   ```bash
   /db configure
   ```
   Select PostgreSQL and enter:
   ```
   postgresql://username:password@localhost:5432/cricketdb
   ```

3. **Start asking questions!**

> 📖 See [SETUP.md](SETUP.md) for detailed Blackbox CLI database setup guide.

---

## 💬 Common Questions to Try with Blackbox CLI

Once your database is connected, try these natural language queries:

### 🏏 Batting Analysis

```
> Who scored the most runs in IPL 2025?
```

```
> Show me Virat Kohli's performance in all matches
```

```
> Best strike rate in death overs (minimum 30 balls faced)
```

```
> Which batters hit the most sixes this season?
```

```
> Top 5 opening partnerships in IPL 2025
```

```
> How many centuries were scored this season and by whom?
```

```
> Average runs scored in powerplay by each team
```

```
> Who are the best finishers when chasing in the last 5 overs?
```

### 🎯 Bowling Analysis

```
> Who took the most wickets in IPL 2025?
```

```
> Best economy rate among bowlers with at least 10 overs bowled
```

```
> Which bowler has the best strike rate in powerplay?
```

```
> Most dot balls bowled by a spinner
```

```
> Best bowling figures in a single match
```

```
> Which bowlers are most expensive in death overs?
```

```
> Compare Jasprit Bumrah vs Arshdeep Singh this season
```

### 🏆 Match & Team Analysis

```
> Show me the IPL 2025 final scorecard
```

```
> Which team won the most matches this season?
```

```
> Head to head record between CSK and MI
```

```
> Does winning the toss help at Wankhede Stadium?
```

```
> Which team has the best powerplay batting average?
```

```
> List all super over matches this season
```

```
> Which team collapses most in middle overs?
```

### 📍 Venue Analysis

```
> What is the average first innings score at each venue?
```

```
> Which venue has the highest run rate?
```

```
> Best bowling venue in IPL 2025
```

```
> Toss advantage percentage at each ground
```

```
> How many matches were played at Narendra Modi Stadium?
```

### 🔍 Advanced Queries

```
> Show me batters who score faster against spin than pace
```

```
> Which players performed best under pressure (last 5 overs while chasing)?
```

```
> Compare team performance batting first vs chasing
```

```
> Find players who got out most to caught dismissals
```

```
> What's the average score in matches where toss winner chose to bat?
```

```
> Show run rate progression by over number across all matches
```

```
> Which bowler-batter matchup has the most dismissals?
```

### 📊 Statistical Deep Dives

```
> Calculate the impact of winning toss on match outcome
```

```
> Show boundary percentage by batting position
```

```
> Average runs per wicket for each team
```

```
> Most economical death over bowler with minimum 20 overs
```

```
> Player of the match winners and their performances
```

---

## 📜 License

Data sourced from [Cricsheet](https://cricsheet.org/) - Ball-by-ball cricket data under Open Database License.

---

**Built with Blackbox AI** 🚀
