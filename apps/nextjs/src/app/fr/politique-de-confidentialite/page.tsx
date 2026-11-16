import React from 'react';

import PDFViewer from '@/app/components/PDFViewer';

import Container from '../../components/Container';

export const metadata = {
  title: 'Politique de Confidentialité - Protection des Données | Urbankiff',
  description: 'Découvrez notre politique de confidentialité et comment Urbankiff protège vos données personnelles. Informations sur la collecte, l\'utilisation et la protection de vos informations.',
  openGraph: {
    title: 'Politique de Confidentialité - Protection des Données | Urbankiff',
    description: 'Découvrez notre politique de confidentialité et comment Urbankiff protège vos données personnelles. Informations sur la collecte, l\'utilisation et la protection de vos informations.',
  },
};

// Enable ISR - page will be statically generated and revalidated every hour
export const revalidate = 3600; // 1 hour in seconds

const PolitiqueConfidentialitePage = () => {

  return (
    <Container>
      <PDFViewer fileUrl={`${process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL}/files/politique-de-confidentialite.pdf`}/>
    </Container>
  );
};

export default PolitiqueConfidentialitePage;
