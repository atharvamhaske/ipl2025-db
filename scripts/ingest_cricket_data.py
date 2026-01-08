#!/usr/bin/env python3
"""
IPL 2025 Cricket Data Ingestion Script
Ingests Cricsheet YAML files into PostgreSQL database.

Usage:
    python ingest_cricket_data.py --db-url "postgresql://user:pass@localhost:5432/cricketdb" --data-dir ./
    
Or with environment variable:
    export DATABASE_URL="postgresql://user:pass@localhost:5432/cricketdb"
    python ingest_cricket_data.py --data-dir ./
"""

import os
import sys
import glob
import argparse
import logging
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Any, Optional, Tuple

import yaml
import psycopg2
from psycopg2.extras import execute_batch

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_phase(over_number: int) -> str:
    """
    Determine T20 phase based on over number.
    Powerplay: Overs 0-5 (1-6 in cricket terms)
    Middle: Overs 6-14 (7-15 in cricket terms)
    Death: Overs 15-19 (16-20 in cricket terms)
    """
    if over_number <= 5:
        return 'powerplay'
    elif over_number <= 14:
        return 'middle'
    else:
        return 'death'


def parse_over_ball(over_ball_key: str) -> Tuple[int, int]:
    """
    Parse over.ball format (e.g., '16.3' -> (16, 3))
    Handles edge cases like '0.1', '19.6', etc.
    """
    parts = str(over_ball_key).split('.')
    over_num = int(parts[0])
    ball_num = int(parts[1]) if len(parts) > 1 else 1
    return over_num, ball_num


def safe_get(data: Dict, *keys, default=None):
    """Safely navigate nested dictionary."""
    result = data
    for key in keys:
        if isinstance(result, dict):
            result = result.get(key, default)
        else:
            return default
    return result if result is not None else default


def extract_match_data(yaml_data: Dict, source_file: str) -> Dict:
    """Extract match-level metadata from YAML."""
    info = yaml_data.get('info', {})
    
    # Handle dates (can be list or single date)
    dates = info.get('dates', [])
    match_date = dates[0] if dates else None
    
    # Extract season from date
    season = None
    if match_date:
        if isinstance(match_date, str):
            season = int(match_date.split('-')[0])
        elif hasattr(match_date, 'year'):
            season = match_date.year
    
    # Handle outcome
    outcome = info.get('outcome', {})
    winner = outcome.get('winner')
    win_by = outcome.get('by', {})
    win_by_runs = win_by.get('runs', 0) or 0
    win_by_wickets = win_by.get('wickets', 0) or 0
    
    # Determine result type
    result_type = 'normal'
    if 'result' in outcome:
        result_type = outcome['result']  # 'no result', 'tie', etc.
    elif not winner:
        result_type = 'no result'
    
    # Get teams
    teams = info.get('teams', [])
    team1 = teams[0] if len(teams) > 0 else None
    team2 = teams[1] if len(teams) > 1 else None
    
    # Player of match (can be list)
    pom = info.get('player_of_match', [])
    player_of_match = pom[0] if pom else None
    
    return {
        'source_file': source_file,
        'match_type': info.get('match_type', 'T20'),
        'competition': info.get('competition', 'IPL'),
        'season': season,
        'match_date': match_date,
        'venue': info.get('venue', 'Unknown'),
        'city': info.get('city'),
        'team1': team1,
        'team2': team2,
        'toss_winner': safe_get(info, 'toss', 'winner'),
        'toss_decision': safe_get(info, 'toss', 'decision'),
        'winner': winner,
        'win_by_runs': win_by_runs,
        'win_by_wickets': win_by_wickets,
        'result_type': result_type,
        'player_of_match': player_of_match
    }


def extract_players(yaml_data: Dict) -> List[Dict]:
    """Extract unique players from YAML."""
    info = yaml_data.get('info', {})
    players_data = info.get('players', {})
    
    players = []
    for team, player_list in players_data.items():
        for player_name in player_list:
            players.append({
                'player_name': player_name,
                'team': team
            })
    
    return players


