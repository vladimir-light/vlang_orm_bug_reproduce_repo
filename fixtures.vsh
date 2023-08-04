// actualy the same as fixtures.v but as VSH script...just to test if it's a VSH specific BUG
import os
import time
import rand
import db.sqlite

const (
	db_name      = 'storage.sqlite'
	db_file_path = os.join_path(@VMODROOT, db_name)
)

[table: 'teams']
pub struct Team {
	id         int       [primary; sql: serial]
	name       string    [nonull; required]
	created_at time.Time [default: 'CURRENT_TIMESTAMP'; sql_type: 'DATETIME']
	updated_at time.Time [default: 'CURRENT_TIMESTAMP'; sql_type: 'DATETIME']
}

[table: 'predictions']
pub struct Prediction {
	id         int       [primary; sql: serial]
	home_team  Team      [fkey: 'id'; nonull; sql_type: 'INTEGER'; unique: 'teams']
	away_team  Team      [fkey: 'id'; nonull; sql_type: 'INTEGER'; unique: 'teams']
	home_goals u8        [default: '0'; nonull; sql_type: 'INTEGER']
	away_goals u8        [default: '0'; nonull; sql_type: 'INTEGER']
	created_at time.Time [default: 'CURRENT_TIMESTAMP'; sql_type: 'DATETIME']
	updated_at time.Time [default: 'CURRENT_TIMESTAMP'; sql_type: 'DATETIME']
}

fn init_teams(db sqlite.DB) ! {
	sql db {
		create table Team
	}!

	found_teams := sql db {
		select count from Team
	}!

	if found_teams > 0 {
		// sql db { delete from Team where id > 0}! // feels kinda hacky. just `delete from Team` doesn't work
		db.exec_none('DELETE FROM `teams`')
	}

	// FC team-name
	new_teams := [
		'Arsenal',
		'Chelsea',
		'Liverpool',
		'Manchester City',
		'Manchester United',
		'Tottenham Hotspur',
		'Real Madrid',
		'Barcelona',
		'Juventus',
		'Inter Milan',
		'Beyern Munich',
		'Ajax',
		'PSG',
		'Porto',
	]

	for _, team_name in new_teams {
		team := Team{
			name: team_name
		}
		sql db {
			insert team into Team
		}!
	}
}

fn init_predictions_simplified(db sqlite.DB) ! {
	// Simplified version of init_predictions
	// We create only one prediction with specific team-ids, no loop over teams
	sql db {
		create table Prediction
	}!

	// if there's no teams -> abbort!
	found_teams := db.q_int('SELECT COUNT(*) FROM `teams`')
	if found_teams < 2 {
		return error('not enough teams')
	}

	// always remove all exsiting predictions, no need ti check if there are any..
	db.exec_none('DELETE FROM `predictions`') // unfortunately there's no way to run this with sql db { delete from ... }

	// first Team
	home_team := sql db {
		select from Team where id == 2
	}!

	// second Team
	away_team := sql db {
		select from Team where id == 7
	}!

	// dump(home_team.first())
	// dump(away_team.first())

	// new Prediction with two Teams from obove and a random number for goals
	new_pred := Prediction{
		home_team: home_team.first()
		away_team: away_team.first()
		home_goals: rand.u8()
		away_goals: rand.u8()
	}

	// expected query here is `insert into "predictions" (id, home_team_id, away_team_id, home_goals, away_goals, created_at, updated_at) VALUES ( ... )`
	// but instead an `insert into "teams"` triggered...
	sql db {
		insert new_pred into Prediction
	}!
}

mut db := sqlite.connect(db_file_path)!

// works
init_teams(db) or { panic(err) }

// works
// init_predictions_no_orm(db) or { panic(err) }
// fails
init_predictions_simplified(db) or { panic(err) }
