import React from 'react';

import PostCategories from '../../components/PostCategories';

export const metadata = {
  title: 'Vidéos - Contenus Vidéo et Actualités | Urbankiff',
  description: 'Regardez les meilleures vidéos, interviews, reportages et contenus multimédias sur Urbankiff. Découvrez la culture urbaine en vidéo avec nos productions exclusives.',
  openGraph: {
    title: 'Vidéos - Contenus Vidéo et Actualités | Urbankiff',
    description: 'Regardez les meilleures vidéos, interviews, reportages et contenus multimédias sur Urbankiff. Découvrez la culture urbaine en vidéo avec nos productions exclusives.',
  },
};

// Enable ISR - page will be statically generated and revalidated every 5 minutes
export const revalidate = 300; // 5 minutes in seconds

const VideosPage = async ({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>
}) => {
  const resolvedSearchParams = await searchParams;
  const pageParam = resolvedSearchParams['page'];
  const page = parseInt(Array.isArray(pageParam) ? pageParam[0] : pageParam ?? '1', 10);
  return (
    <div style={{ paddingBottom: 16}}>
      <PostCategories categoryName='Vidéos' categorySlug='videos' page={page}/>
    </div>
  );
};

export default VideosPage;
