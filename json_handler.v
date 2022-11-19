module scraper

import json
import os { read_file }

// Extract data from json database and return the map
pub fn parse_json_file() map[string]map[string]string {
	println('Reading JSON file...')
	file := read_file('./db.json') or { '' }

	if file == '' {
		// TODO: Proper error handling here :P
		panic("ERROR: Couldn't read json file. Did you delete it?")
	}

	db_values := json.decode(map[string]map[string]string, file) or {
		map[string]map[string]string{}
	}

	return db_values
}

// Finds the domain name and checks it with the database, then returns its map with what to scrape.
pub fn parse_url(url string, db_values map[string]map[string]string) map[string]string {
	mut start_domain_index := 0
	mut end_domain_index := 0

	if url.contains('www.') {
		start_domain_index = url.index('www.') or { panic('parse_url weirdness #1') } + 4
	} else if url.contains('https://') {
		start_domain_index = 8
	} else if url.contains('http://') {
		start_domain_index = 7
	}

	end_domain_index = url.index_after('.', start_domain_index + 1)

	domain_name := url[start_domain_index..end_domain_index]

	for db_domain, scrape_vals in db_values {
		if domain_name == db_domain {
			return scrape_vals
		}
	}

	println("Couldn't find domain name in database (${domain_name})")
	return map[string]string{}
}
