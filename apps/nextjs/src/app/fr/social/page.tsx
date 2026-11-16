
import {
  FacebookOutlined,
  TwitterOutlined,
  InstagramOutlined,
  YoutubeOutlined,
  LinkedinOutlined,
  TikTokOutlined,
  MailOutlined,
  PhoneOutlined,
} from '@ant-design/icons';
import { Row, Col, Card, Space } from 'antd';
import React from 'react';

import Container from '../../components/Container';


export const metadata = {
  title: 'Réseaux Sociaux - Contactez Urbankiff | Urbankiff',
  description: 'Retrouvez Urbankiff sur tous nos réseaux sociaux et plateformes. Suivez nos actualités musique, cinéma et culture urbaine sur Facebook, Instagram, Twitter et plus encore.',
  openGraph: {
    title: 'Réseaux Sociaux - Contactez Urbankiff | Urbankiff',
    description: 'Retrouvez Urbankiff sur tous nos réseaux sociaux et plateformes. Suivez nos actualités musique, cinéma et culture urbaine sur Facebook, Instagram, Twitter et plus encore.',
  },
};

// Enable ISR - page will be statically generated and revalidated every hour
export const revalidate = 3600; // 1 hour in seconds

const SocialsPage = () => {
  const socialLinks = [
    {
      name: 'Facebook',
      icon: <FacebookOutlined style={{ fontSize: '24px', color: '#1877f2' }} />,
      url: 'https://facebook.com/urbankiffoff',
      description: 'Suivez-nous sur Facebook pour les dernières actualités',
    },
    {
      name: 'Instagram',
      icon: <InstagramOutlined style={{ fontSize: '24px', color: '#e4405f' }} />,
      url: 'https://instagram.com/urbankiffoff',
      description: 'Découvrez nos contenus visuels sur Instagram',
    },
    {
      name: 'TikTok',
      icon: <TikTokOutlined style={{ fontSize: '24px', color: '#000000' }} />,
      url: 'https://tiktok.com/@urbankiffoff',
      description: 'Découvrez nos contenus courts et créatifs',
    },
    {
      name: 'Twitter',
      icon: <TwitterOutlined style={{ fontSize: '24px', color: '#1da1f2' }} />,
      url: 'https://twitter.com/urbankiffoff',
      description: 'Restez connectés avec nous sur Twitter',
    },
    {
      name: 'YouTube',
      icon: <YoutubeOutlined style={{ fontSize: '24px', color: '#ff0000' }} />,
      url: 'https://youtube.com/@urbankiffoff',
      description: 'Regardez nos vidéos sur YouTube',
    },
    {
      name: 'LinkedIn',
      icon: <LinkedinOutlined style={{ fontSize: '24px', color: '#0077b5' }} />,
      url: 'https://www.linkedin.com/company/urbankiffoff/',
      description: 'Connectez-vous avec nous professionnellement',
    },
  ];

  const contactInfo = [
    {
      name: 'Email',
      icon: <MailOutlined style={{ fontSize: '24px', color: '#1890ff' }} />,
      value: 'contact@urbankiff.com',
      description: 'Envoyez-nous un message',
    },
    {
      name: 'Téléphone',
      icon: <PhoneOutlined style={{ fontSize: '24px', color: '#52c41a' }} />,
      value: '+229 0167211963',
      description: 'Appelez-nous directement',
    },
  ];

  return (
    <>
      <Container>
        <div style={{ padding: '32px 0' }}>
          <h1 style={{ textAlign: 'center', marginBottom: '48px' }}>
            Nos Réseaux Sociaux
          </h1>

          <p style={{ textAlign: 'center', fontSize: '18px', marginBottom: '48px' }}>
            Restez connectés avec Urbankiff sur tous nos réseaux sociaux et plateformes
          </p>

          {/* Social Media Links */}
          <h2  style={{ marginBottom: '24px', textAlign: 'center' }}>
            Suivez-nous
          </h2>

          <Row gutter={[24, 24]} style={{ marginBottom: '48px' }}>
            {socialLinks.map((social, index) => (
              <Col key={index} xs={24} sm={12} md={8} lg={4}>
                <Card
                  style={{
                    textAlign: 'center',
                    height: '100%',
                    cursor: 'pointer',
                  }}

                >
                  <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                    <a href={social.url} target="_blank" rel="noopener noreferrer" style={{ color: 'inherit', textDecoration: 'none' }}>
                      {React.cloneElement(social.icon, { style: { fontSize: '48px' } })}
                    </a>

                    <h4 style={{ margin: 0 }}>
                      <a href={social.url} target="_blank" rel="noopener noreferrer" style={{ color: 'inherit', textDecoration: 'none' }}>
                        {social.name}
                      </a>
                    </h4>
                  </Space>
                </Card>
              </Col>
            ))}
          </Row>

          {/* Contact Information */}
          <h2 style={{ marginBottom: '24px', textAlign: 'center' }}>
            Contactez-nous
          </h2>

          <Row gutter={[24, 24]}>
            {contactInfo.map((contact, index) => (
              <Col key={index} xs={24} sm={12}>
                <Card style={{ textAlign: 'center' }}>
                  <Space direction="vertical" size="middle">
                    {contact.icon}
                    <h4 style={{ margin: 0 }}>
                      {contact.name}
                    </h4>
                    <p style={{ margin: 0, fontSize: '16px', fontWeight: 'bold' }}>
                      {contact.value}
                    </p>
                    <p style={{ margin: 0, color: '#666' }}>
                      {contact.description}
                    </p>
                  </Space>
                </Card>
              </Col>
            ))}
          </Row>
        </div>
      </Container>
    </>
  );
};

export default SocialsPage;
