
import React from 'react';

import PostCard from '../PostCard';

type itemType = {
    slug: string;
    title: string;
    image: string;
    url: string;
    createdAt: string;
    category: {
        color: string;
        name: string;
    }
  }


const MostViewed = async ({slug}: { slug: string}) => {

  const data = await fetch(`${process.env.BACKEND_URL || process.env.NEXT_PUBLIC_BACKEND_URL}/post/fetchmostview/fr/${slug}`);
  const posts = await data.json();

  return (
    <div className="sidebar-panel">
      <div className="sidebar-panel-title"> Top</div>
      <div className="sidebar-panel-content">

        <>
          {posts.map((item: itemType, idx: undefined) => (
            <PostCard
              key={idx}
              post={item}
              className={'with-row'}
            />
          ))}
        </>

      </div>
    </div>
  );
};

export default MostViewed;
