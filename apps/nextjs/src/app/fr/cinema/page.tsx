import React from 'react';

import PostCategories from '../../components/PostCategories';

export const metadata = {
  title: 'Cinéma - Actualités et Critiques de Films | Urbankiff',
  description: 'Découvrez les dernières actualités cinéma, critiques de films, sorties et interviews d\'acteurs sur Urbankiff. Votre source d\'information sur le 7ème art.',
  openGraph: {
    title: 'Cinéma - Actualités et Critiques de Films | Urbankiff',
    description: 'Découvrez les dernières actualités cinéma, critiques de films, sorties et interviews d\'acteurs sur Urbankiff. Votre source d\'information sur le 7ème art.',
  },
};

// Enable ISR - page will be statically generated and revalidated every 5 minutes
export const revalidate = 300; // 5 minutes in seconds

const CinemaPage = async ({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>

}) => {
  const resolvedSearchParams = await searchParams;
  const pageParam = resolvedSearchParams['page'];
  const page = parseInt(Array.isArray(pageParam) ? pageParam[0] : pageParam ?? '1', 10);
  return (
    <div style={{ paddingBottom: 16}}>
      <PostCategories categoryName='Cinéma' categorySlug='cinema' page={page}/>
    </div>
  );
};

export default CinemaPage;
