import React from 'react';

import PDFViewer from '@/app/components/PDFViewer';

import Container from '../../components/Container';


export const metadata = {
  title: 'Conditions de Service - Règles d\'Utilisation | Urbankiff',
  description: 'Consultez nos conditions de service pour comprendre les règles d\'utilisation de la plateforme Urbankiff. Droits, obligations et conditions d\'accès aux services.',
  openGraph: {
    title: 'Conditions de Service - Règles d\'Utilisation | Urbankiff',
    description: 'Consultez nos conditions de service pour comprendre les règles d\'utilisation de la plateforme Urbankiff. Droits, obligations et conditions d\'accès aux services.',
  },
};

// Enable ISR - page will be statically generated and revalidated every hour
export const revalidate = 3600; // 1 hour in seconds

const ConditionsServicePage = () => {

  return (
    <Container>
      <PDFViewer fileUrl={`${process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL}/files/conditions-de-service.pdf`}/>
    </Container>
  );
};

export default ConditionsServicePage;
