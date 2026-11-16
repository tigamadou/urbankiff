'use client';
import { Space } from 'antd';
import React, { useEffect, useState } from 'react';
import {
  FacebookShareButton,
  FacebookIcon,
  FacebookShareCount,
  TwitterShareButton,
  WhatsappShareButton,
  WhatsappIcon,
  XIcon,
} from 'react-share';
export default function SocialShare() {
  const [currentPath, setCurrentPath] = useState('');

  useEffect(() => {
    setCurrentPath(window.location.href);
  }, []);
  return (
    <Space style={{ padding: '16px 0px' }}>
      <FacebookShareButton url={currentPath} hashtag="" title="">
        <FacebookIcon round={true} size={40}/>
      </FacebookShareButton>
      <FacebookShareCount url={currentPath}/>
      <TwitterShareButton url={currentPath}  title="urbankiff.com">
        <XIcon round={true} size={40}/>
      </TwitterShareButton>
      <WhatsappShareButton url={currentPath}>
        <WhatsappIcon round={true} size={40}/>
      </WhatsappShareButton>
    </Space>
  );
}
