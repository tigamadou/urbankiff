import React from 'react';

import Container from '../../components/Container';
import { SearchPageComponent } from '../../components/SearchPageComponent';

export const metadata = {
  title: 'Recherche - Trouvez vos Contenus | Urbankiff',
  description: 'Recherchez parmi tous les articles, vidéos et contenus d\'Urbankiff. Trouvez rapidement les actualités musique, cinéma et culture urbaine qui vous intéressent.',
  openGraph: {
    title: 'Recherche - Trouvez vos Contenus | Urbankiff',
    description: 'Recherchez parmi tous les articles, vidéos et contenus d\'Urbankiff. Trouvez rapidement les actualités musique, cinéma et culture urbaine qui vous intéressent.',
  },
};

// Enable ISR - page will be statically generated and revalidated every 5 minutes
export const revalidate = 300; // 5 minutes in seconds

const SearchPage = () => {
  const searchUrl = `${process.env.NEXT_PUBLIC_BACKEND_URL_FRONT || process.env.BACKEND_URL}/post/search?search_query=`;

  return (
    <Container>
      <h2 className="page-title">
            Rechercher
      </h2>
      <p>Lance une recherche dans les articles ou vidéos parmi l’ensemble des publications</p>
      <SearchPageComponent searchUrl={searchUrl} language="fr" />
    </Container>
  );
};

export default SearchPage;
