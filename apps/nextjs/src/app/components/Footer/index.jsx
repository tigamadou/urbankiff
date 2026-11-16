import {
  FacebookOutlined,
  TwitterOutlined,
  InstagramOutlined,
  YoutubeOutlined,
} from '@ant-design/icons';
import { Row, Col, Flex } from 'antd';
import Link from 'next/link';
import React from 'react';

import Container from '../Container';

const AppFooter = () => {

  return (
    <div className='footer' style={{ textAlign: 'center', backgroundColor: '#000', color: 'white', padding: '30px 0px' }}>
      <Container>
        <Row justify={'space-between'}>
          <Col xs={24} md={6}>
            <div className="footer-logo">
              <Link href={'/'}><img src="/logo.png" alt="logo_urbankiff" /></Link>
            </div>
          </Col>
          <Col xs={24} md={6}>
            <ul>
              <li>
                <Link href={'/fr'} >Actus</Link>
              </li>
              <li>
                <Link href={'/fr/musiques'}>Musiques</Link>
              </li>
              <li>
                <Link href={'/fr/cinema'} >Cinéma</Link>
              </li>
              <li>
                <Link href={'/fr/videos'} >Vidéos</Link>
              </li>
            </ul>
          </Col>
          <Col xs={24} md={6}>
            <ul>
              <li>
                <Link href={'/fr/mentions-legales'} >Mentions Légales</Link>
              </li>
              <li>
                <Link href="/fr/donnees-et-cookies" >Données et Cookies</Link>
              </li>
              <li>
                <Link href="/fr/conditions-de-service" >Conditions de service</Link>
              </li>
            </ul>
          </Col>
          <Col xs={24} md={6}>
            <ul>
              <li>
                <Link href="/fr/cgu" >Conditions générales d&apos;utilisation</Link>
              </li>
              <li>
                <Link href="/fr/politique-de-confidentialite" >Politique de confidentialité</Link>
              </li>
              <li>
                <Link href="mailto:contacts@urbankiff.com">Nous Contacter</Link>
              </li>
            </ul>
          </Col>
        </Row>

        <Flex gap={16} justify='center' align='center'>
          <Link href="https://www.facebook.com/urbankiffoff" target="_blank" rel="noreferrer" ><FacebookOutlined style={{ fontSize: '24px', marginRight: '10px' }} /></Link>
          <Link href="https://twitter.com/urbankiffoff" target="_blank" rel="noreferrer" ><TwitterOutlined style={{ fontSize: '24px', marginRight: '10px' }} /></Link>
          <Link href="https://www.instagram.com/urbankiffoff/" target="_blank" rel="noreferrer" ><InstagramOutlined style={{ fontSize: '24px', marginRight: '10px' }} /></Link>
          <Link href="https://www.youtube.com/channel/UC92CyBcUqriR_RjkXQP-ISg?view_as=subscriber" target="_blank" rel="noreferrer" ><YoutubeOutlined style={{ fontSize: '24px', marginRight: '10px' }} /></Link>
        </Flex>

        <p >©2023 Urbankiff</p>
      </Container>
    </div>
  );
};

export default AppFooter;
