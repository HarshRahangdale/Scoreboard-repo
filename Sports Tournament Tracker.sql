CREATE DATABASE IF NOT EXISTS Tournaments;
USE Tournaments;

CREATE TABLE teams(
	team_id INT AUTO_INCREMENT PRIMARY KEY,
    team_name VARCHAR(50) NOT NULL UNIQUE,
    city VARCHAR(50) NOT NULL
);

CREATE TABLE players(
	player_id INT AUTO_INCREMENT PRIMARY KEY,
    team_id INT NOT NULL,
    player_name VARCHAR(100) NOT NULL,
    position_ VARCHAR(30) NOT NULL,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE
);

CREATE TABLE matches(
	match_id INT AUTO_INCREMENT PRIMARY KEY,
    match_date DATE NOT NULL,
    home_team_id INT NOT NULL,
    away_team_id INT NOT NULL,
    home_score INT DEFAULT 0 ,
    away_score INT DEFAULT 0,
    STATUS ENUM ('Scheduled' , 'Completed' , 'Cancelled') DEFAULT 'Scheduled',
	FOREIGN KEY (home_team_id) REFERENCES teams(team_id),
    FOREIGN KEY (away_team_id) REFERENCES teams(team_id),
    CHECK (home_team_id <> away_team_id)
);


CREATE TABLE match_status (
	stat_id INT AUTO_INCREMENT PRIMARY KEY,
    match_id INT NOT NULL,
    player_id INT NOT NULL,
    minutes_played INT DEFAULT 0,
    points INT DEFAULT 0,
    assists INT DEFAULT 0 ,
    rebounds INT DEFAULT 0,
    FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES players(player_id) ON DELETE CASCADE,
    UNIQUE KEY uq_player_match (match_id , player_id)
);

INSERT INTO teams (team_name, city) VALUES
('Mumbai Indian', 'Mumbai'),
('Warriors', 'Pune'),
('Strikers', 'Nagpur'),
('Royal Challangers Banglore', 'Banglore');

INSERT INTO players (team_id, player_name, position_) VALUES
(1, 'Aarav Sharma', 'Guard'),
(1, 'Rohan Verma', 'Forward'),
(2, 'Vikram Patel', 'Center'),
(2, 'Aditya Rao', 'Guard'),
(3, 'Kabir Singh', 'Forward'),
(3, 'Devendra Joshi', 'Guard'),
(4, 'Siddharth Roy', 'Center'),
(4, 'Manish Kulkarni', 'Forward');

INSERT INTO matches (match_date, home_team_id, away_team_id, home_score, away_score, status) VALUES
('2026-09-01', 1, 2, 85, 80, 'Completed'),
('2026-09-03', 3, 4, 72, 79, 'Completed'),
('2026-09-05', 1, 3, 90, 88, 'Completed'),
('2026-09-07', 2, 4, 84, 84, 'Completed');

INSERT INTO match_status (match_id, player_id, minutes_played, points, assists, rebounds) VALUES
-- Match 1 (Titans vs Warriors)
(1, 1, 32, 28, 7, 4),
(1, 2, 28, 20, 3, 8),
(1, 3, 35, 24, 2, 11),
(1, 4, 30, 18, 6, 3),
-- Match 2 (Strikers vs Panthers)
(2, 5, 34, 22, 4, 6),
(2, 6, 26, 15, 5, 2),
(2, 7, 33, 27, 3, 12),
(2, 8, 31, 19, 5, 5),
-- Match 3 (Titans vs Strikers)
(3, 1, 36, 34, 8, 5),
(3, 2, 25, 14, 2, 6),
(3, 5, 33, 29, 3, 7),
(3, 6, 28, 21, 6, 1),
-- Match 4 (Warriors vs Panthers)
(4, 3, 38, 30, 1, 14),
(4, 4, 32, 16, 8, 4),
(4, 7, 35, 22, 4, 10),
(4, 8, 29, 21, 3, 6);

SELECT * FROM teams;
SELECT * FROM players;
SELECT * FROM matches;
SELECT * FROM match_status;

-- Write queries for match results, player scores
SELECT 
	m.match_id , 
    m.match_date , 
    ht.team_name AS home_team ,
    CONCAT (m.home_score , '-' , m.away_score) AS score,
    ats.team_name AS away_team,
    CASE
		WHEN m.home_score > m.away_score THEN ht.team_name
        WHEN m.away_score > m.home_score THEN ats.team_name
        ELSE 'DRAW'
	END AS Winner
FROM matches m 
JOIN teams ht ON m.home_team_id = ht.team_id
JOIN teams ats ON m.away_team_id = ats.team_id
WHERE m.status = 'Completed';

-- Individual players Scores

SELECT 
	p.player_name , 
    t.team_name ,
    m.match_id,
    s.points,
    s.assists,
    s.rebounds,
    s.minutes_played
FROM match_status s
JOIN players p ON s.player_id = p.player_id
JOIN teams t ON p.team_id = t.team_id
JOIN matches m ON s.match_id = m.match_id
ORDER BY s.points DESC;

-- Create views for leaderboards and points tables.

