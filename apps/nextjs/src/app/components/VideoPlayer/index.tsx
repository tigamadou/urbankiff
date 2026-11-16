'use client';
import React from 'react';
import ReactPlayer from 'react-player';

const VideoPlayer = ({ url }: { url: string}) => {
  return (
    <div
      style={{
        marginBottom: 10,
        width: '100%',
      }}
    >
      <ReactPlayer
        width={'100%'}
        height={'auto'}
        style={{ aspectRatio: '16/9', background: '#000' }}
        controls={true}
        url={url}
        light={true}
      />
    </div>
  );
};

export default VideoPlayer;
