from datetime import datetime, timedelta
from bs4 import BeautifulSoup
import requests
from ..models import Scrapper


def main_scrapper(url, article_list_tag, article_list_class, link_tag, link_class, title_tag, title_class, intro_tag, intro_class, content_tag, content_class, image_attribute, website, language):
    response = requests.get(url)
    grab_time = datetime.utcnow() - timedelta(minutes=10)
    if response.status_code == 200:
        # Parse the HTML content of the page
        soup = BeautifulSoup(response.text, 'html.parser')
        # Find and extract specific elements (e.g., article titles)
        articles = soup.find_all(article_list_tag, class_=article_list_class)
        for article_list in articles:
            if (article_list_tag == "ul"):
                individual_articles = article_list.find_all('li')
                for article in individual_articles:
                    image = article.find('img')
                    link = article.find(link_tag, class_=link_class)
                    title = article.find(
                        title_tag, class_=title_class)
                    intro = article.find(
                        intro_tag, class_=intro_class) if intro_tag and intro_class else ""
                    content = " "
                    formatted_link = ""
                    if link and not link["href"].startswith("https"):
                        formatted_link = "https:{}".format(link['href'])
                    else:
                        formatted_link = link["href"]
                    article_link_get = requests.get(
                        formatted_link)  # get the article link
                    article_soup = BeautifulSoup(
                        article_link_get.text, 'html.parser')
                    content_generated = article_soup.find(
                        content_tag, class_=content_class)
                    content = content_generated

                    try:

                        Scrapper.objects.get_or_create(title=title.text, date=grab_time, intro=intro.text,
                                                       content=content.text, image=image[image_attribute], website=website, link=link["href"], language=language)
                    except Exception as e:
                        print("Exception: {}".format(e))
            else:
                for article in article_list:
                    image = article.find('img')
                    link = ""
                    if link_tag:
                        link = article.find("a")
                    if link == -1:
                        continue
                    title = article.find(title_tag)
                    intro = ""
                    if (intro_tag != ""):

                        intro_soup = article.find(
                            "a", class_=intro_class)
                        intro = intro_soup.text
                    content = " "
                    formatted_link = ""
                    if link["href"] and not link["href"].startswith("https"):
                        formatted_link = "https:{}".format(link['href'])
                    else:
                        formatted_link = link["href"]
                    article_link_get = requests.get(
                        formatted_link)  # get the article link
                    article_soup = BeautifulSoup(
                        article_link_get.text, 'html.parser')
                    content_generated = article_soup.find(
                        content_tag, class_=content_class)
                    content = content_generated
                    try:

                        Scrapper.objects.get_or_create(title=title.text, date=grab_time, intro=intro,
                                                       content=content.text, image=image[image_attribute], website=website, link=link["href"], language=language)
                    except Exception as e:
                        print("Exception: {}".format(e))
