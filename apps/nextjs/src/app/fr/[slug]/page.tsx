// 'use cache';

import { Col, Row, Space } from 'antd';
import moment from 'moment';
import type { Metadata, ResolvingMetadata } from 'next';
import { notFound } from 'next/navigation';
import React from 'react';

import {AdComponent} from '../../components/AdComponent';
import Container from '../../components/Container';
import { Date } from '../../components/Date';
import MostViewed from '../../components/MostViewed';
import SocialShare from '../../components/Socials';
import VideoPlayer from '../../components/VideoPlayer';


// Enable ISR - page will be statically generated and revalidated every 5 minutes
export const revalidate = 300; // 5 minutes in seconds

type Props = {
  params: Promise<{ slug: string }>
}

export async function generateMetadata(
  { params }: Props,
  parent: ResolvingMetadata,
): Promise<Metadata> {
  // read route params
  const slug = (await params).slug;

  try {
    const data = await fetch(`${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchpostdata/${slug}`, {
      next: {
        revalidate: 300,
        tags: ['posts', 'single-post', slug],
      },
    });

    if (!data.ok) {
      throw new Error(`Failed to fetch post data: ${data.status}`);
    }

    const posts = await data.json();
    if (!posts || posts.length === 0) {
      throw new Error('No post data found');
    }

    const post = posts[0];
    // optionally access and extend (rather than replace) parent metadata
    const previousImages = (await parent).openGraph?.images || [];

    return {
      title: `${post.title} | Urbankiff`,
      description: post.intro || `Découvrez l'article "${post.title}" sur Urbankiff. Actualités musique, cinéma et culture urbaine.`,
      openGraph: {
        title: `${post.title} | Urbankiff`,
        description: post.intro || `Découvrez l'article "${post.title}" sur Urbankiff. Actualités musique, cinéma et culture urbaine.`,
        images: [post.image, ...previousImages],
      },
    };
  } catch (error) {
    console.error('Error generating metadata for post:', slug, error);
    return {
      title: 'Article | Urbankiff',
      description: 'Découvrez cet article sur Urbankiff. Actualités musique, cinéma et culture urbaine.',
    };
  }
}


const SinglePost = async ({
  params,
}: {
  params: Promise<{ slug: string }>
}) => {
  const slug = (await params).slug;

  try {
    const data = await fetch(`${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchpostdata/${slug}`, {
      next: {
        revalidate: 300,
        tags: ['posts', 'single-post', slug],
      },
    });

    if (!data.ok) {
      console.error(`Failed to fetch post data for ${slug}: ${data.status}`);
      notFound();
    }

    const posts = await data.json();
    const empty = posts.length === 0;
    if (empty) {notFound();}
    const post = posts[0];
    const {
      audio,
      author,
      // category,
      content,
      createdAt,
      // id,
      image,
      // intro,
      // tags,
      title,
      updatedAt,
      // url,
      video,
    // viewCount
    } = post;

    const viewRequest = await fetch(`${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/record-view/${post.id}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id: post.id,
      }),
      // No caching for POST requests (analytics)
    });
    await viewRequest.json();
    // const adsRequest = await fetch(`${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/ads/`)
    // const ads = await adsRequest.json();
    // const media = await ads.find(({ uuid }: { uuid: string})=> uuid === 'banner_single_post')?.medias[0]


    return (
      <>
        <AdComponent space_uuid="banner_single_post" />
        <Container>
          <div className="mb-3" style={{ marginBottom: 16 }}>
            {post.video ? (
              <VideoPlayer url={video} />
            ) : (

              <div className="single-post-image">
                <img src={image} alt={title}/>
              </div>

            )}

          </div>
          <Row>
            <Col md={18}>
              <>
                <h1 className="single-post-title">
                  {title}
                </h1>
                <div className="single-post-info">
                  <span>
                      Publié le:{' '}
                    <Date
                      locale={'fr'}
                      time={createdAt}
                      fromNow={false}
                      dateTime={true}
                    />
                  </span>
                  <span>
                      Par: {author.firstname}
                  </span>
                  {moment(updatedAt).isAfter(moment(createdAt)) && (
                    <span>
                        Modifé le:{' '}
                      <Date
                        locale={'fr'}
                        time={updatedAt}
                        fromNow={false}
                        dateTime={true}
                      />
                    </span>
                  )}
                </div>


                <div
                  className='single-post-content'
                  style={{ marginBottom: 60 }}
                  dangerouslySetInnerHTML={{
                    __html: content,
                  }}
                ></div>

                {audio ? (
                  <div
                    style={{
                      maxWidth: 600,
                      marginBottom: 10,
                    }}
                  >
                    <audio controls>
                      <source src={`${process?.env?.NEXT_PUBLIC_BACKEND_URL || process?.env?.BACKEND_URL}/files/${post.audio}`} type="audio/mpeg"/>
                        Your browser does not support the audio tag.
                    </audio>
                  </div>
                ) : null}

                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'flex-start',
                    alignItems: 'center',
                    gap: '16px',
                    padding: '10px 0px',
                  }}
                >
                  <h3>Partager </h3>
                  <Space>
                    <SocialShare/>
                  </Space>
                </div>
              </>

            </Col>
            <Col md={6}>
              <div className="sidebar">
                <MostViewed slug={slug} />
              </div>
            </Col>
          </Row>
        </Container>
      </>
    );
  } catch (error) {
    console.error('Error loading post:', slug, error);
    notFound();
  }
};

export default SinglePost;
