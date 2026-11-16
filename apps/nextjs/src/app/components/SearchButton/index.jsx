'use client';
import { SearchOutlined } from '@ant-design/icons';
import { Button } from 'antd';
import Link from 'next/link';
import React from 'react';

const SearchButton = ({clicked}) =>{


  return (
    <Link href={'/fr/search'} onClick={() => clicked ? clicked() : null }>
      <Button
        type="button"
        shape="circle"
        icon={<SearchOutlined />}
      />
    </Link>
  );
};

export { SearchButton };
