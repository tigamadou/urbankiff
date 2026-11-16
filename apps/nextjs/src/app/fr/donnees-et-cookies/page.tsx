import React from 'react';

import PDFViewer from '@/app/components/PDFViewer';

import Container from '../../components/Container';

export const metadata = {
  title: 'Données et Cookies - Gestion des Données | Urbankiff',
  description: 'Découvrez comment Urbankiff gère vos données personnelles et utilise les cookies. Informations sur la collecte, le traitement et la protection de vos informations.',
  openGraph: {
    title: 'Données et Cookies - Gestion des Données | Urbankiff',
    description: 'Découvrez comment Urbankiff gère vos données personnelles et utilise les cookies. Informations sur la collecte, le traitement et la protection de vos informations.',
  },
};

// Enable ISR - page will be statically generated and revalidated every hour
export const revalidate = 3600; // 1 hour in seconds

const DonneesCookiesPage = () => {

  return (
    <Container>
      <PDFViewer fileUrl={`${process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL}/files/politique-de-gestion-des-incidents-de-violation-des-donnees-personnelles.pdf`}/>
    </Container>
  );
};

export default DonneesCookiesPage;
