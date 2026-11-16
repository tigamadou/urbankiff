// 'use cache';
import { Col, Row, Flex } from 'antd';
import Link from 'next/link';
import React from 'react';

import { AdComponent } from '../components/AdComponent';
import Container from '../components/Container';
// import Pagination from '../components/Pagination';
import PostCard from '../components/PostCard';


export const metadata = {
  title: 'Urbankiff - Actualités Musique, Cinéma et Vidéos | Culture Urbaine',
  description: 'Découvrez les dernières actualités musique, cinéma et vidéos sur Urbankiff. Restez informé de la culture urbaine avec nos articles exclusifs, interviews et contenus multimédias.',
  openGraph: {
    title: 'Urbankiff - Actualités Musique, Cinéma et Vidéos | Culture Urbaine',
    description: 'Découvrez les dernières actualités musique, cinéma et vidéos sur Urbankiff. Restez informé de la culture urbaine avec nos articles exclusifs, interviews et contenus multimédias.',
  },
};

// Enable ISR - page will be statically generated and revalidated every 5 minutes
export const revalidate = 300; // 5 minutes in seconds

const HomePage = async () => {
  // Helper function to safely fetch and parse JSON
  const safeFetch = async (url: string, fallback: unknown[] = []) => {
    try {
      const response = await fetch(url, {
        next: { revalidate: 300, tags: ['posts'] },
      });

      if (!response.ok) {
        console.warn(`API call failed for ${url}: ${response.status} ${response.statusText}`);
        return fallback;
      }

      const text = await response.text();
      if (!text.trim()) {
        console.warn(`Empty response from ${url}`);
        return fallback;
      }

      return JSON.parse(text);
    } catch (error) {
      console.error(`Error fetching from ${url}:`, error);
      return fallback;
    }
  };

  // Fetch with Next.js caching and error handling
  const musiquesPosts = await safeFetch(
    `${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchcategorypostdata?name=musiques&last_post=0&language=fr`,
  );

  const ciposts2 = await safeFetch(
    `${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchcategorypostdata?name=cinema&last_post=0&language=fr`,
  );

  const viposts2 = await safeFetch(
    `${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchcategorypostdata?name=videos&last_post=0&language=fr`,
  );

  const tops2 = await safeFetch(
    `${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchmostview/fr/lol`,
  );

  return (
    <>
      <AdComponent space_uuid="campaign_main" />
      <div style={{ paddingBottom: 16}}>
        <Container>
          <Flex justify='flex-start' gap={16} align='center' style={{marginBottom:  16}}>
            <Link className="page-title" href="/fr/musiques">
              <span>Musiques</span>
            </Link>
          </Flex>

          <Row gutter={[32, 32]}>
            {musiquesPosts.slice(0, 4).map((item: unknown, index: number) => (
              <Col key={index} md={8} lg={6} sm={12} xs={24}>
                <PostCard post={item}/>
              </Col>
            ))}
          </Row>
        </Container>
      </div>
      <div style={{ paddingBottom: 16}}>
        <Container>
          <Flex justify='flex-start' gap={16} align='center' style={{marginBottom:  16}}>
            <Link className="page-title" href="/fr/videos">
              <span>Vidéos</span>
            </Link>
          </Flex>
          <Row gutter={[32, 32]}>
            {viposts2.slice(0, 4).map((item: unknown, index: number) => (
              <Col key={index} md={8} lg={6} sm={12} xs={24}>
                <PostCard post={item} className="light"/>
              </Col>
            ))}
          </Row>
        </Container>
      </div>
      <div style={{ paddingBottom: 16}}>
        <Container>
          <Flex justify='flex-start' gap={16} align='center' style={{marginBottom:  16}}>
            <Link className="page-title" href="/fr/cinema">
              <span>Cinéma</span>
            </Link>
          </Flex>

          <Row gutter={[32, 32]}>
            {ciposts2.slice(0, 4).map((item: unknown, index: number) => (
              <Col key={index} md={8} lg={6} sm={12} xs={24}>
                <PostCard post={item}/>
              </Col>
            ))}
          </Row>
        </Container>
      </div>
      <div style={{ paddingBottom: 16}}>
        <Container>
          <Flex justify='flex-start' gap={16} align='center' style={{marginBottom:  16}}>
            <Link className="page-title" href="/fr/#">
              <span>LES PLUS LUS</span>
            </Link>
          </Flex>

          <Row gutter={[32, 32]}>
            {tops2.slice(0, 4).map((item: unknown, index: number) => (
              <Col key={index} md={8} lg={6} sm={12} xs={24}>
                <PostCard post={item}/>
              </Col>
            ))}
          </Row>
        </Container>
      </div>


    </>
  );
};

export default HomePage;
