
import { Col, Row, Flex } from 'antd';
import { notFound } from 'next/navigation';
import React from 'react';

import Container from '../../components/Container';
import PostCard from '../../components/PostCard';
import Pagination from '../Pagination';

interface PostCategoriesProps {
    categoryName: string;
    categorySlug: string;
    language?: string;
    page?: number;
  }

const PostCategories: React.FC<PostCategoriesProps>  = async ({ categoryName, categorySlug, language= 'fr', page=1 }) => {
  const limit = 12;
  const url = `${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/posts?category=${categorySlug}&language=${language}&page=${page}&limit=${limit}`;

  try {
    const data = await fetch(url, {
      next: {
        revalidate: 300,
        tags: ['posts', categorySlug, 'category'],
      },
    });

    if (!data.ok) {
      console.error(`Failed to fetch posts for category ${categorySlug}: ${data.status}`);
      notFound();
    }

    const posts = await data.json();
    if (!posts || !posts.results || posts.results.length === 0 ) {
      notFound();
    }
    const {count, results} = posts;

    const totalPages = Math.round(count/limit);


    return (
      <>
        <Container>
          <Flex justify='space-between' align='center' style={{marginBottom:  16}}>
            <h2 className="page-title">
              {categoryName}
            </h2>
          </Flex>

          <Row gutter={[32, 32]}>
            {results?.map((item: unknown, index: number) => (
              <Col key={index} md={8} lg={6} sm={12} xs={24}>
                <PostCard post={item}/>
              </Col>
            ))}
          </Row>
          <Pagination  basePath={`/fr/${categorySlug}`} currentPage={page} totalPages={totalPages} />
        </Container>
      </>
    );
  } catch (error) {
    console.error('Error loading posts for category:', categorySlug, error);
    notFound();
  }
};


export default PostCategories;
