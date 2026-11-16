import React from 'react';

import PDFViewer from '@/app/components/PDFViewer';

import Container from '../../components/Container';

export const metadata = {
  title: 'Conditions Générales d\'Utilisation (CGU) | Urbankiff',
  description: 'Consultez nos conditions générales d\'utilisation pour comprendre les règles et conditions d\'usage de la plateforme Urbankiff. Informations légales et droits des utilisateurs.',
  openGraph: {
    title: 'Conditions Générales d\'Utilisation (CGU) | Urbankiff',
    description: 'Consultez nos conditions générales d\'utilisation pour comprendre les règles et conditions d\'usage de la plateforme Urbankiff. Informations légales et droits des utilisateurs.',
  },
};

// Enable ISR - page will be statically generated and revalidated every hour
export const revalidate = 3600; // 1 hour in seconds

const CGUPage = () => {

  return (
    <Container>
      <PDFViewer fileUrl={`${process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL}/files/cgufr.pdf`}/>
    </Container>
  );
};

export default CGUPage;
