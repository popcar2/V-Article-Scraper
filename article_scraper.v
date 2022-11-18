import net.http { get, Response }
import strings
import os { write_file, input }

struct Article{
	title string
	subtitle string
	body string
}

fn main(){
	for {
		url := os.input("Input article URL (0 to exit): ")

		if url == '0'{
			return
		}

		println("Connecting...")

		resp := http.get(url) or { http.Response{} }

		match resp.status_code{
			200 {
				println("Connected!")
				article := start_scraping(resp)

				println("Writing to file...")
				mut file_name := article.title
				if file_name.len > 100{
					file_name = article.title[0..100]
				}
				file_name = remove_illegal_characters(file_name)
				write_file("./${file_name}.txt", "${article.title}\n${article.subtitle}\n\n${article.body}") or { println("Unable to write file :(") }

				println("All done! Written to ${file_name}.txt")
			}
			else {
				println("Failed to connect, status code ${resp.status_code}")
			}
		}
	}
}

// Scrapes title, subtitle, and article body and returns an Article
fn start_scraping(resp http.Response) Article{
	title := scrape_tag(resp.body, "h1")
	subtitle := scrape_tag(resp.body, "h2")
	body := scrape_paragraphs(resp.body, "section", 'class="article-page"')

	return Article{title, subtitle, body}
}

// Scrapes a specific HTML tag (like h1 and h2 for titles and subtitles respectively)
fn scrape_tag(body string, tag string) string{
	mut tag_start_index := body.index("<${tag}") or { return "COULDN'T FIND ${tag}" }
	tag_start_index = body.index_after(">", tag_start_index)
	tag_stop_index := body.index_after("</${tag}", tag_start_index + 1)

	return clean_string(body[tag_start_index + 1..tag_stop_index])
}

// Scrapes the body and separates each <p> paragraph text, ignoring everything inbetween
fn scrape_paragraphs(body string, tag string, identifier string) string{
	mut section_start_index := body.index("<${tag} ${identifier}") or { return "COULDN'T FIND BODY!" }
	section_start_index = body.index_after(">", section_start_index)

	// Basically skips every extra <section></section> inbetween the main <section>...</section> of the article's body
	mut section_start_iter := body.index_after("<${tag}", section_start_index)
	mut section_stop_index := body.index_after("</${tag}", section_start_index + 1)

	for section_start_iter != -1 && section_start_iter < section_stop_index{
		section_start_iter = body.index_after("<${tag}", section_start_iter + 1)
		section_stop_index = body.index_after("</${tag}", section_stop_index + 1)
	}

	article_body := body[section_start_index + 1..section_stop_index]

	mut str_builder := strings.new_builder(0)

	// Add contents of every <p>...</p> while still the article section
	mut paragraph_start_index := article_body.index("<p>") or { -1 }
	for paragraph_start_index != -1 && paragraph_start_index < section_stop_index{
		paragraph_end_index := article_body.index_after("</p>", paragraph_start_index)
		paragraph := article_body[paragraph_start_index + 3..paragraph_end_index]
		if paragraph != ''{
			str_builder.writeln(paragraph)
		}
		paragraph_start_index = article_body.index_after("<p>", paragraph_start_index + 3)
	}

	return clean_string(str_builder.str())
}

// Removes HTML/string shenanigans
fn clean_string(text string) string{
	return text.replace('&quot;', '"').replace('&#x27;', "'").replace('&amp;', '&')
}

fn remove_illegal_characters(text string) string{
	mut str_builder := strings.new_builder(0)

	// Only add legal ASCII charactes [0-9][A-Z][a-z]
	for c in text{
		if (c > 47 && c < 58) || (c > 64 && c < 91) || (c > 96 && c < 123){
			str_builder.write_u8(c)
		}
		else if c == 32{
			str_builder.write_u8(45)
		}
	}

	return str_builder.str()
}