CREATE OR REPLACE VIEW view_points_table AS
WITH match_results AS (
    -- Home team 
    SELECT 
        home_team_id AS team_id,
        CASE 
            WHEN home_score > away_score THEN 1 ELSE 0 
        END AS won,
        CASE 
            WHEN home_score = away_score THEN 1 ELSE 0 
        END AS drawn,
        CASE 
            WHEN home_score < away_score THEN 1 ELSE 0 
        END AS lost,
        home_score AS points_for,
        away_score AS points_against
    FROM matches WHERE status = 'Completed'
    
    UNION ALL
    
    -- Away team 
    SELECT 
        away_team_id AS team_id,
        CASE 
            WHEN away_score > home_score THEN 1 ELSE 0 
        END AS won,
        CASE 
            WHEN away_score = home_score THEN 1 ELSE 0 
        END AS drawn,
        CASE 
            WHEN away_score < home_score THEN 1 ELSE 0 
        END AS lost,
        away_score AS points_for,
        home_score AS points_against
    FROM matches WHERE status = 'Completed'
)
SELECT 
    t.team_name,
    COUNT(mr.team_id) AS matches_played,
    SUM(mr.won) AS wins,
    SUM(mr.drawn) AS draws,
    SUM(mr.lost) AS losses,
    SUM(mr.points_for) AS total_scored,
    SUM(mr.points_against) AS total_conceded,
    (SUM(mr.points_for) - SUM(mr.points_against)) AS score_difference,
    SUM(mr.won * 2 + mr.drawn * 1) AS tournament_points
FROM teams t
LEFT JOIN match_results mr ON t.team_id = mr.team_id
GROUP BY t.team_id, t.team_name
ORDER BY tournament_points DESC, score_difference DESC;

SELECT * FROM view_points_table;

CREATE OR REPLACE VIEW view_player_leaderboard AS
SELECT 
    DENSE_RANK() OVER (ORDER BY COALESCE(SUM(s.points), 0) DESC) AS rank_points,
    p.player_id,
    p.player_name,
    p.position_,
    t.team_name,
    COUNT(s.match_id) AS games_played,
    COALESCE(SUM(s.points), 0) AS total_points,
    ROUND(COALESCE(AVG(s.points), 0), 1) AS ppg,
    COALESCE(SUM(s.assists), 0) AS total_assists,
    ROUND(COALESCE(AVG(s.assists), 0), 1) AS apg,
    COALESCE(SUM(s.rebounds), 0) AS total_rebounds,
    ROUND(COALESCE(AVG(s.rebounds), 0), 1) AS rpg,
    COALESCE(SUM(s.minutes_played), 0) AS total_minutes
FROM players p
JOIN teams t ON p.team_id = t.team_id
LEFT JOIN match_status s ON p.player_id = s.player_id
GROUP BY 
    p.player_id, 
    p.player_name, 
    p.position_, 
    t.team_name;

SELECT * FROM view_player_leaderboard;

-- TOP 5 SCORERS

SELECT rank_points, player_name, team_name, games_played, total_points, ppg 
FROM view_player_leaderboard 
ORDER BY rank_points ASC 
LIMIT 5;

-- Use CTE for average player performance.
WITH tournament_averages AS (
    SELECT 
        AVG(points) AS avg_tournament_points,
        AVG(assists) AS avg_tournament_assists,
        AVG(rebounds) AS avg_tournament_rebounds
    FROM match_status
),
player_averages AS (
    SELECT 
        p.player_name,
        t.team_name,
        COUNT(s.match_id) AS appearances,
        ROUND(AVG(s.points), 2) AS player_avg_points,
        ROUND(AVG(s.assists), 2) AS player_avg_assists,
        ROUND(AVG(s.rebounds), 2) AS player_avg_rebounds
    FROM players p
    JOIN teams t ON p.team_id = t.team_id
    JOIN match_status s ON p.player_id = s.player_id
    GROUP BY p.player_id, p.player_name, t.team_name
)
SELECT 
    pa.player_name,
    pa.team_name,
    pa.appearances,
    pa.player_avg_points,
    ROUND(ta.avg_tournament_points, 2) AS benchmark_avg_points,
    ROUND(pa.player_avg_points - ta.avg_tournament_points, 2) AS point_diff_from_avg,
    CASE 
        WHEN pa.player_avg_points > ta.avg_tournament_points THEN 'Above Average'
        ELSE 'Below Average'
    END AS scoring_tier
FROM player_averages pa
CROSS JOIN tournament_averages ta
ORDER BY pa.player_avg_points DESC;

-- Export team performance reports.

SELECT 
    t.team_name,
    pt.matches_played,
    pt.wins,
    pt.losses,
    pt.draws,
    pt.tournament_points,
    pt.score_difference,
    ROUND(AVG(s.points), 1) AS avg_points_per_player_game,
    SUM(s.assists) AS total_team_assists,
    SUM(s.rebounds) AS total_team_rebounds
FROM teams t
JOIN view_points_table pt ON t.team_name = pt.team_name
LEFT JOIN players p ON t.team_id = p.team_id
LEFT JOIN match_status s ON p.player_id = s.player_id
GROUP BY 
    t.team_id, 
    t.team_name, 
    pt.matches_played, 
    pt.wins, 
    pt.losses, 
    pt.draws, 
    pt.tournament_points, 
    pt.score_difference
ORDER BY pt.tournament_points DESC;
-- INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/team_performance_report.csv';

SHOW VARIABLES LIKE 'secure_file_priv';
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/team_performance_report.csv'