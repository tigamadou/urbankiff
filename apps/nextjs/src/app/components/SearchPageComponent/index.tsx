'use client';
import { Input, Col, Row, Typography } from 'antd';
import React, { useEffect, useState, useCallback } from 'react';

import PostCard from '../PostCard';

const { Search } = Input;
const { Title, Text } = Typography;

interface SearchPageComponentProps {
  searchUrl: string;
  language: string;
}

const SearchPageComponent: React.FC<SearchPageComponentProps> = ({ searchUrl, language }) => {

  const [searchValue, setSearchingValue] = useState('');
  const [searching, setSearching] = useState(false);
  const [posts, setPosts] = useState([]);
  // const [initialSearchDone, setInitialSearchDone] = useState(false)

  const onSearch = useCallback(async (value: string) => {
    setSearching(true);
    setSearchingValue(value);
    const url = `${searchUrl}${value}&language=${language}`;

    try {
      const response = await fetch(url, {
        next: {
          revalidate: 300,
          tags: ['search', 'search-results'],
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }

      const data = await response.json();
      setPosts(data); // Update posts with the fetched data
    } catch (error) {
      console.error('Error fetching data:', error);
      // Handle the error appropriately, e.g., display an error message to the user
    } finally {
      setSearching(false); // Ensure searching is set to false regardless of success or failure
    }
  }, [language, searchUrl, setPosts, setSearching, setSearchingValue]);

  useEffect(() => {

    if (searchValue && searchValue.length > 0) {onSearch(searchValue);}
  }, [onSearch, searchValue]);

  return (
    <>

      <Search
        placeholder={'Chercher'}
        disabled={searching}
        loading={searching}
        onSearch={onSearch}
        defaultValue={searchValue}
        size="large"
      />
      <br/>
      <br/>
      <>

        <Title level={3}>Résultat(s)</Title>

        {posts && posts.length > 0 ? (
          <Row gutter={[32, 32]}>
            {posts.map((item, index) => (
              <Col key={index} md={6} xs={24}>
                <PostCard post={item}  />
              </Col>
            ))}
          </Row>
        ) : (
          <Row>
            <Text>
            Désolé, aucune correspondance n&apos;a été trouvée pour votre
            recherche. Essayez avec d&apos;autres mots-clés.
            </Text>
          </Row>
        )}
      </>
    </>
  );
};

export { SearchPageComponent };
