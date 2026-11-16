'use client';
import { MenuOutlined } from '@ant-design/icons';
import { Button } from 'antd';
import { Drawer } from 'antd';
import Link from 'next/link';
import React, { useState } from 'react';

import {SearchButton} from '../SearchButton';


// eslint-disable-next-line @typescript-eslint/no-explicit-any
const SideMenu = ({ onClose, open }: {onClose: any, open: boolean}) => {


  return (
    <Drawer
      width="100%"
      title={
        <div className="logo">
          <Link onClick={onClose} href={'/'}>
            <div className="logo-image">
              <img src="/logo.png" alt="logo_urbankiff" />
            </div>
            <div className="logo-text">

              URBANKIFF
            </div>
          </Link>
        </div>
      }
      placement="right"
      onClose={() => onClose()}
      open={open}
      className="sidemenu"
      styles={{header: {padding: '10px', borderBottom: '2px solid #000', boxShadow: '0px 15px 10px -10px rgba($color: #686868, $alpha: .4)'}}}
      footer={<div className="flex justify-between"><SearchButton clicked={onClose}/></div>}
    >
      <div className="header">

      </div>
      <ul>
        <li >
          <Link
            href={'/fr'}
            onClick={onClose}
          >
            <span>Actus</span>
          </Link>
        </li>
        <li>
          <Link
            href={'/fr/musiques'}
            onClick={onClose}
          >
            <span>Musiques</span>
          </Link>
        </li>
        <li>
          <Link
            href={'/fr/cinema'}
            onClick={onClose}
          >
            <span>Cinéma</span>
          </Link>
        </li>
        <li>
          <Link
            href={'/fr/videos'}
            onClick={onClose}
          >
            <span>Vidéos</span>
          </Link>
        </li>
        <li>
        </li>
      </ul>
    </Drawer>

  );
};

const MobileMenuComponent = () =>{
  const [showMenu, setShowMenu] = useState(false);

  const handleMenu = () => {
    setShowMenu(!showMenu);
  };

  return (
    <>
      <Button
        type="text"
        shape="circle"
        icon={<MenuOutlined />}
        onClick={handleMenu}
      />
      <SideMenu onClose={handleMenu} open={showMenu}/>
    </>

  );
};

export { MobileMenuComponent };
