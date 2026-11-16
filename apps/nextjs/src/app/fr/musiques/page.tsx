import React from 'react';

import PostCategories from '../../components/PostCategories';

export const metadata = {
  title: 'Musiques - Actualités et Découvertes Musicales | Urbankiff',
  description: 'Explorez les dernières actualités musicales, découvertes d\'artistes et tendances de la musique urbaine sur Urbankiff. Interviews, chroniques et exclusivités musicales.',
  openGraph: {
    title: 'Musiques - Actualités et Découvertes Musicales | Urbankiff',
    description: 'Explorez les dernières actualités musicales, découvertes d\'artistes et tendances de la musique urbaine sur Urbankiff. Interviews, chroniques et exclusivités musicales.',
  },
};

// Enable ISR - page will be statically generated and revalidated every 5 minutes
export const revalidate = 300; // 5 minutes in seconds

const MusiquesPage = async ({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>

}) => {
  const resolvedSearchParams = await searchParams;
  const pageParam = resolvedSearchParams['page'];
  const page = parseInt(Array.isArray(pageParam) ? pageParam[0] : pageParam ?? '1', 10);

  return (
    <div style={{ paddingBottom: 16}}>
      <PostCategories categoryName='Musiques' categorySlug='musiques' page={page}/>
    </div>
  );
};

export default MusiquesPage;