def extract_innings_and_deliveries(yaml_data: Dict, match_id: int, teams: List[str]) -> Tuple[List[Dict], List[Dict]]:
    """Extract innings and ball-by-ball data from YAML."""
    innings_list = yaml_data.get('innings', [])
    
    innings_data = []
    deliveries_data = []
    
    for idx, innings_entry in enumerate(innings_list):
        # Get innings key (e.g., '1st innings', '2nd innings', 'super over')
        innings_key = list(innings_entry.keys())[0]
        innings_info = innings_entry[innings_key]
        
        innings_number = idx + 1
        batting_team = innings_info.get('team')
        
        # Determine bowling team
        bowling_team = None
        for team in teams:
            if team != batting_team:
                bowling_team = team
                break
        
        # Check if super over
        is_super_over = 'super' in innings_key.lower()
        
        # Process deliveries
        deliveries = innings_info.get('deliveries', [])
        
        total_runs = 0
        total_wickets = 0
        total_extras = 0
        last_over = 0
        last_ball = 0
        
        for delivery_entry in deliveries:
            # Each delivery is a dict with one key (over.ball)
            over_ball_key = list(delivery_entry.keys())[0]
            delivery = delivery_entry[over_ball_key]
            
            over_num, ball_num = parse_over_ball(over_ball_key)
            last_over = over_num
            last_ball = ball_num
            
            # Extract runs
            runs = delivery.get('runs', {})
            runs_batter = runs.get('batsman', 0) or runs.get('batter', 0) or 0
            runs_extras = runs.get('extras', 0) or 0
            runs_total = runs.get('total', 0) or 0
            
            total_runs += runs_total
            total_extras += runs_extras
            
            # Extract extras breakdown
            extras = delivery.get('extras', {})
            extras_wides = extras.get('wides', 0) or 0
            extras_noballs = extras.get('noballs', 0) or 0
            extras_byes = extras.get('byes', 0) or 0
            extras_legbyes = extras.get('legbyes', 0) or 0
            extras_penalty = extras.get('penalty', 0) or 0
            
            # Determine if legal delivery
            is_legal = extras_wides == 0 and extras_noballs == 0
            
            # Extract wicket info
            wicket = delivery.get('wicket') or delivery.get('wickets')
            is_wicket = False
            wicket_type = None
            player_dismissed = None
            fielder = None
            
            if wicket:
                # Handle both single wicket and list of wickets
                if isinstance(wicket, list):
                    wicket = wicket[0]  # Take first wicket
                
                is_wicket = True
                wicket_type = wicket.get('kind')
                player_dismissed = wicket.get('player_out')
                
                # Get fielder(s)
                fielders = wicket.get('fielders', [])
                if fielders:
                    if isinstance(fielders[0], dict):
                        fielder = fielders[0].get('name')
                    else:
                        fielder = fielders[0]
                
                total_wickets += 1
            
            # Compute derived fields
            is_four = runs_batter == 4
            is_six = runs_batter == 6
            is_boundary = is_four or is_six
            is_dot_ball = runs_total == 0 and is_legal
            
            # Get phase
            phase = get_phase(over_num)
            
            deliveries_data.append({
                'match_id': match_id,
                'innings_number': innings_number,
                'over_number': over_num,
                'ball_number': ball_num,
                'batting_team': batting_team,
                'bowling_team': bowling_team,
                'striker': delivery.get('batsman') or delivery.get('batter'),
                'non_striker': delivery.get('non_striker'),
                'bowler': delivery.get('bowler'),
                'runs_batter': runs_batter,
                'runs_extras': runs_extras,
                'runs_total': runs_total,
                'extras_wides': extras_wides,
                'extras_noballs': extras_noballs,
                'extras_byes': extras_byes,
                'extras_legbyes': extras_legbyes,
                'extras_penalty': extras_penalty,
                'is_wicket': is_wicket,
                'wicket_type': wicket_type,
                'player_dismissed': player_dismissed,
                'fielder': fielder,
                'is_boundary': is_boundary,
                'is_four': is_four,
                'is_six': is_six,
                'is_dot_ball': is_dot_ball,
                'is_legal_delivery': is_legal,
                'phase': phase
            })
        
        # Calculate total overs (e.g., 19.3)
        total_overs = float(f"{last_over}.{last_ball}")
        
        innings_data.append({
            'match_id': match_id,
            'innings_number': innings_number,
            'batting_team': batting_team,
            'bowling_team': bowling_team,
            'total_runs': total_runs,
            'total_wickets': total_wickets,
            'total_overs': total_overs,
            'total_extras': total_extras,
            'is_super_over': is_super_over
        })
    
    return innings_data, deliveries_data


