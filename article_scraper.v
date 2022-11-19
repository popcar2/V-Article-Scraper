import scraper
import net.http { Response, get }
import strings { new_builder }
import os { input, write_file }

struct Article {
	title    string
	subtitle string
	body     string
}

fn main() {
	// What to look for in each website, it's a map[string]map[string]string
	db_values := scraper.parse_json_file()

	for {
		url := input('Input article URL (0 to exit): ')

		if url == '0' || url == '' {
			return
		}

		println('Connecting...')

		resp := get(url) or { Response{} }

		match resp.status_code {
			200 {
				println('Connected!')
				article := start_scraping(url, resp, db_values)

				println('Writing to file...')
				mut file_name := article.title
				if file_name.len > 100 {
					file_name = article.title[0..100]
				}
				file_name = remove_illegal_characters(file_name)
				write_file('./${file_name}.txt', '${article.title}\n${article.subtitle}\n\n${article.body}') or {
					println('Unable to write file :(')
				}

				println('All done! Written to ${file_name}.txt')
			}
			else {
				println('Failed to connect, status code ${resp.status_code}')
			}
		}
	}
}

// Scrapes title, subtitle, and article body and returns an Article
fn start_scraping(url string, resp Response, db_values map[string]map[string]string) Article {
	scrape_vals := scraper.parse_url(url, db_values)

	title := scrape_tag(resp.body, scrape_vals['title_tag'], scrape_vals['title_identifier'])
	subtitle := scrape_tag(resp.body, scrape_vals['subtitle_tag'], scrape_vals['subtitle_identifier'])
	body := scrape_paragraphs(resp.body, scrape_vals['body_tag'], scrape_vals['body_identifier'])

	return Article{title, subtitle, body}
}

// Scrapes a specific HTML tag (like h1 and h2 for titles and subtitles respectively)
fn scrape_tag(body string, tag string, identifier string) string {
	if tag == ''{
		return "EMPTY: No tag supplied"
	}

	mut tag_start_index := body.index('<${tag}${identifier}') or { return "COULDN'T FIND ${tag}" }
	tag_start_index = body.index_after('>', tag_start_index)
	tag_stop_index := body.index_after('</${tag}', tag_start_index + 1)

	return clean_string(body[tag_start_index + 1..tag_stop_index])
}

// fn scrape_every_tag(body string, tag string) string[]{

//}

// Scrapes the body and separates each <p> paragraph text, ignoring everything inbetween
fn scrape_paragraphs(body string, tag string, identifier string) string {
	write_file('./test.txt', body) or { panic('AHHH') }

	mut section_start_index := body.index('<${tag} ${identifier}') or {
		return "COULDN'T FIND BODY!"
	}
	section_start_index = body.index_after('>', section_start_index)

	// Basically skips every extra <section></section> inbetween the main <section>...</section> of the article's body
	mut section_start_iter := body.index_after('<${tag}', section_start_index)
	mut section_stop_index := body.index_after('</${tag}', section_start_index + 1)

	for section_start_iter != -1 && section_start_iter < section_stop_index {
		section_start_iter = body.index_after('<${tag}', section_start_iter + 1)
		section_stop_index = body.index_after('</${tag}', section_stop_index + 1)
	}

	if section_start_index == -1 || section_stop_index == -1 {
		println("ERROR: Couldn't find article body start/stop")
		return "ERROR: Couldn't find article body start/stop"
	}

	article_body := body[section_start_index + 1..section_stop_index]

	mut str_builder := new_builder(0)

	// Add contents of every <p>...</p> while still the article section
	mut paragraph_start_index := article_body.index('<p') or { -1 }

	if paragraph_start_index == -1 {
		println("ERROR: Couldn't find article body start/stop")
		return "ERROR: Couldn't find article body start/stop"
	}

	for paragraph_start_index != -1 {
		paragraph_start_index = article_body.index_after('>', paragraph_start_index + 1)
		paragraph_end_index := article_body.index_after('</p>', paragraph_start_index)

		paragraph := article_body[paragraph_start_index + 1..paragraph_end_index]
		if paragraph != '' {
			str_builder.writeln(clean_string('${paragraph}\n'))
		}

		paragraph_start_index = article_body.index_after('<p', paragraph_start_index + 1)
	}

	return str_builder.str().trim('\n')
}

// Removes HTML/string shenanigans
fn clean_string(text string) string {
	return text.replace('&quot;', '"').replace('&#34;', "'").replace('&#x27;', "'").replace('&rsquo;',"'")
		.replace('&amp;', '&').replace('&nbsp;', ' ').replace('&mdash;', '—').replace('&ldquo;','“')
		.replace('&rdquo;', '”').trim(' ')
}

fn remove_illegal_characters(text string) string {
	mut str_builder := new_builder(0)

	// Only add legal ASCII charactes [0-9][A-Z][a-z]
	for c in text {
		if (c > 47 && c < 58) || (c > 64 && c < 91) || (c > 96 && c < 123) {
			str_builder.write_u8(c)
		} else if c == 32 {
			str_builder.write_u8(45)
		}
	}

	return str_builder.str().trim(' ')
}
