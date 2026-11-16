from bs4 import BeautifulSoup
import requests

urls = ["https://www.vulture.com/", "https://www.nrj.fr/", "https://www.booska-p.com/", "https://www.nme.com/", "https://www.music-news.com/", "https://vt.co/"]
# url = ""
# page = requests.get(url)
# soup = BeautifulSoup(page.text, "html")


def vultureScrapper():

    response = requests.get(urls[0])

    # Check if the request was successful
    if response.status_code == 200:
        # Parse the HTML content of the page
        soup = BeautifulSoup(response.text, 'html.parser')

        # Find and extract specific elements (e.g., article titles)
        article_titles = soup.find_all('h2', class_='article-title')

        # Iterate through the titles and print them
        for title in article_titles:
            print(title.text)

        # Find and extract a specific link (e.g., the first link in the page)
        link = soup.find('a', href=True)

        # Check if a link was found
        if link:
            # Get the URL of the link
            link_url = link['href']

            # Send an HTTP GET request to the link URL
            link_response = requests.get(link_url)

            # Check if the request to the link was successful
            if link_response.status_code == 200:
                # Process the content of the linked page
                # ... Your scraping and processing code for the linked page goes here ...
                pass
            else:
                print(f"Failed to retrieve the linked page. Status code: {link_response.status_code}")

        else:
            print("No link found on the page.")

    else:
        print(f"Failed to retrieve the webpage. Status code: {response.status_code}")