def insert_match(cursor, match_data: Dict) -> Optional[int]:
    """Insert match and return match_id. Returns None if already exists."""
    # Check if already ingested
    cursor.execute(
        "SELECT match_id FROM matches WHERE source_file = %s",
        (match_data['source_file'],)
    )
    existing = cursor.fetchone()
    if existing:
        logger.info(f"  Skipping {match_data['source_file']} - already ingested")
        return None
    
    cursor.execute("""
        INSERT INTO matches (
            source_file, match_type, competition, season, match_date, venue, city,
            team1, team2, toss_winner, toss_decision, winner,
            win_by_runs, win_by_wickets, result_type, player_of_match
        ) VALUES (
            %(source_file)s, %(match_type)s, %(competition)s, %(season)s, %(match_date)s,
            %(venue)s, %(city)s, %(team1)s, %(team2)s, %(toss_winner)s, %(toss_decision)s,
            %(winner)s, %(win_by_runs)s, %(win_by_wickets)s, %(result_type)s, %(player_of_match)s
        ) RETURNING match_id
    """, match_data)
    
    return cursor.fetchone()[0]


def insert_players(cursor, players: List[Dict]):
    """Insert players (ignore duplicates)."""
    execute_batch(cursor, """
        INSERT INTO players (player_name, team)
        VALUES (%(player_name)s, %(team)s)
        ON CONFLICT (player_name, team) DO NOTHING
    """, players)


def insert_innings(cursor, innings_data: List[Dict]):
    """Insert innings data."""
    execute_batch(cursor, """
        INSERT INTO innings (
            match_id, innings_number, batting_team, bowling_team,
            total_runs, total_wickets, total_overs, total_extras, is_super_over
        ) VALUES (
            %(match_id)s, %(innings_number)s, %(batting_team)s, %(bowling_team)s,
            %(total_runs)s, %(total_wickets)s, %(total_overs)s, %(total_extras)s, %(is_super_over)s
        )
    """, innings_data)


def insert_deliveries(cursor, deliveries: List[Dict]):
    """Insert ball-by-ball data in batches."""
    execute_batch(cursor, """
        INSERT INTO ball_by_ball (
            match_id, innings_number, over_number, ball_number,
            batting_team, bowling_team, striker, non_striker, bowler,
            runs_batter, runs_extras, runs_total,
            extras_wides, extras_noballs, extras_byes, extras_legbyes, extras_penalty,
            is_wicket, wicket_type, player_dismissed, fielder,
            is_boundary, is_four, is_six, is_dot_ball, is_legal_delivery, phase
        ) VALUES (
            %(match_id)s, %(innings_number)s, %(over_number)s, %(ball_number)s,
            %(batting_team)s, %(bowling_team)s, %(striker)s, %(non_striker)s, %(bowler)s,
            %(runs_batter)s, %(runs_extras)s, %(runs_total)s,
            %(extras_wides)s, %(extras_noballs)s, %(extras_byes)s, %(extras_legbyes)s, %(extras_penalty)s,
            %(is_wicket)s, %(wicket_type)s, %(player_dismissed)s, %(fielder)s,
            %(is_boundary)s, %(is_four)s, %(is_six)s, %(is_dot_ball)s, %(is_legal_delivery)s, %(phase)s
        )
    """, deliveries, page_size=500)


