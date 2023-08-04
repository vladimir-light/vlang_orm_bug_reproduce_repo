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
	// We create only one Prediction with specific team-ids, no loop over teams
	sql db {
		create table Prediction
	}!

	// If there are no teams → abort!
	found_teams := db.q_int('SELECT COUNT(*) FROM `teams`')
	if found_teams < 2 {
		return error('not enough teams')
	}

	// Always remove all existing predictions, no need to check if there are any.
	db.exec_none('DELETE FROM `predictions`') // unfortunately there's no way to run this with `sql db { delete from Prediction }`

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


fn init_predictions_no_orm(db sqlite.DB) ! {
	// still the quickest way to create table if not exists even though this function should NOT use any ORM calls
	sql db {
		create table Prediction
	}!


	//1) check if there enough teams
	//2) check if there any existing predictions. if so, remove
	//3) create predictions with random teams

	//1)
	found_teams :=db.q_int("SELECT COUNT(*) FROM `teams`")
	if found_teams < 2
	{
		panic('Not enought teams...')
	}

	// 2) just delete everytime.
	db.exec_none('DELETE FROM `predictions`')

	//3) create
	// 3.1 - get list of all odd teams (randomly ordered)
	// 3.2 - get list of all even teams (randomly ordered)
	// 3.3 - create prediction with a odd and even teams-id


	// 3.1 and 3.2
	mut even_teams_ids, _ := db.exec('SELECT id FROM `teams` WHERE (id&1)=0 ORDER BY RANDOM()')
	mut odd_teams_ids, _ := db.exec('SELECT id FROM `teams` WHERE (id&1)<>0 ORDER BY RANDOM()')
	//
	for {
		if even_teams_ids.len < 1 || odd_teams_ids.len < 1 {
			// exit loop if there's no teams to process
			break
		}

		even_team := even_teams_ids.pop()
		home_team_id := even_team.vals[0].int()
		odd_team := odd_teams_ids.pop()
		away_team_id := odd_team.vals[0].int()

		// Quick and dirty...but also risky. No escaping, no param/value binding... feels wrong!
		_ := db.exec_none("INSERT INTO `predictions` (`home_team_id`, `away_team_id`, `home_goals`, `away_goals`) VALUES(${home_team_id}, ${away_team_id}, ${rand.u8()}, ${rand.u8()})")
	}
}

fn main() {
	mut db := sqlite.connect(db_file_path)!

	// INFO: In order to repdoruce potential bug in ORM
	// 1) comment out all init_* functions but not init_teams().
	// 2) run it ( v -d trace_orm run fixtures.v ) `teams` table will be created and populated with data
	// 3) comment out all init_* functions but not init_predictions_no_orm()
	// 4) run it again. `predictions` table will be created and populated with data
	// 5) now, comment everything but not init_predictions_simplified() and run it -> script panics with "V panic: db.sqlite.SQLError: UNIQUE constraint failed:" while trying to insert into `teams` instead of inserting into `predictions` table
	init_teams(db) or { panic(err) } // works
	// init_predictions_no_orm(db) or { panic(err) } // works
	// init_predictions_simplified(db) or { panic(err) } // fails
}
