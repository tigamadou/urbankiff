import { Space } from 'antd';
import Link from 'next/link';
import React from 'react';

import { MobileMenuComponent } from '../MobileMenuComponent';
import {SearchButton} from '../SearchButton';
import  './Navbar.scss';

const Navbar = () => {

  return (
    <>
      <div className="navbar on-desktop">
        <div className="container ">
          <div className="logo">
            <div className="logo-image">
              <img src="/logo.png" alt="logo_urbankiff" />
            </div>
            <div className="logo-text">

              <Link href={'/'}>URBANKIFF</Link>
            </div>
          </div>

        </div>
        <div className="container">
          <div className="navbar-left">
            <ul className="navbar-menu">
              <li className="navbar-menu-item">
                <Link href={'/fr'}>
                  <span>Actus</span>
                </Link>
              </li>
              <li className="navbar-menu-item">
                <Link
                  href={'/fr/musiques'}
                  target={''}
                >
                  <span>Musiques</span>
                </Link>
              </li>
              <li className="navbar-menu-item">
                <Link
                  href={'/fr/cinema'}
                  target={''}
                >
                  <span>Cinéma</span>
                </Link>
              </li>
              <li className="navbar-menu-item">
                <Link
                  href={'/fr/videos'}
                  target={''}
                >
                  <span>Vidéos</span>
                </Link>
              </li>

            </ul>
          </div>
          <div className="navbar-right">

            <Space wrap>
              <ul className="navbar-menu">
                <li className="navbar-menu-item on-desktop">
                  <SearchButton clicked={null}/>
                </li>
                <li className="navbar-menu-item on-mobile">
                  <MobileMenuComponent/>
                </li>
              </ul>
            </Space>
          </div>
        </div>
      </div>
      <div className="navbar on-mobile">
        <div className="container">
          <div className="logo">
            <div className="logo-image">
              <img src="/logo.png" alt="logo_urbankiff" />
            </div>
            <div className="logo-text">

              <Link href={'/'}>URBANKIFF</Link>
            </div>
          </div>
          <div className="navbar-right">
            <ul className="navbar-menu">
              <li className="navbar-menu-item on-mobile">
                <MobileMenuComponent/>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </>
  );
};

export default Navbar;
