# 🏏 IPL 2025 Cricket Database

A fully normalized PostgreSQL database for IPL 2025 cricket data, optimized for natural language querying via **[Blackbox](https://blackbox.ai) DB Chat**.

---

**Created by Atharva Mhaske with pair programmer [@blackboxai](https://blackbox.ai)** 🤖

---

## 🎬 Demo

### Ask a question in natural language:
![Demo Query](public/img/demo-query.png)

### Get instant answers from your database:
![Demo Response](public/img/demo-response.png)

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

## 💬 Questions to Try with [Blackbox](https://blackbox.ai) CLI

### 🏏 Batting
```
> Who scored the most runs in IPL 2025?
> How many runs did Virat Kohli score in the final?
> Best strike rate in death overs
> Who hit the most sixes this season? 💥
> Top 5 highest individual scores
> Which opener has the best average?
```

### 🎯 Bowling
```
> Who took the most wickets in IPL 2025?
> Best economy rate in death overs
> Compare Bumrah vs Arshdeep Singh
> Which spinner took the most wickets?
> Best bowling figures in a single match
```

### 🏆 Match & Team
```
> Show me the IPL 2025 final scorecard
> Which team won the most matches?
> Head to head: RCB vs CSK
> Does winning toss help at Wankhede?
> List all super over matches
```

### 🦆 Fun & Quirky Questions
```
> How many ducks were scored this season? 🦆
> Who got out for a duck the most times?
> Total sixes hit in IPL 2025? 💥
> Which match had the most sixes?
> Who hit the most sixes in a single innings?
> How many golden ducks (out on first ball)?
> Which bowler gave the most sixes?
> Funniest stat: most runs scored only in boundaries
> Who faced the most dot balls?
> Which team hit the most sixes in powerplay?
```

### 🔥 Spicy Comparisons
```
> Kohli vs Rohit: Who performed better?
> MI vs CSK: All time rivalry stats
> Best death over specialist?
> Who chokes most under pressure? 😬
> Most expensive over bowled this season?
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
