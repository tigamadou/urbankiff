import React from 'react';

import Container from '../../components/Container';
import PDFViewer from '../../components/PDFViewer';

export const metadata = {
  title: 'Mentions Légales - Informations Légales | Urbankiff',
  description: 'Consultez nos mentions légales pour connaître les informations légales de la plateforme Urbankiff. Éditeur, hébergeur et informations de contact officielles.',
  openGraph: {
    title: 'Mentions Légales - Informations Légales | Urbankiff',
    description: 'Consultez nos mentions légales pour connaître les informations légales de la plateforme Urbankiff. Éditeur, hébergeur et informations de contact officielles.',
  },
};

// Enable ISR - page will be statically generated and revalidated every hour
export const revalidate = 3600; // 1 hour in seconds

const MentionsLegalesPage = () => {

  return (
    <Container>
      <PDFViewer fileUrl={`${process.env.NEXT_PUBLIC_BACKEND_URL || process.env.BACKEND_URL}/files/mentions_legales.pdf`}/>
    </Container>
  );
};

export default MentionsLegalesPage;
