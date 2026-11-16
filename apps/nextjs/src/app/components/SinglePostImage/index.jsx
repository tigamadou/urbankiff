'use client';
import React, { useState, useEffect } from 'react';

import { ImageWL } from '../ImageWL';


const SinglePostImage = ({ image }) => {
  const [isMounted, setIsmounted] = useState(false);

  useEffect(() => {
    setIsmounted(true);
    return () => setIsmounted(false);
  }, []);
  return (
    <>
      {isMounted &&
        <div className="post-image-container">
          <ImageWL
            className="original"
            src={image}
            large={image}
            showOriginal={true}
          />
        </div>
      }
    </>
  );};

export { SinglePostImage };