def process_yaml_file(cursor, filepath: str) -> bool:
    """Process a single YAML file. Returns True if successfully ingested."""
    filename = os.path.basename(filepath)
    logger.info(f"Processing: {filename}")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            yaml_data = yaml.safe_load(f)
        
        if not yaml_data:
            logger.warning(f"  Empty YAML file: {filename}")
            return False
        
        # Extract match data
        match_data = extract_match_data(yaml_data, filename)
        
        # Insert match (returns None if already exists)
        match_id = insert_match(cursor, match_data)
        if match_id is None:
            return False  # Already ingested
        
        logger.info(f"  Inserted match_id: {match_id}")
        
        # Extract and insert players
        players = extract_players(yaml_data)
        insert_players(cursor, players)
        logger.info(f"  Processed {len(players)} players")
        
        # Get teams for bowling team determination
        teams = yaml_data.get('info', {}).get('teams', [])
        
        # Extract innings and deliveries
        innings_data, deliveries_data = extract_innings_and_deliveries(yaml_data, match_id, teams)
        
        # Insert innings
        insert_innings(cursor, innings_data)
        logger.info(f"  Inserted {len(innings_data)} innings")
        
        # Insert deliveries
        insert_deliveries(cursor, deliveries_data)
        logger.info(f"  Inserted {len(deliveries_data)} deliveries")
        
        return True
        
    except yaml.YAMLError as e:
        logger.error(f"  YAML parsing error in {filename}: {e}")
        return False
    except Exception as e:
        logger.error(f"  Error processing {filename}: {e}")
        raise


def main():
    parser = argparse.ArgumentParser(description='Ingest Cricsheet YAML files into PostgreSQL')
    parser.add_argument('--db-url', type=str, 
                        default=os.environ.get('DATABASE_URL'),
                        help='PostgreSQL connection URL')
    parser.add_argument('--data-dir', type=str, default='./',
                        help='Directory containing YAML files')
    parser.add_argument('--schema-file', type=str, default='schema.sql',
                        help='Path to schema SQL file')
    parser.add_argument('--init-schema', action='store_true',
                        help='Initialize database schema before ingestion')
    
    args = parser.parse_args()
    
    if not args.db_url:
        logger.error("Database URL required. Use --db-url or set DATABASE_URL environment variable")
        sys.exit(1)
    
    # Find YAML files
    yaml_pattern = os.path.join(args.data_dir, '*.yaml')
    yaml_files = sorted(glob.glob(yaml_pattern))
    
    if not yaml_files:
        logger.error(f"No YAML files found in {args.data_dir}")
        sys.exit(1)
    
    logger.info(f"Found {len(yaml_files)} YAML files to process")
    
    # Connect to database
    try:
        conn = psycopg2.connect(args.db_url)
        conn.autocommit = False
        cursor = conn.cursor()
        logger.info("Connected to PostgreSQL database")
        
        # Initialize schema if requested
        if args.init_schema:
            schema_path = os.path.join(args.data_dir, args.schema_file)
            if os.path.exists(schema_path):
                logger.info(f"Initializing schema from {schema_path}")
                with open(schema_path, 'r') as f:
                    cursor.execute(f.read())
                conn.commit()
                logger.info("Schema initialized successfully")
            else:
                logger.warning(f"Schema file not found: {schema_path}")
        
        # Process each YAML file
        success_count = 0
        skip_count = 0
        error_count = 0
        
        for filepath in yaml_files:
            try:
                result = process_yaml_file(cursor, filepath)
                if result:
                    success_count += 1
                    conn.commit()
                else:
                    skip_count += 1
            except Exception as e:
                error_count += 1
                conn.rollback()
                logger.error(f"Rolling back transaction for {filepath}")
        
        # Final summary
        logger.info("=" * 50)
        logger.info("INGESTION COMPLETE")
        logger.info(f"  Successfully ingested: {success_count}")
        logger.info(f"  Skipped (already exists): {skip_count}")
        logger.info(f"  Errors: {error_count}")
        logger.info("=" * 50)
        
        # Print summary stats
        cursor.execute("SELECT COUNT(*) FROM matches")
        match_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM innings")
        innings_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM ball_by_ball")
        ball_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM players")
        player_count = cursor.fetchone()[0]
        
        logger.info("DATABASE STATS:")
        logger.info(f"  Total matches: {match_count}")
        logger.info(f"  Total innings: {innings_count}")
        logger.info(f"  Total deliveries: {ball_count}")
        logger.info(f"  Total players: {player_count}")
        
    except psycopg2.Error as e:
        logger.error(f"Database error: {e}")
        sys.exit(1)
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
            logger.info("Database connection closed")


if __name__ == '__main__':
    main()
