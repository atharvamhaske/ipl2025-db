# 🏏 IPL 2025 Cricket Database

A fully normalized PostgreSQL database for IPL 2025 cricket data, optimized for natural language querying via **[Blackbox](https://blackbox.ai) DB Chat**.

---

**Created by Atharva Mhaske with pair programmer [@blackboxai](https://blackbox.ai)** 🤖

---

## 📁 Project Structure

```
ipl-db/
├── README.md                    # This file
├── SETUP.md                     # Blackbox CLI setup guide
├── data/                        # Raw YAML match files (74 matches)
├── scripts/                     # Python & Shell scripts
│   ├── ingest_cricket_data.py   # Main ingestion script
│   └── setup_postgres.sh        # PostgreSQL setup helper
└── sql/                         # SQL files
    ├── schema.sql               # Database schema
    └── verify.sql               # Verification queries
```

## 📊 Database Overview

| Table | Description | Rows |
|-------|-------------|------|
| `matches` | Match metadata (teams, venue, toss, result) | 74 |
| `innings` | Innings summary (runs, wickets, overs) | 148 |
| `ball_by_ball` | Every delivery with full context | 17,285 |
| `players` | Unique players with team associations | 202 |

## 🚀 Quick Start

```bash
# 1. Install dependencies
pip install pyyaml psycopg2-binary

# 2. Create database
psql -U postgres -c "CREATE DATABASE cricketdb;"

# 3. Initialize schema & ingest data
psql -U postgres -d cricketdb -f sql/schema.sql
python scripts/ingest_cricket_data.py --db-url "postgresql://postgres:password@localhost:5432/cricketdb" --data-dir ./data/
```

## 🤖 [Blackbox](https://blackbox.ai) DB Chat Integration

```bash
# 1. Start Blackbox CLI
blackbox

# 2. Configure database
/db configure
# Select PostgreSQL → Enter: postgresql://user:pass@localhost:5432/cricketdb

# 3. Start asking questions!
```

> 📖 See [SETUP.md](SETUP.md) for detailed setup guide.

---

## 💬 Common Questions to Try

### 🏏 Batting
```
> Who scored the most runs in IPL 2025?
> Show me Virat Kohli's performance in all matches
> Best strike rate in death overs (minimum 30 balls faced)
> Which batters hit the most sixes this season?
> Who are the best finishers when chasing?
```

### 🎯 Bowling
```
> Who took the most wickets in IPL 2025?
> Best economy rate among bowlers with at least 10 overs bowled
> Most dot balls bowled by a spinner
> Compare Jasprit Bumrah vs Arshdeep Singh this season
```

### 🏆 Match & Team Analysis
```
> Show me the IPL 2025 final scorecard
> Which team won the most matches this season?
> Head to head record between CSK and MI
> Does winning the toss help at Wankhede Stadium?
```

### 📍 Venue Analysis
```
> What is the average first innings score at each venue?
> Which venue has the highest run rate?
> Toss advantage percentage at each ground
```

### 🔍 Advanced Queries
```
> Which players performed best under pressure (last 5 overs while chasing)?
> Compare team performance batting first vs chasing
> Which bowler-batter matchup has the most dismissals?
> Calculate the impact of winning toss on match outcome
```

---

## 📈 IPL 2025 Stats

| Metric | Value |
|--------|-------|
| Total Matches | 74 |
| Total Deliveries | 17,285 |
| Unique Players | 202 |
| Season | March 22 - June 3, 2025 |

### Top Run Scorers
| Batter | Runs | SR |
|--------|------|-----|
| B Sai Sudharsan | 759 | 156.17 |
| SA Yadav | 717 | 167.92 |
| V Kohli | 657 | 144.71 |

### Top Wicket Takers
| Bowler | Wickets | Economy |
|--------|---------|---------|
| M Prasidh Krishna | 26 | 8.58 |
| Noor Ahmad | 24 | 8.32 |
| TA Boult | 23 | 9.02 |

---

## 📜 License

Data sourced from [Cricsheet](https://cricsheet.org/) - Ball-by-ball cricket data under Open Database License.

---

**Built with [Blackbox AI](https://blackbox.ai)** 🚀
